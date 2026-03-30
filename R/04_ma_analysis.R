# =============================================================================
# 04_ma_analysis.R
# Massachusetts-specific analysis: subset to MA residents with dental
# insurance at any point in 2023 (DNTINS31_M23 == 1 | DNTINS23_M23 == 1)
# and replicate Q1–Q3 estimates.
#
# PREREQUISITE: Requires the MEPS restricted-use file, which includes STATECD
# (state of residence). The public-use FYC file does not contain state
# identifiers. Request access at: https://meps.ahrq.gov/mepsweb/data_stats/onsite_downloading.jsp
#
# Once you have the restricted-use file:
#   1. Re-run 01_download_data.R with the restricted-use file in place
#   2. Set has_state <- TRUE and confirm state_var below
#   3. Populate the analysis sections
#
# Input:  data/design_full_2023.rds   (from 02_survey_design.R)
#         data/dv_2023.rds            (from 01_download_data.R)
# Output: (TBD)
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

# =============================================================================
# Configuration
# =============================================================================

# Flip to TRUE once the restricted-use file with STATECD is available
has_state <- FALSE

# State variable name in the restricted-use file (confirm against codebook)
state_var <- "STATECD"   # MA FIPS code = 25

# =============================================================================
# 1. Load data
# =============================================================================

message("Loading survey design and dental visits data...")
design_full <- readRDS(here("data", "design_full_2023.rds"))
dv_raw      <- readRDS(here("data", "dv_2023.rds"))

# =============================================================================
# 2. Build MA + DLR subpopulation design
# =============================================================================

if (!has_state) {
  stop(
    "has_state is FALSE — state identifier not available in current data.\n",
    "This script requires the MEPS restricted-use file with STATECD.\n",
    "Set has_state <- TRUE once that file is in place."
  )
}

message("Creating MA + DLR subpopulation (",
        state_var, " == 25 & (DNTINS31_M23 == 1 | DNTINS23_M23 == 1))...")

# Eligibility filter: MA residents with dental insurance at any point in 2023.
# OR of two round-specific flags covers the full year — see 02_survey_design.R.
design_ma_dlr <- subset(design_full,
                        design_full$variables[[state_var]] == 25 &
                          (DNTINS31_M23 == 1 | DNTINS23_M23 == 1))

ma_n        <- nrow(design_ma_dlr$variables)
ma_weighted <- round(sum(design_ma_dlr$variables$PERWT23F))
message("  MA DLR cohort: ",
        format(ma_n, big.mark = ","), " unweighted | ",
        format(ma_weighted, big.mark = ","), " weighted")

analytic_ma <- design_ma_dlr$variables

# =============================================================================
# 3. Q1 — Dental visit frequency (MA)
# =============================================================================

# TODO

# =============================================================================
# 4. Q2 — Dental spending (MA)
# =============================================================================

# TODO

# =============================================================================
# 5. Q3 — Dental service mix (MA)
# =============================================================================

# TODO

# =============================================================================
# 6. Table 1 — MA DLR cohort descriptives
# =============================================================================

# TODO

message("\n04_ma_analysis.R complete.")
