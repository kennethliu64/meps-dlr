# =============================================================================
# 03_dummy_analysis.R
# Run weighted estimates for all three research questions using the survey
# design objects from 02_survey_design.R. Produces a descriptive table of
# the analytic cohort and a bar chart of the dental service mix.
#
# Q1: Among the national DLR cohort, how many dental visits did they have?
# Q2: What were total and out-of-pocket dental expenditures?
# Q3: What was the mix of dental services utilized?
#
# This is a national-level dummy analysis using the full U.S. DLR cohort
# (DVTPRV23 > 0). MA-specific analysis will be in a separate script once
# the restricted-use file with STATECD is available.
#
# NOTE: "dummy" = baseline analysis on 2023 data only. The full pre-post
# analysis requires 2024 data. These results verify the pipeline end-to-end.
#
# Input:  data/design_full_2023.rds
#         data/design_dlr_2023.rds
#         data/dv_2023.rds
# Output: output/table1_cohort.html
#         output/service_mix.png
#         output/q1_visits.csv
#         output/q2_spending.csv
#         output/q3_service_mix.csv
# =============================================================================

source(here::here("R", "00_setup.R"))

dir.create(here("output"), showWarnings = FALSE)

# Load design objects
message("Loading survey design objects...")
design_dlr <- readRDS(here("data", "design_dlr_2023.rds"))
dv_raw     <- readRDS(here("data", "dv_2023.rds"))

# Convenience: the analytic data frame (national DLR cohort)
analytic <- design_dlr$variables

message("  Analytic cohort (national DLR): ",
        format(nrow(analytic), big.mark = ","), " unweighted | ",
        format(round(sum(analytic$PERWT23F)), big.mark = ","), " weighted")

# =============================================================================
# Q1 — Dental visit frequency (DVTOT23)
# =============================================================================

message("\nQ1: Dental visit frequency...")

q1_mean <- svymean(~DVTOT23, design = design_dlr, na.rm = TRUE)
q1_total <- svytotal(~DVTOT23, design = design_dlr, na.rm = TRUE)

message("  Weighted mean visits: ", round(coef(q1_mean), 3),
        " (SE: ", round(SE(q1_mean), 3), ")")

q1_out <- tibble(
  metric   = c("mean_visits", "total_visits"),
  estimate = c(coef(q1_mean), coef(q1_total)),
  se       = c(SE(q1_mean), SE(q1_total))
)
write_csv(q1_out, here("output", "q1_visits.csv"))
message("  Saved: output/q1_visits.csv")

# =============================================================================
# Q2 — Total and out-of-pocket dental spending
# =============================================================================

message("\nQ2: Dental spending...")

q2_mean <- svymean(~DVTEXP23 + DVTSLF23, design = design_dlr, na.rm = TRUE)

message("  Weighted mean total expenditure: $", round(coef(q2_mean)["DVTEXP23"], 2))
message("  Weighted mean OOP expenditure:   $", round(coef(q2_mean)["DVTSLF23"], 2))

q2_out <- tibble(
  outcome  = names(coef(q2_mean)),
  mean     = coef(q2_mean),
  se       = SE(q2_mean)
)
write_csv(q2_out, here("output", "q2_spending.csv"))
message("  Saved: output/q2_spending.csv")

# =============================================================================
# Q3 — Dental service mix (from event-level file HC-248B)
# =============================================================================
# Link the dental visits file to the DLR cohort via DUPERSID, then compute
# the proportion of visits where each procedure type was performed.

message("\nQ3: Dental service mix...")

dlr_ids <- unique(analytic$DUPERSID)

procedure_vars <- c(
  "EXAMEX", "XRAYX", "CLNNGX", "FLRIDEX", "SEALNTX",
  "FILLNGX", "CROWNX", "ROOTCAX", "EXTRACTX", "IMPLNTX",
  "BRIDGEX", "DENTURX", "ORTHDONX"
)

# Keep only visits belonging to DLR cohort members
# and only the procedure flag columns that actually exist
existing_proc_vars <- intersect(procedure_vars, names(dv_raw))

dv_cohort <- dv_raw |>
  filter(DUPERSID %in% dlr_ids) |>
  select(DUPERSID, all_of(existing_proc_vars))

# Proportion of visits with each procedure (unweighted at visit level —
# MEPS does not provide visit-level weights; person weights are person-level)
service_props <- dv_cohort |>
  summarise(
    across(all_of(existing_proc_vars),
           ~ mean(.x == 1, na.rm = TRUE),
           .names = "{.col}")
  ) |>
  pivot_longer(everything(), names_to = "procedure", values_to = "proportion") |>
  mutate(
    n_visits = nrow(dv_cohort),
    procedure = factor(procedure, levels = existing_proc_vars)
  ) |>
  arrange(desc(proportion))

print(service_props, n = Inf)
write_csv(service_props, here("output", "q3_service_mix.csv"))
message("  Saved: output/q3_service_mix.csv")

# ---- Bar chart of service mix -----------------------------------------------

service_labels <- c(
  EXAMEX   = "Examination",
  XRAYX    = "X-ray",
  CLNNGX   = "Cleaning",
  FLRIDEX  = "Fluoride",
  SEALNTX  = "Sealant",
  FILLNGX  = "Filling",
  CROWNX   = "Crown",
  ROOTCAX  = "Root canal",
  EXTRACTX = "Extraction",
  IMPLNTX  = "Implant",
  BRIDGEX  = "Bridge",
  DENTURX  = "Denture",
  ORTHDONX = "Orthodontics"
)

p_mix <- service_props |>
  mutate(label = service_labels[as.character(procedure)]) |>
  ggplot(aes(x = reorder(label, proportion), y = proportion)) +
  geom_col(fill = "#2166ac", alpha = 0.85) +
  geom_text(aes(label = scales::percent(proportion, accuracy = 0.1)),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = "Dental service mix — DLR cohort, 2023 (pre-law baseline)",
    subtitle = paste0("Among U.S. privately-insured dental users (n visits = ",
                      format(nrow(dv_cohort), big.mark = ","), ")"),
    x        = NULL,
    y        = "Proportion of visits",
    caption  = "Source: MEPS HC-248B (2023). Visit-level proportions, unweighted."
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(here("output", "service_mix.png"), p_mix,
       width = 8, height = 5, dpi = 150)
message("  Saved: output/service_mix.png")

# =============================================================================
# Descriptive Table 1 — analytic cohort
# =============================================================================

message("\nBuilding cohort descriptive table (Table 1)...")

# Select variables available in the cohort; skip gracefully if some are absent
table_vars_candidates <- c(
  "AGE23X", "SEX", "RACEV2X", "HISPANX",
  "POVCAT23", "EDUCYR", "EMPST53",
  "INSURC23", "RTHLTH53",
  "DVTOT23", "DVTEXP23", "DVTSLF23"
)
table_vars <- intersect(table_vars_candidates, names(analytic))

tbl <- analytic |>
  select(all_of(table_vars)) |>
  tbl_summary(
    statistic = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    missing = "ifany"
  ) |>
  modify_caption("**Table 1. National DLR cohort characteristics (unweighted), 2023**") |>
  bold_labels()

tbl |>
  as_gt() |>
  gt::gtsave(here("output", "table1_cohort.html"))

message("  Saved: output/table1_cohort.html")

message("\n03_dummy_analysis.R complete.")
