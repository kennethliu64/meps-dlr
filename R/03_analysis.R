# =============================================================================
# 03_analysis.R
# Weighted estimates for all three research questions.
#
# Point `design_path` at whichever design object you want to analyze —
# the analysis is identical regardless of whether the cohort is national,
# state-level, or any other subpopulation. Build the design you need in
# 02_survey_design.R, save it as an .rds, and point this script at it.
#
# Q1: Dental visit frequency (DVTOT23)
# Q2: Total and out-of-pocket dental expenditures (DVTEXP23, DVTSLF23)
# Q3: Dental service mix (procedure flags from HC-248B)
#
# Input:  data/<your_design>.rds   (from 02_survey_design.R)
#         data/dv_2023.rds         (from 01_download_data.R)
# Output: output/<label>_table1_cohort.html   — survey-weighted cohort characteristics
#         output/<label>_descriptive.html     — formatted Q1/Q2/Q3 results (human-readable)
#         output/<label>_models.html          — all 5 adjusted models in one table
#         output/<label>_service_mix.png      — bar chart of procedure mix
#         output/<label>_q1_visits.csv        — raw Q1 estimates (programmatic use)
#         output/<label>_q2_spending.csv      — raw Q2 estimates (programmatic use)
#         output/<label>_q3_service_mix.csv   — raw Q3 estimates (programmatic use)
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

dir.create(here("output"), showWarnings = FALSE)

# =============================================================================
# Configuration — change these two lines to switch cohorts
# =============================================================================

design_path      <- here("data", "design_dlr_2023.rds")   # path to design object
design_full_path <- here("data", "design_full_2023.rds")  # full design (same year — needed for Q3)
label            <- "dlr_2023"                             # prefix for output files

# =============================================================================
# 1. Load data
# =============================================================================

message("Loading survey design and dental visits data...")
design_analysis <- readRDS(design_path)
design_full     <- readRDS(design_full_path)  # needed for Q3
dv_raw          <- readRDS(here("data", "dv_2023.rds"))

analytic <- design_analysis$variables

message("  Cohort (", label, "): ",
        format(nrow(analytic), big.mark = ","), " unweighted | ",
        format(round(sum(analytic$PERWT23F)), big.mark = ","), " weighted")

out_path <- function(filename) here("output", paste0(label, "_", filename))

# =============================================================================
# Q1 — Dental visit frequency (DVTOT23)
# =============================================================================

message("\nQ1: Dental visit access and frequency...")

q1_any   <- svymean(~I(as.numeric(DVTOT23 > 0)), design = design_analysis, na.rm = TRUE)
q1_mean  <- svymean(~DVTOT23,        design = design_analysis, na.rm = TRUE)
q1_total <- svytotal(~DVTOT23,       design = design_analysis, na.rm = TRUE)

message("  Weighted prob any visit: ", round(coef(q1_any), 3),
        " (SE: ", round(SE(q1_any), 3), ")")
message("  Weighted mean visits:    ", round(coef(q1_mean), 3),
        " (SE: ", round(SE(q1_mean), 3), ")")

q1_ci_any   <- confint(q1_any)
q1_ci_mean  <- confint(q1_mean)
q1_ci_total <- confint(q1_total)

q1_out <- tibble(
  metric   = c("prob_any_visit", "mean_visits", "total_visits"),
  estimate = c(coef(q1_any),       coef(q1_mean),       coef(q1_total)),
  se       = c(SE(q1_any),         SE(q1_mean),         SE(q1_total)),
  ci_lower = c(q1_ci_any[, 1],     q1_ci_mean[, 1],     q1_ci_total[, 1]),
  ci_upper = c(q1_ci_any[, 2],     q1_ci_mean[, 2],     q1_ci_total[, 2])
)
write_csv(q1_out, out_path("q1_visits.csv"))
message("  Saved: ", out_path("q1_visits.csv"))

# =============================================================================
# Q2 — Total and out-of-pocket dental spending
# =============================================================================

message("\nQ2: Dental spending...")

q2_mean <- svymean(~DVTEXP23 + DVTSLF23 + DVTPRV23, design = design_analysis, na.rm = TRUE)

message("  Weighted mean total expenditure:   $", round(coef(q2_mean)["DVTEXP23"], 2))
message("  Weighted mean OOP expenditure:     $", round(coef(q2_mean)["DVTSLF23"], 2))
message("  Weighted mean insurer payout:      $", round(coef(q2_mean)["DVTPRV23"], 2))

q2_ci <- confint(q2_mean)

q2_out <- tibble(
  outcome  = names(coef(q2_mean)),
  mean     = coef(q2_mean),
  se       = SE(q2_mean),
  ci_lower = q2_ci[, 1],
  ci_upper = q2_ci[, 2]
)
write_csv(q2_out, out_path("q2_spending.csv"))
message("  Saved: ", out_path("q2_spending.csv"))

# =============================================================================
# Q3 — Dental service mix (from event-level file HC-248B)
# =============================================================================

message("\nQ3: Dental service mix...")

procedure_vars <- c(
  "EXAMINEX", "JUSTXRYX", "CLENTETX", "FLUORIDX", "SEALANTX",
  "FILLINGX", "ROOTCANX", "GUMSURGX", "ORALSURX", "IMPLANTX",
  "BRIDGESX", "DENTPROX", "DENTOTHX", "ORTHDONX"
)

existing_proc_vars <- intersect(procedure_vars, names(dv_raw))

if (length(existing_proc_vars) == 0) {
  stop("No procedure variables found in HC-248B. ",
       "Verify the file against the HC-248B codebook for this panel year.")
}

# Collapse visit-level flags to person level: did this person have *any* visit
# of each type? HC-248B has no visit-level weights; the AHRQ-recommended
# approach is to aggregate to person level and apply person weights via the
# design object. This also avoids inflating proportions for frequent visitors.
dv_person <- dv_raw |>
  select(DUPERSID, all_of(existing_proc_vars)) |>
  group_by(DUPERSID) |>
  summarise(
    across(all_of(existing_proc_vars),
           ~ as.integer(any(.x == 1, na.rm = TRUE)),
           .names = "{.col}"),
    .groups = "drop"
  )

# Merge onto the FULL person-level frame (from design_full), then subset.
# IMPORTANT: svydesign() must be built from the complete sample so that all
# strata/PSU combinations are present for correct variance estimation.
# Merging onto the filtered analytic frame would silently discard strata,
# breaking SEs — the same anti-pattern as filtering before svydesign().
fyc_q3 <- design_full$variables |>
  left_join(dv_person, by = "DUPERSID") |>
  mutate(across(all_of(existing_proc_vars),
                ~ replace_na(.x, 0L)))  # persons with no dental visits → 0

design_q3 <- svydesign(
  id      = ~VARPSU,
  strata  = ~VARSTR,
  weights = ~PERWT23F,
  data    = fyc_q3,
  nest    = TRUE
)
design_q3 <- subset(design_q3, DNTINS31_M23 == 1 | DNTINS23_M23 == 1)

svy_formula_q3 <- as.formula(paste("~", paste(existing_proc_vars, collapse = " + ")))
q3_means <- svymean(svy_formula_q3, design = design_q3, na.rm = TRUE)

service_props <- tibble(
  procedure  = names(coef(q3_means)),
  proportion = coef(q3_means),
  se         = SE(q3_means)
) |>
  mutate(procedure = factor(procedure, levels = existing_proc_vars)) |>
  arrange(desc(proportion))

print(service_props, n = Inf)
write_csv(service_props, out_path("q3_service_mix.csv"))
message("  Saved: ", out_path("q3_service_mix.csv"))

# ---- Bar chart of service mix -----------------------------------------------

service_labels <- c(
  EXAMINEX = "Examination",
  JUSTXRYX = "X-ray",
  CLENTETX = "Cleaning",
  FLUORIDX = "Fluoride",
  SEALANTX = "Sealant",
  FILLINGX = "Filling",
  ROOTCANX = "Root canal",
  GUMSURGX = "Gum surgery",
  ORALSURX = "Oral surgery/extraction",
  IMPLANTX = "Implant",
  BRIDGESX = "Bridge",
  DENTPROX = "Dental prosthesis",
  DENTOTHX = "Other dental",
  ORTHDONX = "Orthodontics"
)

p_mix <- service_props |>
  mutate(proc_label = service_labels[as.character(procedure)]) |>
  ggplot(aes(x = reorder(proc_label, proportion), y = proportion)) +
  geom_col(fill = "#2166ac", alpha = 0.85) +
  geom_text(aes(label = scales::percent(proportion, accuracy = 0.1)),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = paste0("Dental service mix — ", label),
    subtitle = paste0("n persons (DLR cohort) = ", format(nrow(analytic), big.mark = ",")),
    x        = NULL,
    y        = "Proportion of persons with any visit of type",
    caption  = "Source: MEPS HC-248B + HC-251. Person-level weighted prevalence."
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(out_path("service_mix.png"), p_mix, width = 8, height = 5, dpi = 150)
message("  Saved: ", out_path("service_mix.png"))

# =============================================================================
# Covariate-adjusted models
# =============================================================================

message("\nFitting covariate-adjusted models...")

fit_q1_any <- svyglm(update(formula_apriori, I(DVTOT23 > 0) ~ .),
                     design = design_analysis, family = quasibinomial())
fit_q1     <- svyglm(update(formula_apriori, DVTOT23 ~ .),
                     design = design_analysis, family = quasipoisson())
fit_q2a    <- svyglm(update(formula_apriori, log(DVTEXP23 + 1) ~ .),
                     design = design_analysis, family = gaussian())
fit_q2b    <- svyglm(update(formula_apriori, log(DVTSLF23 + 1) ~ .),
                     design = design_analysis, family = gaussian())
fit_q2c    <- svyglm(update(formula_apriori, log(DVTPRV23 + 1) ~ .),
                     design = design_analysis, family = gaussian())

tbl_models <- tbl_merge(
  list(
    tbl_regression(fit_q1_any, exponentiate = TRUE),
    tbl_regression(fit_q1,     exponentiate = TRUE),
    tbl_regression(fit_q2a,    exponentiate = FALSE),
    tbl_regression(fit_q2b,    exponentiate = FALSE),
    tbl_regression(fit_q2c,    exponentiate = FALSE)
  ),
  tab_spanner = c(
    "**Any visit** (OR)",
    "**Visit count** (IRR)",
    "**Total spend** (log \u03b2)",
    "**OOP spend** (log \u03b2)",
    "**Insurer payout** (log \u03b2)"
  )
) |>
  modify_caption(paste0(
    "**Covariate-adjusted models — ", label, "**<br>",
    "OR = odds ratio; IRR = incidence rate ratio; ",
    "log \u03b2 = coefficient on log(y+1) scale."
  )) |>
  bold_labels()

tbl_models |>
  as_gt() |>
  gt::gtsave(out_path("models.html"))
message("  Saved: ", out_path("models.html"))

# =============================================================================
# Formatted descriptive results (Q1 + Q2 + Q3 in one HTML)
# =============================================================================

message("\nBuilding formatted descriptive results...")

q3_ci <- confint(q3_means)

q1_gt <- tibble(
  Metric = c("Any dental visit", "Mean visits per person", "Total visits (population)"),
  Estimate = c(
    scales::percent(coef(q1_any),    accuracy = 0.1),
    sprintf("%.2f",                  coef(q1_mean)),
    scales::comma(round(            coef(q1_total)))
  ),
  `95% CI` = c(
    paste0(scales::percent(q1_ci_any[, 1],   0.1), "\u2013", scales::percent(q1_ci_any[, 2],   0.1)),
    paste0(sprintf("%.2f", q1_ci_mean[, 1]),  "\u2013", sprintf("%.2f", q1_ci_mean[, 2])),
    paste0(scales::comma(round(q1_ci_total[, 1])), "\u2013", scales::comma(round(q1_ci_total[, 2])))
  )
) |>
  gt() |>
  tab_header(title = "Q1: Dental visit access and frequency") |>
  tab_source_note("Survey-weighted. DLR cohort: individuals with dental insurance at any point in the survey year.")

q2_gt <- tibble(
  Outcome = c("Total expenditures", "Out-of-pocket", "Insurer payout"),
  `Mean (survey-weighted)` = scales::dollar(coef(q2_mean), accuracy = 1),
  `95% CI` = paste0(
    scales::dollar(q2_ci[, 1], accuracy = 1), "\u2013",
    scales::dollar(q2_ci[, 2], accuracy = 1)
  )
) |>
  gt() |>
  tab_header(title = "Q2: Dental spending (annual per-person)") |>
  tab_source_note("Survey-weighted. DVTPRV23 is zero for insured individuals with no dental visits.")

q3_gt <- service_props |>
  mutate(
    Procedure  = service_labels[as.character(procedure)],
    Prevalence = scales::percent(proportion, accuracy = 0.1),
    `95% CI`   = paste0(
      scales::percent(pmax(0, q3_ci[as.character(procedure), 1]), 0.1), "\u2013",
      scales::percent(q3_ci[as.character(procedure), 2], 0.1)
    )
  ) |>
  select(Procedure, Prevalence, `95% CI`) |>
  gt() |>
  tab_header(title = "Q3: Dental service mix") |>
  tab_source_note("Person-level weighted prevalence: proportion of DLR cohort with any visit of each type.")

writeLines(
  paste0(
    "<!DOCTYPE html><html><head>",
    "<style>body{font-family:sans-serif;margin:2em;max-width:900px}</style>",
    "</head><body>",
    "<h1>Descriptive Results \u2014 ", label, "</h1>",
    gt::as_raw_html(q1_gt), "<br>",
    gt::as_raw_html(q2_gt), "<br>",
    gt::as_raw_html(q3_gt),
    "</body></html>"
  ),
  out_path("descriptive.html")
)
message("  Saved: ", out_path("descriptive.html"))

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

tbl <- design_analysis |>
  tbl_svysummary(
    include    = all_of(table_vars),
    statistic  = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n_unweighted} ({p}%)"
    ),
    missing = "ifany"
  ) |>
  modify_caption(paste0("**Table 1. Cohort characteristics (survey-weighted) — ", label, "**")) |>
  bold_labels()

tbl |>
  as_gt() |>
  gt::gtsave(out_path("table1_cohort.html"))

message("  Saved: ", out_path("table1_cohort.html"))

message("\n03_analysis.R complete (", label, ").")
