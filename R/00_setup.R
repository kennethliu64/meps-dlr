# =============================================================================
# 00_setup.R
# Install and load all packages required for the DLR Dental MEPS analysis.
# Run this script once when you first clone the repo.
# Every other script calls source("R/00_setup.R") at the top.
# =============================================================================

# ---- CRAN packages ----------------------------------------------------------

required_packages <- c(
  "haven",       # Read SAS transport (.ssp / .xpt) files from AHRQ
  "tidyverse",   # Data manipulation and visualization
  "survey",      # Complex survey-weighted regression (svyglm, svydesign)
  "srvyr",       # Tidy (dplyr-style) interface to the survey package
  "gtsummary",   # Publication-ready Table 1 with survey weights
  "gt",          # Underlying table engine; needed for gt::gtsave()
  "broom",       # Tidy coefficient tables from model objects
  "labelled",    # Work with variable labels from MEPS imports
  "here"         # Reproducible, project-relative file paths
)

newly_installed <- required_packages[
  !required_packages %in% rownames(installed.packages())
]

if (length(newly_installed) > 0) {
  message("Installing missing packages: ", paste(newly_installed, collapse = ", "))
  install.packages(newly_installed[newly_installed != "MEPS"], dependencies = TRUE)
}

# ---- Load all packages ------------------------------------------------------

invisible(lapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

message("Setup complete. All packages loaded. R version: ", R.version$version.string)
