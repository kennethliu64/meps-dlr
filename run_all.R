# =============================================================================
# run_all.R — DLR Dental MEPS Analysis Pipeline
# Edit the three lines below, then source this file to run everything.
# =============================================================================

year     <- 2023L        # Survey year
fyc_file <- "h251.dta"  # FYC filename in data/  (HC-251 for 2023)
dv_file  <- "h248b.dta" # Dental visits filename  (HC-248B for 2023)

# =============================================================================

source("R/00_setup.R")
source("R/01_download_data.R")
source("R/02_survey_design.R")
source("R/03_analysis.R")
