# =============================================================================
# run_all.R — DLR Dental MEPS Analysis Pipeline (multi-year)
# =============================================================================
# HOW TO RUN
# -----------------------------------------------------------------------------
# 1. First time only: open R, set this project's folder as the working
#    directory, then run:   source("R/00_setup.R")
#    This installs any missing packages.
#
# 2. Put the MEPS Stata files in the data/ folder (unzipped .dta files).
#    For each year you want to analyze, you need two files from
#    https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp :
#      - Full-Year Consolidated (FYC) — person-level file, e.g. h251.dta
#      - Dental Visits           (DV) — event-level file, e.g. h248b.dta
#
# 3. Edit the config block below:
#      - `years`       : which years to analyze.
#      - `fyc_files`   : map each year to its FYC filename in data/.
#      - `dv_files`    : map each year to its Dental Visits filename in data/.
#      - `dntins1_vars` / `dntins2_vars`: dental-insurance variable names per
#        year. If you're not sure what they are, leave the entry blank and
#        source R/scan_dntins.R — it prints every DNTINS* variable in each
#        file and emits a copy-pasteable block you can drop back in here.
#    Everything else has a sensible default; edit the other sections only
#    if you need to change variance method or run synthetic control.
#
# 4. Run the whole pipeline:   source("run_all.R")
#    Outputs land in output/ :
#      - dlr_<year>_table1_cohort.html   cohort characteristics
#      - dlr_<year>_descriptive.html     Q1/Q2/Q3 results, human-readable
#      - dlr_<year>_models.html          all covariate-adjusted models
#      - dlr_<year>_service_mix.png      bar chart of procedure mix
#      - dlr_<year>_q{1,2,3}_*.csv       raw estimates for each year
#      - compare_years.html              cross-year comparison table
#      - (synthetic control outputs appear when state-level data is available)
#
# TROUBLESHOOTING
# -----------------------------------------------------------------------------
# - "File not found"  — put the .dta in data/ and check the filename matches.
# - "Dental insurance filter variables not found" — source R/scan_dntins.R,
#   it tells you exactly what to set.
# - "State column not found" — public-use MEPS doesn't have it. Either get
#   restricted-use data, or set `dev_inject_states <- TRUE` below to smoke-
#   test the synthetic-control pipeline with fake states (outputs get a
#   `_dev` suffix and are NOT valid results).
#
# For statistical rationale and citations, see R/REFERENCES.md and CLAUDE.md.
# =============================================================================

# --- Required: years to analyze ----------------------------------------------
years <- c(2022L, 2023L)

# --- Required: file paths per year (unzipped .dta files in data/) ------------
fyc_files <- c(
  "2022" = "h243.dta",     # HC-243 Full-Year Consolidated
  "2023" = "h251.dta"      # HC-251 Full-Year Consolidated
)
dv_files <- c(
  "2022" = "h239b.dta",    # HC-239B Dental Visits
  "2023" = "h248b.dta"     # HC-248B Dental Visits
)

# --- Required: dental insurance filter variables per year --------------------
# If you don't know the correct names for a given year, leave this step blank
# (or set entries to NA_character_) and source R/scan_dntins.R first — it
# prints every DNTINS* variable found in each FYC file and emits a
# copy-pasteable skeleton with any auto-derivable guesses pre-filled.
dntins1_vars <- c(
  "2022" = "DNTINS31_M22",
  "2023" = "DNTINS31_M23"
)
dntins2_vars <- c(
  "2022" = "DNTINS23_M22",
  "2023" = "DNTINS23_M23"
)

# --- Optional: variance estimation method ------------------------------------
# "Taylor" (default) uses the survey package's Taylor-series linearization
# with VARSTR/VARPSU — AHRQ's standard approach and what you get from the
# public-use MEPS files alone. "BRR" uses balanced repeated replication via
# the HC-036BRR supplementary file; this is AHRQ's most defensible method
# but requires the extra file per year. See R/REFERENCES.md [AHRQ-BRR].
variance_method <- "Taylor"

# Per-year HC-036BRR Stata filenames (only used when variance_method = "BRR").
# Leave as-is unless you've downloaded the file from AHRQ.
brr_files <- c(
  # "2022" = "h36brr22.dta",
  # "2023" = "h36brr23.dta"
)

# --- Optional: synthetic control + state handling ----------------------------
# Synthetic control requires restricted-use MEPS data with a state identifier
# (non-public — see https://meps.ahrq.gov/data_stats/onsite_datacenter.jsp ).
# See R/REFERENCES.md [Synth-R, ADH-10] for methodology.
#
# THREE MODES:
#
# A) REAL synthetic control (you have restricted-use MEPS with a state column):
#      dev_inject_states <- FALSE
#      state_col         <- "STATE"   # or whatever your file calls it
#    Pipeline runs state_panel.R + stack_state_panel.R + synth_analysis.R
#    automatically and produces real estimates. This is what you want for
#    actual results.
#
# B) DEV MODE — smoke-testing the SC code without real state data:
#      dev_inject_states <- TRUE
#    Public-use MEPS has no state column, so the pipeline assigns each person
#    to one of 20 fake states deterministically (via a hash of DUPERSID) and
#    labels one of them "MA". This lets you verify that dataprep(), synth(),
#    and all the plotting code run end-to-end on your machine BEFORE
#    restricted-use data arrives. ALL dev outputs get a "_dev" suffix on
#    their filename (e.g. dlr_2023_dev_state_panel.csv, state_panel_long_dev.csv)
#    so they can never be mistaken for real results. The numbers are
#    meaningless — this is only for checking that the plumbing works.
#
# C) SKIP synthetic control entirely (default for public-use single-year runs):
#      dev_inject_states <- FALSE
#    AND you have no state column. The pipeline will error in
#    01_download_data.R with a clear message pointing to restricted-use
#    access. If you only want Q1/Q2/Q3 descriptive results and the cross-year
#    comparison table (no SC), comment out these two lines at the bottom of
#    this file:    source("R/stack_state_panel.R")
#                  source("R/synth_analysis.R")
#    and leave dev_inject_states <- FALSE.
#
# The remaining knobs:
#   state_col          — column name in the FYC that holds the state identifier
#   treated_state      — value designated as the treated unit (MA for DLR)
#   post_period_start  — first year AFTER the policy takes effect (2024 for DLR)
#   synth_outcomes     — MEPS variable STEMS (no year suffix) to analyze via SC
state_col         <- "STATE"
treated_state     <- "MA"
post_period_start <- 2024L
synth_outcomes    <- c("DVTOT", "DVTEXP")
dev_inject_states <- FALSE

# =============================================================================
# Per-year loop
# =============================================================================
# The four script files (config.R, 01, 02, 03) were designed for a single year
# whose variables are set in the global environment. config.R uses exists()
# checks to pick up optional overrides, which means stale values persist
# across iterations unless cleared — so the first act of each iteration is to
# remove every global the downstream scripts read.

source("R/00_setup.R")

# Validate config up-front: every year must have matching entries in
# fyc_files and dv_files. Missing DNTINS entries are allowed — they fall
# through to the auto-derived names in config.R.
for (vname in c("fyc_files", "dv_files")) {
  missing_keys <- setdiff(as.character(years), names(get(vname)))
  if (length(missing_keys)) {
    stop("`", vname, "` is missing entries for year(s): ",
         paste(missing_keys, collapse = ", "),
         ". Add them (or remove from `years`).")
  }
}

lookup <- function(v, key) if (key %in% names(v)) v[[key]] else NA_character_

for (y in years) {
  suppressWarnings(rm(
    year, fyc_file, dv_file, brr_file,
    label_override, dntins1_override, dntins2_override,
    envir = .GlobalEnv
  ))

  year     <- y
  fyc_file <- fyc_files[[as.character(y)]]
  dv_file  <- dv_files[[as.character(y)]]
  brr_file <- lookup(brr_files, as.character(y))

  d1 <- lookup(dntins1_vars, as.character(y))
  d2 <- lookup(dntins2_vars, as.character(y))
  if (!is.na(d1)) dntins1_override <- d1
  if (!is.na(d2)) dntins2_override <- d2

  message("\n", strrep("=", 70))
  message("Year ", y, " | FYC: ", fyc_file, " | DV: ", dv_file)
  message(strrep("=", 70))

  source("R/01_download_data.R")
  source("R/02_survey_design.R")
  source("R/03_analysis.R")
  source("R/state_panel.R")
}

source("R/04_compare_years.R")
source("R/stack_state_panel.R")
source("R/synth_analysis.R")
