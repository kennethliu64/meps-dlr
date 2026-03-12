# =============================================================================
# 04_primary_models.R
#
# NOTE: Full pre-post analysis requires 2024 data. This script runs baseline
# descriptive models on 2023 only. The DiD model structure is scaffolded at
# the bottom of this script and will be activated when 2024 MEPS data are
# released (expected late 2025 / 2026).
#
# Three survey-weighted regression models are estimated:
#   Model 1 — Dental visit frequency (dvtot23, count, OLS)
#   Model 2 — Total dental spending, log-transformed (log_dvtexp23, OLS)
#   Model 3 — Out-of-pocket dental spending, log-transformed (log_dvtslf23, OLS)
#
# All models use svyglm() with the MEPS complex survey design object.
# Results are tidied with broom::tidy() and saved as CSVs.
#
# Input:  data/survey_design_2023.rds  (from 02_analytic_sample.R)
# Output: output/tables/model1_visits.csv
#         output/tables/model2_total_spend.csv
#         output/tables/model3_oop.csv
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

message("  Unweighted N in design: ",
        nrow(svy_design$variables))

# =============================================================================
# 2. Define the right-hand side (covariate formula)
# =============================================================================
# Full covariate set for all three primary models:
#   age23x    — continuous age
#   sex       — sex (factor: Male / Female)
#   racev2x   — race/ethnicity (factor)
#   povcat23  — income category (factor: Poor … High income)
#   educyr    — years of education (continuous)
#   empst53   — employment status (factor)
#   insurc23  — insurance type (factor)
#   rthlth53  — self-rated health (factor: Excellent … Poor)
#   anylmi23  — any activity limitation (binary)

rhs_full <- ~ age23x + sex + racev2x + povcat23 + educyr +
               empst53 + insurc23 + rthlth53 + anylmi23

# Helper: fit svyglm, tidy, add model metadata, save
fit_and_save <- function(formula, design, family = gaussian(), model_name, outfile) {

  message("Fitting ", model_name, "...")
  fit <- svyglm(formula, design = design, family = family)

  # Tidy coefficient table: estimate, std error, t-stat, p-value, 95% CI
  results <- tidy(fit, conf.int = TRUE) |>
    mutate(
      model = model_name,
      outcome = as.character(formula[[2]])
    ) |>
    select(model, outcome, term, estimate, std.error, statistic, p.value,
           conf.low, conf.high)

  # Print to console
  message("  Coefficients for ", model_name, ":")
  print(results, n = Inf)

  # Save to CSV
  write_csv(results, here("output", "tables", outfile))
  message("  Saved: output/tables/", outfile)

  invisible(fit)
}

# =============================================================================
# 3. Model 1 — Dental visit frequency (dvtot23, continuous count)
# =============================================================================
# OLS via svyglm with Gaussian family. dvtot23 is right-skewed; a Poisson or
# negative binomial model may be preferable in future iterations but OLS with
# robust (Taylor-linearized) SEs is defensible here given the survey context.

formula_m1 <- update(rhs_full, dvtot23 ~ .)

fit_m1 <- fit_and_save(
  formula    = formula_m1,
  design     = svy_design,
  family     = gaussian(),
  model_name = "Model 1: Dental visits (count, OLS)",
  outfile    = "model1_visits.csv"
)

# =============================================================================
# 4. Model 2 — Total dental expenditures (log-transformed)
# =============================================================================
# log(dvtexp23 + 1) to handle zero-expenditure observations.
# Coefficients approximate % change in spending per unit change in predictor.

formula_m2 <- update(rhs_full, log_dvtexp23 ~ .)

fit_m2 <- fit_and_save(
  formula    = formula_m2,
  design     = svy_design,
  family     = gaussian(),
  model_name = "Model 2: Log total dental expenditures",
  outfile    = "model2_total_spend.csv"
)

# =============================================================================
# 5. Model 3 — Out-of-pocket dental expenditures (log-transformed)
# =============================================================================

formula_m3 <- update(rhs_full, log_dvtslf23 ~ .)

fit_m3 <- fit_and_save(
  formula    = formula_m3,
  design     = svy_design,
  family     = gaussian(),
  model_name = "Model 3: Log out-of-pocket dental expenditures",
  outfile    = "model3_oop.csv"
)

# =============================================================================
# 6. Model fit summaries
# =============================================================================

message("\n--- Model fit summaries ---")
for (obj in list(fit_m1, fit_m2, fit_m3)) {
  message(deparse(formula(obj)[[2]]),
          "  |  Residual df: ", obj$df.residual,
          "  |  Null deviance: ", round(obj$null.deviance, 1),
          "  |  Residual deviance: ", round(obj$deviance, 1))
}

# =============================================================================
# DiD SCAFFOLD — ACTIVATE WHEN 2024 MEPS DATA ARE AVAILABLE
# =============================================================================
# When HC-257 (2024 full-year consolidated) and HC-254B (2024 dental visits)
# are released, follow steps 01–02 for 2024, then stack the two years and run:
#
# # Stack 2023 (pre) and 2024 (post) analytic samples
# combined <- bind_rows(
#   readRDS(here("data", "analytic_sample_2023.rds")) |> mutate(year = 2023, post = 0),
#   readRDS(here("data", "analytic_sample_2024.rds")) |> mutate(year = 2024, post = 1)
# )
#
# # treated = 1 for MA residents with private dental insurance (DLR-affected)
# # treated = 1 is already implied by the restriction to dvtprv23 > 0 within MA.
# # If a national comparison group is added, treated = as.integer(state == "MA").
#
# # Re-create survey design on combined data (update weights variable name if needed)
# svy_did <- svydesign(
#   id      = ~varpsu,
#   strata  = ~varstr,
#   weights = ~perwt_f,       # confirm weight variable name for 2024
#   data    = combined,
#   nest    = TRUE
# )
#
# # DiD formula (no explicit 'treated' term needed when sample is MA-only;
# # 'post' coefficient is the pre-post estimate; add treated*post if using
# # a national comparison group)
# #
# # MA-only pre-post:
# #   dvtot ~ post + age + sex + racev2x + povcat + educyr + empst + insurc + rthlth + anylmi
# #
# # DiD with comparison group (e.g., other New England states without DLR):
# #   dvtot ~ treated * post + age + sex + racev2x + povcat + educyr + empst + insurc + rthlth + anylmi
# #
# # The coefficient on 'post' (MA-only) or 'treated:post' (DiD) is the causal estimate.
#
# fit_did_visits <- svyglm(
#   dvtot ~ treated * post + age + sex + racev2x + povcat + educyr +
#           empst + insurc + rthlth + anylmi,
#   design = svy_did,
#   family = gaussian()
# )
# tidy(fit_did_visits, conf.int = TRUE) |> print(n = Inf)

message("\n04_primary_models.R complete.")
