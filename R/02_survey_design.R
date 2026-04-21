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
#   AHRQ [AHRQ-SE]: "Creating a special analysis file that contains only
#   observations for the subgroup of interest may yield incorrect standard
#   errors... preserve the entire survey design structure for the program by
#   reading in the entire person-level file." See R/REFERENCES.md.
#
# Two design objects are saved:
#   design_full — all respondents in the input data
#   design_dlr  — DLR cohort: had dental insurance at any point in the survey year
#
# Variance method (set in run_all.R):
#   "Taylor" (default) — Taylor-series linearization via svydesign(). Uses only
#                        VARSTR/VARPSU/PERWT from the FYC file itself.
#   "BRR"              — Balanced repeated replication via svrepdesign(). Uses
#                        the HC-036BRR replicate-weights file (merged on
#                        DUPERSID in 01_download_data.R). Both methods are
#                        recommended by AHRQ [AHRQ-SE]; BRR is considered the
#                        most defensible but requires the extra file.
#
# The same pipeline works for both the national public-use file and a
# state-specific restricted-use file — just swap the .dta in data/.
#
# Input:  data/fyc_<year>.rds  (from 01_download_data.R)
#         data/brr_<year>.rds  (only when variance_method = "BRR")
# Output: data/design_full_<year>.rds
#         data/design_dlr_<year>.rds
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

# =============================================================================
# 1. Load person-level data
# =============================================================================

message("Loading ", fyc_rds, "...")
fyc <- readRDS(fyc_rds)
message("  Rows: ", nrow(fyc))

# =============================================================================
# 2. Recode categorical covariates as factors
# =============================================================================
# These MEPS variables are integer-coded categories with no ordinal meaning.
# Treating them as numeric in svyglm would impose a spurious linear slope
# across arbitrarily-ordered codes (e.g., race codes 1–6 are not a scale).
# Converting here ensures the correct type travels with the design object.
# This anti-pattern is called out in CLAUDE.md under "Survey design rules".
#
#   SEX       1=Male, 2=Female
#   RACEV2X   1=White, 2=Black, 3=AIAN, 4=Asian/NHPI, 6=Multiple races
#   var_povcat 1=Poor, 2=Near poor, 3=Low income, 4=Middle income, 5=High income
#   EMPST53   1=Employed, 2=Unemployed, 3=Not in labor force

message("Recoding categorical covariates as factors...")

fyc <- fyc |>
  mutate(
    SEX            = factor(SEX,              levels = c(1, 2),
                            labels = c("Male", "Female")),
    RACEV2X        = factor(RACEV2X,          levels = c(1, 2, 3, 4, 6),
                            labels = c("White", "Black", "AIAN", "Asian/NHPI", "Multiple")),
    !!var_povcat  := factor(.data[[var_povcat]], levels = 1:5,
                            labels = c("Poor", "Near poor", "Low income",
                                       "Middle income", "High income")),
    EMPST53        = factor(EMPST53,          levels = c(1, 2, 3),
                            labels = c("Employed", "Unemployed", "Not in labor force"))
  )

message("  SEX, RACEV2X, ", var_povcat, ", EMPST53 converted to factors.")

# =============================================================================
# 3. Build the full survey design (Taylor or BRR)
# =============================================================================
# MEPS uses a stratified multistage cluster design. AHRQ [AHRQ-SE]:
#   "The MEPS public use files include variables to obtain weighted estimates
#   and to implement a Taylor-series approach to estimate standard errors...
#   These variables, which jointly reflect the MEPS survey design, include
#   the estimation weight, sampling strata, and primary sampling unit (PSU)."
#
# Taylor branch (default):
#   id      = VARPSU    — primary sampling unit
#   strata  = VARSTR    — variance stratum
#   weights = var_weight — final person-level analysis weight
#   nest    = TRUE      — PSU IDs restart within each stratum (required for MEPS)
#
# BRR branch:
#   Merges the HC-036BRR replicate weights onto the FYC by DUPERSID and builds
#   an svrepdesign() with type = "BRR". All downstream svy* calls in
#   03_analysis.R work identically on either design object.

message("Building full survey design (variance_method = ", variance_method, ")...")

weight_formula <- as.formula(paste0("~", var_weight))

if (identical(variance_method, "BRR")) {
  # ---- BRR path --------------------------------------------------------------
  if (!file.exists(brr_rds)) {
    stop("variance_method = \"BRR\" but ", brr_rds, " not found. ",
         "Run 01_download_data.R first with a valid brr_file set.")
  }
  brr <- readRDS(brr_rds)

  # Merge replicate weights onto the FYC by DUPERSID. Keep all FYC rows so the
  # full-design structure is preserved; BRR file is expected to cover the
  # entire FYC sample.
  n_before <- nrow(fyc)
  fyc <- dplyr::left_join(fyc, brr, by = "DUPERSID")
  if (nrow(fyc) != n_before) {
    stop("DUPERSID is not unique in BRR file — merge produced row duplication.")
  }

  # HC-036BRR provides 64 replicate-weight columns typically named BRR1..BRR64
  # (or similar). Grab whatever BRR* columns exist in the merged frame.
  brr_cols <- grep("^BRR[0-9]+$", names(fyc), value = TRUE)
  if (length(brr_cols) == 0) {
    stop("No BRR* replicate weight columns found after merge. ",
         "Check HC-036BRR column naming (expected BRR1, BRR2, ...).")
  }
  message("  BRR replicate weights: ", length(brr_cols), " columns found.")

  repweights_formula <- as.formula(paste0("~", paste(brr_cols, collapse = " + ")))

  design_full <- svrepdesign(
    data       = fyc,
    weights    = weight_formula,
    repweights = repweights_formula,
    type       = "BRR"
  )
} else {
  # ---- Taylor path (default) -------------------------------------------------
  design_full <- svydesign(
    id      = ~VARPSU,
    strata  = ~VARSTR,
    weights = weight_formula,
    data    = fyc,
    nest    = TRUE
  )
}

message("  Design: ",
        format(nrow(fyc), big.mark = ","), " persons | ",
        "Weighted N: ", format(round(sum(fyc[[var_weight]])), big.mark = ","))

# =============================================================================
# 4. DLR cohort: var_dntins1 == 1 | var_dntins2 == 1
# =============================================================================
# Restricts to individuals who had dental insurance at any point in the survey year.
#
# MEPS collects insurance data across multiple interview rounds within a year.
# Two dental insurance variables cover complementary windows:
#   var_dntins1 — dental insurance at any time in Round 3 / Period 1 (early year)
#   var_dntins2 — dental insurance at any time in R5/R3 through 12/31 (later year)
# Using OR captures anyone with dental coverage during any part of the year,
# consistent with how MEPS constructs its own full-year insurance summaries.
#
# WHY DENTAL-SPECIFIC VARIABLES INSTEAD OF var_prvexp > 0:
# Using var_prvexp > 0 conditions on the outcome — it excludes dentally-insured
# people who didn't visit the dentist, which is exactly the group where the DLR
# law may have had an effect. DNTINS variables define eligibility by coverage
# status, not utilization.
#
# var_prvexp remains in the data as an outcome variable — not used for selection.
#
# LIMITATION: MEPS does not distinguish self-insured (ERISA-exempt) from
# fully-insured dental plans. All estimates are intention-to-treat.

dntins_filter <- as.formula(paste0("~ ", var_dntins1, " == 1 | ", var_dntins2, " == 1"))

message("Creating DLR cohort subpopulation (", var_dntins1, " == 1 | ", var_dntins2, " == 1)...")

design_dlr <- subset(design_full, eval(parse(text = paste0(var_dntins1, " == 1 | ", var_dntins2, " == 1"))))

dlr_n        <- nrow(design_dlr$variables)
dlr_weighted <- round(sum(design_dlr$variables[[var_weight]]))
message("  DLR cohort: ",
        format(dlr_n, big.mark = ","), " persons | ",
        "Weighted N: ", format(dlr_weighted, big.mark = ","))

# =============================================================================
# 5. Save design objects
# =============================================================================

saveRDS(design_full, design_full_rds)
saveRDS(design_dlr,  design_dlr_rds)

message("\nSaved:")
message("  ", design_full_rds)
message("  ", design_dlr_rds)

message("\n02_survey_design.R complete.")
