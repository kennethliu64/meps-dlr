# =============================================================================
# 02_survey_design.R
# Build the MEPS complex survey design object and create the DLR
# subpopulation design for downstream analysis.
#
# KEY METHOD NOTE: Subpopulations are created with subset() on the full design,
# NOT by filtering the data frame before calling svydesign(). Filtering rows
# first breaks variance estimation because the strata/PSU structure of the
# full sample must remain intact. subset() restricts which rows contribute to
# estimates while preserving the design structure.
#
# Two design objects are saved:
#   design_full — all respondents in the input data
#   design_dlr  — DLR cohort: had dental insurance at any point in 2023
#                 (DNTINS31_M23 == 1 | DNTINS23_M23 == 1)
#
# The same pipeline works for both the national public-use file and a
# state-specific restricted-use file — just swap the .dta in data/.
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
# 2. Recode categorical covariates as factors
# =============================================================================
# These MEPS variables are integer-coded categories with no ordinal meaning.
# Treating them as numeric in svyglm would impose a spurious linear slope
# across arbitrarily-ordered codes (e.g., race codes 1–6 are not a scale).
# Converting here ensures the correct type travels with the design object.
#
#   SEX      1=Male, 2=Female
#   RACEV2X  1=White, 2=Black, 3=AIAN, 4=Asian/NHPI, 6=Multiple races
#   POVCAT23 1=Poor, 2=Near poor, 3=Low income, 4=Middle income, 5=High income
#   EMPST53  1=Employed, 2=Unemployed, 3=Not in labor force

message("Recoding categorical covariates as factors...")

fyc <- fyc |>
  mutate(
    SEX      = factor(SEX,      levels = c(1, 2),
                      labels = c("Male", "Female")),
    RACEV2X  = factor(RACEV2X,  levels = c(1, 2, 3, 4, 6),
                      labels = c("White", "Black", "AIAN", "Asian/NHPI", "Multiple")),
    POVCAT23 = factor(POVCAT23, levels = 1:5,
                      labels = c("Poor", "Near poor", "Low income",
                                 "Middle income", "High income")),
    EMPST53  = factor(EMPST53,  levels = c(1, 2, 3),
                      labels = c("Employed", "Unemployed", "Not in labor force"))
  )

message("  SEX, RACEV2X, POVCAT23, EMPST53 converted to factors.")

# =============================================================================
# 3. Build the full national survey design
# =============================================================================
# MEPS uses a stratified multistage cluster design:
#   id      = VARPSU  — primary sampling unit
#   strata  = VARSTR  — variance stratum
#   weights = PERWT23F — final person-level analysis weight
#   nest    = TRUE    — PSU IDs restart within each stratum (required for MEPS)

message("Building full survey design...")

design_full <- svydesign(
  id      = ~VARPSU,
  strata  = ~VARSTR,
  weights = ~PERWT23F,
  data    = fyc,
  nest    = TRUE
)

message("  Design: ",
        format(nrow(fyc), big.mark = ","), " persons | ",
        "Weighted N: ", format(round(sum(fyc$PERWT23F)), big.mark = ","))

# =============================================================================
# 4. DLR cohort: DNTINS31_M23 == 1 | DNTINS23_M23 == 1
# =============================================================================
# Restricts to individuals who had dental insurance at any point in 2023.
#
# MEPS collects insurance data across multiple interview rounds within a year.
# Two dental insurance variables cover complementary windows:
#   DNTINS31_M23 — dental insurance at any time in Round 3 / Period 1 (early 2023)
#   DNTINS23_M23 — dental insurance at any time in R5/R3 through 12/31/2023 (later 2023)
# Using OR captures anyone with dental coverage during any part of the year,
# consistent with how MEPS constructs its own full-year insurance summaries.
#
# WHY DENTAL-SPECIFIC VARIABLES INSTEAD OF DVTPRV23 > 0:
# Using DVTPRV23 > 0 (private insurance paid for dental care) conditions on
# the outcome — it excludes dentally-insured people who didn't go to the
# dentist, which is exactly the group where the DLR law may have had an effect.
# That would bias the sample toward dental users and make it impossible to
# detect whether the law increased utilization from zero.
# DNTINS variables define eligibility by coverage status, not utilization.
#
# DVTPRV23 remains in the data as an outcome variable (did private insurance
# pay anything? how much?) — it is not used for sample selection.
#
# LIMITATION: MEPS does not distinguish self-insured (ERISA-exempt) from
# fully-insured dental plans. Self-insured plan holders are not subject to
# the MA DLR mandate. All estimates are intention-to-treat and likely
# attenuated toward null.

message("Creating DLR cohort subpopulation (DNTINS31_M23 == 1 | DNTINS23_M23 == 1)...")

design_dlr <- subset(design_full, DNTINS31_M23 == 1 | DNTINS23_M23 == 1)

dlr_n        <- nrow(design_dlr$variables)
dlr_weighted <- round(sum(design_dlr$variables$PERWT23F))
message("  DLR cohort: ",
        format(dlr_n, big.mark = ","), " persons | ",
        "Weighted N: ", format(dlr_weighted, big.mark = ","))

# =============================================================================
# 5. Save design objects
# =============================================================================

saveRDS(design_full, here("data", "design_full_2023.rds"))
saveRDS(design_dlr,  here("data", "design_dlr_2023.rds"))

message("\nSaved:")
message("  data/design_full_2023.rds")
message("  data/design_dlr_2023.rds")

message("\n02_survey_design.R complete.")
