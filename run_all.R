# =============================================================================
# run_all.R — DLR Dental MEPS Analysis Pipeline
# Edit the lines in the config block below, then source this file.
# =============================================================================

# --- Required: set year and filenames ----------------------------------------
year     <- 2023L        # Survey year
fyc_file <- "h251.dta"  # FYC filename in data/  (HC-251 for 2023, h243 for 2022)
dv_file  <- "h248b.dta" # Dental visits filename  (HC-248B for 2023,h239b for 2022)

# --- Optional: override dental insurance filter variables --------------------
# The pipeline auto-derives these from `year` (e.g. DNTINS31_M23).
# If the auto-derived names are missing from your FYC file, run 01_download_data.R
# once — it will print all DNTINS* variables found in the file.
# Then uncomment and set the correct names here:
#
# dntins1_override <- "DNTINS31_M23"   # dental insurance, early year
# dntins2_override <- "DNTINS23_M23"   # dental insurance, late year

# =============================================================================

source("R/00_setup.R")
source("R/01_download_data.R")
source("R/02_survey_design.R")
source("R/03_analysis.R")
