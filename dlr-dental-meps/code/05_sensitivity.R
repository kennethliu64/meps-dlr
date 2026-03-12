# =============================================================================
# 05_sensitivity.R
#
# PURPOSE: Sensitivity analysis — test robustness of primary model estimates
# (from 04_primary_models.R) to covariate specification.
#
# APPROACH: Re-estimate all three primary models using a minimal covariate set:
#   age23x, sex, racev2x, povcat23, insurc23, rthlth53
# These are the core demographic and health confounders considered most stable
# and least prone to post-treatment contamination or collinearity.
#
# INTERPRETATION: If sensitivity coefficients are similar in sign and magnitude
# to full-model coefficients (04_primary_models.R), results are robust to
# covariate choice. Large divergence would suggest confounding by the omitted
# variables (education, employment, activity limitations).
#
# IMPORTANT LIMITATION — SELF-INSURED / FULLY-INSURED MISCLASSIFICATION:
# MEPS does not distinguish self-insured employer plans (governed by ERISA;
# exempt from state insurance regulation) from fully-insured plans (subject to
# Massachusetts' DLR mandate). Individuals with self-insured coverage are
# incorrectly classified as DLR-affected. This measurement error is non-
# differential (direction of sponsorship is unrelated to dental outcomes
# conditional on covariates) and biases all estimates — full and sensitivity —
# toward the null (intention-to-treat attenuation). Sensitivity estimates are
# therefore not expected to resolve this bias; they test only covariate
# specification robustness.
#
# Input:  data/survey_design_2023.rds    (from 02_analytic_sample.R)
#         output/tables/model1_visits.csv
#         output/tables/model2_total_spend.csv
#         output/tables/model3_oop.csv
# Output: output/tables/model1_visits_sensitivity.csv
#         output/tables/model2_total_spend_sensitivity.csv
#         output/tables/model3_oop_sensitivity.csv
#         output/tables/sensitivity_comparison.csv
# =============================================================================

library(tidyverse)
library(survey)
library(broom)
library(here)

# Ensure output directory exists
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. Load survey design object
# =============================================================================

message("Loading survey design object...")
svy_design <- readRDS(here("data", "survey_design_2023.rds"))

# =============================================================================
# 2. Define minimal covariate formula
# =============================================================================
# Minimal set: core demographics and health status only.
# Omitted relative to full model: educyr, empst53, anylmi23

rhs_minimal <- ~ age23x + sex + racev2x + povcat23 + insurc23 + rthlth53

# Helper: fit sensitivity model, tidy, label, save
fit_sensitivity <- function(formula, design, model_name, outfile) {

  message("Fitting sensitivity model: ", model_name, "...")
  fit <- svyglm(formula, design = design, family = gaussian())

  results <- tidy(fit, conf.int = TRUE) |>
    mutate(
      model  = paste0(model_name, " (sensitivity)"),
      spec   = "minimal",
      outcome = as.character(formula[[2]])
    ) |>
    select(model, spec, outcome, term, estimate, std.error, statistic,
           p.value, conf.low, conf.high)

  write_csv(results, here("output", "tables", outfile))
  message("  Saved: output/tables/", outfile)

  invisible(results)
}

# =============================================================================
# 3. Sensitivity Model 1 — Dental visit frequency
# =============================================================================

sens_m1 <- fit_sensitivity(
  formula    = update(rhs_minimal, dvtot23 ~ .),
  design     = svy_design,
  model_name = "Model 1: Dental visits (count, OLS)",
  outfile    = "model1_visits_sensitivity.csv"
)

# =============================================================================
# 4. Sensitivity Model 2 — Total dental expenditures (log)
# =============================================================================

sens_m2 <- fit_sensitivity(
  formula    = update(rhs_minimal, log_dvtexp23 ~ .),
  design     = svy_design,
  model_name = "Model 2: Log total dental expenditures",
  outfile    = "model2_total_spend_sensitivity.csv"
)

# =============================================================================
# 5. Sensitivity Model 3 — Out-of-pocket dental expenditures (log)
# =============================================================================

sens_m3 <- fit_sensitivity(
  formula    = update(rhs_minimal, log_dvtslf23 ~ .),
  design     = svy_design,
  model_name = "Model 3: Log out-of-pocket dental expenditures",
  outfile    = "model3_oop_sensitivity.csv"
)

# =============================================================================
# 6. Side-by-side comparison: full vs. sensitivity models
# =============================================================================

message("Building full vs. sensitivity coefficient comparison table...")

# Load full-model results produced by 04_primary_models.R
full_files <- c(
  "model1_visits.csv",
  "model2_total_spend.csv",
  "model3_oop.csv"
)

full_results_list <- map(full_files, function(f) {
  path <- here("output", "tables", f)
  if (!file.exists(path)) {
    warning("Full model file not found: ", path,
            "\nRun 04_primary_models.R first.")
    return(NULL)
  }
  read_csv(path, show_col_types = FALSE) |>
    mutate(spec = "full")
})

full_results <- bind_rows(full_results_list)

# Stack full and sensitivity
sensitivity_results <- bind_rows(sens_m1, sens_m2, sens_m3)

comparison <- bind_rows(full_results, sensitivity_results) |>
  arrange(outcome, term, spec) |>
  select(outcome, term, spec, estimate, std.error, p.value, conf.low, conf.high)

# Print comparison to console
message("\n--- Full vs. sensitivity coefficient comparison ---")
print(comparison, n = Inf)

# Save comparison table
write_csv(comparison, here("output", "tables", "sensitivity_comparison.csv"))
message("\nSaved: output/tables/sensitivity_comparison.csv")

message("\n05_sensitivity.R complete.")
