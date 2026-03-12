# =============================================================================
# 00_packages.R
# Install and load all packages required for the DLR Dental MEPS analysis.
#
# Run this script once before running any other scripts in the project.
# If a package is already installed, install.packages() is a no-op.
# =============================================================================

# ---- CRAN packages -----------------------------------------------------------

required_packages <- c(
  "tidyverse",   # Data manipulation (dplyr, tidyr, ggplot2, readr, etc.)
  "haven",       # Read SAS Transport (.ssp / XPT) files from MEPS
  "survey",      # Complex survey-weighted regression (svyglm, svydesign)
  "srvyr",       # Tidy (dplyr-style) interface to the survey package
  "gtsummary",   # Publication-ready Table 1 with survey weights
  "broom",       # Tidy coefficient tables from model objects
  "labelled",    # Work with variable labels from MEPS/HAVEN imports
  "here"         # Reproducible, project-relative file paths
)

# Install any packages that are not yet present
newly_installed <- required_packages[
  !required_packages %in% rownames(installed.packages())
]

if (length(newly_installed) > 0) {
  message("Installing missing packages: ", paste(newly_installed, collapse = ", "))
  install.packages(newly_installed, dependencies = TRUE)
} else {
  message("All required packages already installed.")
}

# ---- Load all packages -------------------------------------------------------

invisible(lapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  message("  loaded: ", pkg)
}))

message("\nPackage setup complete. R version: ", R.version$version.string)
