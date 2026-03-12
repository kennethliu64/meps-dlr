# =============================================================================
# 02_analytic_sample.R
# Define the analytic sample, create derived variables, factorize categoricals,
# and set up the complex survey design object.
#
# Input:  data/ma_2023_clean.rds  (created by 01_load_clean.R)
# Output: data/analytic_sample_2023.rds
#         data/survey_design_2023.rds
# =============================================================================

library(tidyverse)
library(survey)
library(srvyr)
library(labelled)
library(here)

# =============================================================================
# 1. Load cleaned MA person-level data
# =============================================================================

message("Loading data/ma_2023_clean.rds...")
ma <- readRDS(here("data", "ma_2023_clean.rds"))
message("  Rows: ", nrow(ma), " | Cols: ", ncol(ma))

# =============================================================================
# 2. Restrict to the DLR-affected analytic sample
# =============================================================================
# The DLR law applies to private dental insurers.
# dvtprv23 > 0 identifies individuals whose dental care was at least partly
# paid by private dental insurance — the population directly exposed to the law.
#
# NOTE: MEPS does not distinguish self-insured (ERISA-governed, state-exempt)
# from fully-insured plans. This is an intention-to-treat restriction; some
# individuals with dvtprv23 > 0 may have self-insured coverage and be unaffected
# by the DLR mandate. All estimates are therefore attenuated toward null.

message("Restricting to privately insured dental users (dvtprv23 > 0)...")

analytic <- ma |>
  filter(dvtprv23 > 0)

message("  Analytic sample N = ", nrow(analytic))

# =============================================================================
# 3. Create derived outcome variables
# =============================================================================

message("Creating derived variables...")

analytic <- analytic |>
  mutate(
    # Binary: any dental visit in 2023 (1 = yes, 0 = no)
    any_dental_visit = as.integer(dvtot23 > 0),

    # Log-transformed spending (log(x + 1) to handle zeros)
    log_dvtexp23 = log(dvtexp23 + 1),   # log total dental expenditures
    log_dvtslf23 = log(dvtslf23 + 1)    # log out-of-pocket dental expenditures
  )

# =============================================================================
# 4. Factorize categorical variables with meaningful labels
# =============================================================================

message("Factorizing categorical variables...")

analytic <- analytic |>
  mutate(

    # --- Sex ---
    # MEPS codes: 1 = Male, 2 = Female
    sex = factor(sex,
                 levels = c(1, 2),
                 labels = c("Male", "Female")),

    # --- Race/Ethnicity (racev2x) ---
    # MEPS Version 2 race variable (does not include Hispanic ethnicity — that is
    # captured separately in hispanx). Full codebook values:
    #   1 = White — no other race reported
    #   2 = Black — no other race reported
    #   3 = American Indian / Alaska Native — no other race reported
    #   4 = Asian — no other race reported
    #   5 = Native Hawaiian / Pacific Islander — no other race reported
    #   6 = Multiple races reported
    #  -1 = Inapplicable (age < 1)
    racev2x = factor(racev2x,
                     levels = c(1, 2, 3, 4, 5, 6, -1),
                     labels = c(
                       "White",
                       "Black",
                       "American Indian/Alaska Native",
                       "Asian",
                       "Native Hawaiian/Pacific Islander",
                       "Multiple races",
                       "Inapplicable"
                     )),

    # --- Hispanic ethnicity ---
    # 1 = Hispanic, 2 = Not Hispanic
    hispanx = factor(hispanx,
                     levels = c(1, 2),
                     labels = c("Hispanic", "Not Hispanic")),

    # --- Poverty category (povcat23) ---
    # 1 = Poor/Negative income (< 100% FPL)
    # 2 = Near poor (100–124% FPL)
    # 3 = Low income (125–199% FPL)
    # 4 = Middle income (200–399% FPL)
    # 5 = High income (≥ 400% FPL)
    povcat23 = factor(povcat23,
                      levels = 1:5,
                      labels = c(
                        "Poor",
                        "Near poor",
                        "Low income",
                        "Middle income",
                        "High income"
                      )),

    # --- Self-reported health status (rthlth53) ---
    # Round 5 (closest to year-end); 1 = Excellent … 5 = Poor
    rthlth53 = factor(rthlth53,
                      levels = 1:5,
                      labels = c(
                        "Excellent",
                        "Very good",
                        "Good",
                        "Fair",
                        "Poor"
                      )),

    # --- Employment status (empst53, Round 5) ---
    # 1 = Employed, 2 = Unemployed, 3 = Not in labor force, -1 = Inapplicable
    empst53 = factor(empst53,
                     levels = c(1, 2, 3, -1),
                     labels = c(
                       "Employed",
                       "Unemployed",
                       "Not in labor force",
                       "Inapplicable"
                     )),

    # --- Insurance coverage (insurc23) ---
    # Collapsed to major categories; see HC-251 codebook for full detail.
    # Common codes:
    #  1 = Any private (includes employer + individual)
    #  2 = Public only (Medicaid, Medicare, or other public)
    #  3 = Uninsured all year
    # (Additional codes exist for mixed/partial-year coverage)
    insurc23 = factor(insurc23)
  )

message("  Factorization complete.")

# =============================================================================
# 5. Set up complex survey design object
# =============================================================================
# MEPS uses a stratified multistage cluster design.
# - id       = PSU (primary sampling unit): varpsu
# - strata   = variance stratum: varstr
# - weights  = final person-level weight: perwt23f
# - nest=TRUE ensures PSU IDs are interpreted as nested within strata
#              (MEPS PSU codes restart within each stratum)

message("Setting up survey design object...")

svy_design <- svydesign(
  id      = ~varpsu,
  strata  = ~varstr,
  weights = ~perwt23f,
  data    = analytic,
  nest    = TRUE
)

message("  Survey design created.")
message("  Unweighted N: ", nrow(analytic))
message("  Weighted N (sum of weights): ",
        format(round(sum(analytic$perwt23f)), big.mark = ","))

# =============================================================================
# 6. Save outputs
# =============================================================================

message("Saving analytic sample to data/analytic_sample_2023.rds...")
saveRDS(analytic, here("data", "analytic_sample_2023.rds"))

message("Saving survey design object to data/survey_design_2023.rds...")
saveRDS(svy_design, here("data", "survey_design_2023.rds"))

message("\n02_analytic_sample.R complete.")
