# =============================================================================
# 02_survey_design.R
# Build the MEPS complex survey design object and create two national-level
# subpopulation designs for downstream analysis.
#
# KEY METHOD NOTE: Subpopulations are created with subset() on the full design,
# NOT by filtering the data frame before calling svydesign(). Filtering rows
# first breaks variance estimation because the strata/PSU structure of the
# full sample must remain intact. subset() restricts which rows contribute to
# estimates while preserving the design structure.
#
# Two design objects are saved:
#   design_full — full national MEPS sample (all respondents)
#   design_dlr  — national DLR cohort: DVTPRV23 > 0 (used private dental insurance)
#
# MA-specific design objects are built in a separate script (04_ma_analysis.R)
# once the restricted-use file with STATECD is available.
#
# Input:  data/fyc_2023.rds  (from 01_download_data.R)
# Output: data/design_full_2023.rds
#         data/design_dlr_2023.rds
# =============================================================================

source(here::here("R", "00_setup.R"))

# =============================================================================
# 1. Load person-level data
# =============================================================================

message("Loading data/fyc_2023.rds...")
fyc <- readRDS(here("data", "fyc_2023.rds"))
message("  Rows: ", nrow(fyc))

# =============================================================================
# 2. Build the full national survey design
# =============================================================================
# MEPS uses a stratified multistage cluster design:
#   id      = VARPSU  — primary sampling unit
#   strata  = VARSTR  — variance stratum
#   weights = PERWT23F — final person-level analysis weight
#   nest    = TRUE    — PSU IDs restart within each stratum (required for MEPS)

message("Building full national survey design...")

design_full <- svydesign(
  id      = ~VARPSU,
  strata  = ~VARSTR,
  weights = ~PERWT23F,
  data    = fyc,
  nest    = TRUE
)

message("  Full design: ",
        format(nrow(fyc), big.mark = ","), " persons | ",
        "Weighted N: ", format(round(sum(fyc$PERWT23F)), big.mark = ","))

# =============================================================================
# 3. DLR cohort: DVTPRV23 > 0
# =============================================================================
# Restricts to individuals whose dental care was paid at least partly by
# private insurance — the population proxied as DLR-affected.
#
# LIMITATION: MEPS does not distinguish self-insured (ERISA; state-exempt)
# from fully-insured plans. Both have DVTPRV23 > 0. Self-insured plan holders
# are misclassified as DLR-affected, attenuating all estimates toward null.
# All results should be interpreted as intention-to-treat.

message("Creating DLR cohort subpopulation (DVTPRV23 > 0)...")

design_dlr <- subset(design_full, DVTPRV23 > 0)

dlr_n        <- nrow(design_dlr$variables)
dlr_weighted <- round(sum(design_dlr$variables$PERWT23F))
message("  DLR cohort: ",
        format(dlr_n, big.mark = ","), " persons | ",
        "Weighted N: ", format(dlr_weighted, big.mark = ","))

# =============================================================================
# 4. Save design objects
# =============================================================================

saveRDS(design_full, here("data", "design_full_2023.rds"))
saveRDS(design_dlr,  here("data", "design_dlr_2023.rds"))

message("\nSaved:")
message("  data/design_full_2023.rds")
message("  data/design_dlr_2023.rds")

message("\n02_survey_design.R complete.")
