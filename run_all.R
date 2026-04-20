# =============================================================================
# run_all.R — DLR Dental MEPS Analysis Pipeline (multi-year)
# Edit the year-keyed vectors below, then source this file.
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
    year, fyc_file, dv_file,
    label_override, dntins1_override, dntins2_override,
    envir = .GlobalEnv
  ))

  year     <- y
  fyc_file <- fyc_files[[as.character(y)]]
  dv_file  <- dv_files[[as.character(y)]]

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
}

source("R/04_compare_years.R")
