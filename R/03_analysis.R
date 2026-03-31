# =============================================================================
# 03_analysis.R
# Weighted estimates for all three research questions using the MEPS survey
# design objects from 02_survey_design.R.
#
# Supports two scopes — set the `scope` variable below:
#
#   scope = "national"  — full U.S. DLR cohort (public-use file, default)
#   scope = "ma"        — Massachusetts only (requires restricted-use file
#                          with STATECD; MA FIPS = 25)
#
# Q1: Dental visit frequency (DVTOT23)
# Q2: Total and out-of-pocket dental expenditures (DVTEXP23, DVTSLF23)
# Q3: Dental service mix (procedure flags from HC-248B)
#
# Input:  data/design_full_2023.rds   (from 02_survey_design.R)
#         data/design_dlr_2023.rds    (from 02_survey_design.R)
#         data/dv_2023.rds            (from 01_download_data.R)
# Output: output/<scope>_table1_cohort.html
#         output/<scope>_service_mix.png
#         output/<scope>_q1_visits.csv
#         output/<scope>_q2_spending.csv
#         output/<scope>_q3_service_mix.csv
#         output/<scope>_q1_visits_adjusted.csv
#         output/<scope>_q2a_total_spend_adjusted.csv
#         output/<scope>_q2b_oop_spend_adjusted.csv
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

dir.create(here("output"), showWarnings = FALSE)

# =============================================================================
# Configuration — set scope here
# =============================================================================

scope <- "national"   # "national" or "ma"

# State variable name (only used when scope = "ma")
state_var <- "STATECD"

# =============================================================================
# 1. Load data and build the analysis design
# =============================================================================

message("Loading survey design and dental visits data...")
design_full <- readRDS(here("data", "design_full_2023.rds"))
design_dlr  <- readRDS(here("data", "design_dlr_2023.rds"))
dv_raw      <- readRDS(here("data", "dv_2023.rds"))

if (scope == "ma") {
  # Verify state variable exists
  if (!state_var %in% names(design_full$variables)) {
    stop("State variable '", state_var, "' not found in design data.\n",
         "The public-use file does not include state identifiers.\n",
         "Use scope = \"national\" or provide the restricted-use file.")
  }

  message("Scope: MA — subsetting to ", state_var, " == 25 with dental insurance...")
  design_analysis <- subset(design_full,
                            design_full$variables[[state_var]] == 25 &
                              (DNTINS31_M23 == 1 | DNTINS23_M23 == 1))
  scope_label <- "MA DLR cohort"
} else {
  message("Scope: National DLR cohort...")
  design_analysis <- design_dlr
  scope_label <- "National DLR cohort"
}

analytic <- design_analysis$variables

message("  ", scope_label, ": ",
        format(nrow(analytic), big.mark = ","), " unweighted | ",
        format(round(sum(analytic$PERWT23F)), big.mark = ","), " weighted")

# Helper: prefix output filenames with scope
out_path <- function(filename) here("output", paste0(scope, "_", filename))

# =============================================================================
# Q1 — Dental visit frequency (DVTOT23)
# =============================================================================

message("\nQ1: Dental visit frequency...")

q1_mean  <- svymean(~DVTOT23, design = design_analysis, na.rm = TRUE)
q1_total <- svytotal(~DVTOT23, design = design_analysis, na.rm = TRUE)

message("  Weighted mean visits: ", round(coef(q1_mean), 3),
        " (SE: ", round(SE(q1_mean), 3), ")")

q1_out <- tibble(
  metric   = c("mean_visits", "total_visits"),
  estimate = c(coef(q1_mean), coef(q1_total)),
  se       = c(SE(q1_mean), SE(q1_total))
)
write_csv(q1_out, out_path("q1_visits.csv"))
message("  Saved: ", out_path("q1_visits.csv"))

# =============================================================================
# Q2 — Total and out-of-pocket dental spending
# =============================================================================

message("\nQ2: Dental spending...")

q2_mean <- svymean(~DVTEXP23 + DVTSLF23, design = design_analysis, na.rm = TRUE)

message("  Weighted mean total expenditure: $", round(coef(q2_mean)["DVTEXP23"], 2))
message("  Weighted mean OOP expenditure:   $", round(coef(q2_mean)["DVTSLF23"], 2))

q2_out <- tibble(
  outcome = names(coef(q2_mean)),
  mean    = coef(q2_mean),
  se      = SE(q2_mean)
)
write_csv(q2_out, out_path("q2_spending.csv"))
message("  Saved: ", out_path("q2_spending.csv"))

# =============================================================================
# Q3 — Dental service mix (from event-level file HC-248B)
# =============================================================================

message("\nQ3: Dental service mix...")

dlr_ids <- unique(analytic$DUPERSID)

procedure_vars <- c(
  "EXAMEX", "XRAYX", "CLNNGX", "FLRIDEX", "SEALNTX",
  "FILLNGX", "CROWNX", "ROOTCAX", "EXTRACTX", "IMPLNTX",
  "BRIDGEX", "DENTURX", "ORTHDONX"
)

existing_proc_vars <- intersect(procedure_vars, names(dv_raw))

dv_cohort <- dv_raw |>
  filter(DUPERSID %in% dlr_ids) |>
  select(DUPERSID, all_of(existing_proc_vars))

service_props <- dv_cohort |>
  summarise(
    across(all_of(existing_proc_vars),
           ~ mean(.x == 1, na.rm = TRUE),
           .names = "{.col}")
  ) |>
  pivot_longer(everything(), names_to = "procedure", values_to = "proportion") |>
  mutate(
    n_visits  = nrow(dv_cohort),
    procedure = factor(procedure, levels = existing_proc_vars)
  ) |>
  arrange(desc(proportion))

print(service_props, n = Inf)
write_csv(service_props, out_path("q3_service_mix.csv"))
message("  Saved: ", out_path("q3_service_mix.csv"))

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
    title    = paste0("Dental service mix — ", scope_label, ", 2023"),
    subtitle = paste0("Dentally-insured individuals (n visits = ",
                      format(nrow(dv_cohort), big.mark = ","), ")"),
    x        = NULL,
    y        = "Proportion of visits",
    caption  = "Source: MEPS HC-248B (2023). Visit-level proportions, unweighted."
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(out_path("service_mix.png"), p_mix, width = 8, height = 5, dpi = 150)
message("  Saved: ", out_path("service_mix.png"))

# =============================================================================
# Covariate-adjusted models
# =============================================================================

message("\nFitting covariate-adjusted models...")

# Q1 adjusted — dental visit frequency
fit_q1_apriori  <- svyglm(update(formula_apriori,  DVTOT23 ~ .),
                           design = design_analysis, family = gaussian())
fit_q1_extended <- svyglm(update(formula_extended, DVTOT23 ~ .),
                           design = design_analysis, family = gaussian())

# Q2a adjusted — total dental expenditures (log)
fit_q2a_apriori  <- svyglm(update(formula_apriori,  log(DVTEXP23 + 1) ~ .),
                            design = design_analysis, family = gaussian())
fit_q2a_extended <- svyglm(update(formula_extended, log(DVTEXP23 + 1) ~ .),
                            design = design_analysis, family = gaussian())

# Q2b adjusted — out-of-pocket expenditures (log)
fit_q2b_apriori  <- svyglm(update(formula_apriori,  log(DVTSLF23 + 1) ~ .),
                            design = design_analysis, family = gaussian())
fit_q2b_extended <- svyglm(update(formula_extended, log(DVTSLF23 + 1) ~ .),
                            design = design_analysis, family = gaussian())

model_pairs <- list(
  list(apriori = fit_q1_apriori,  extended = fit_q1_extended,
       name = "q1_visits"),
  list(apriori = fit_q2a_apriori, extended = fit_q2a_extended,
       name = "q2a_total_spend"),
  list(apriori = fit_q2b_apriori, extended = fit_q2b_extended,
       name = "q2b_oop_spend")
)

for (m in model_pairs) {
  out <- bind_rows(
    broom::tidy(m$apriori,  conf.int = TRUE) |> mutate(covariate_set = "apriori"),
    broom::tidy(m$extended, conf.int = TRUE) |> mutate(covariate_set = "extended")
  )
  write_csv(out, out_path(paste0(m$name, "_adjusted.csv")))
  message("  Saved: ", out_path(paste0(m$name, "_adjusted.csv")))
}

# =============================================================================
# Descriptive Table 1
# =============================================================================

message("\nBuilding cohort descriptive table (Table 1)...")

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
  modify_caption(paste0("**Table 1. ", scope_label, " characteristics (unweighted), 2023**")) |>
  bold_labels()

tbl |>
  as_gt() |>
  gt::gtsave(out_path("table1_cohort.html"))

message("  Saved: ", out_path("table1_cohort.html"))

message("\n03_analysis.R complete (scope: ", scope, ").")
