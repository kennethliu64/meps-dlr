# =============================================================================
# 00_setup.R
# Install and load all packages required for the DLR Dental MEPS analysis.
# Run this script once when you first clone the repo.
# Every other script calls source("R/00_setup.R") at the top.
# =============================================================================

# ---- CRAN packages ----------------------------------------------------------

required_packages <- c(
  "haven",       # read_dta() for reading MEPS Stata (.dta) files
  "tidyverse",   # Data manipulation and visualization
  "survey",      # Complex survey-weighted regression (svyglm, svydesign)
  "srvyr",       # Tidy (dplyr-style) interface to the survey package
  "gtsummary",   # Publication-ready Table 1 with survey weights
  "gt",          # Underlying table engine; needed for gt::gtsave()
  "broom",       # Tidy coefficient tables from model objects
  "labelled",    # Work with variable labels from MEPS imports
  "here",        # Reproducible, project-relative file paths
  "Synth",       # Synthetic control (Abadie-Diamond-Hainmueller)
  "digest"       # Deterministic hashing for dev-mode state injection
)

newly_installed <- required_packages[
  !required_packages %in% rownames(installed.packages())
]

if (length(newly_installed) > 0) {
  message("Installing missing packages: ", paste(newly_installed, collapse = ", "))
  install.packages(newly_installed, dependencies = TRUE)
}

# ---- Load all packages ------------------------------------------------------

invisible(lapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

# MEPS has strata with a single PSU ("lonely PSUs"). The 'adjust' method
# centers the contribution around the grand mean and is the R-survey analog
# of SUDAAN's MISSUNIT option, which AHRQ describes as estimating the
# contribution "using the difference in that unit's value and the overall
# mean value of the population." Avoids errors during variance estimation
# in subpopulations.
#   AHRQ, Computing Standard Errors for MEPS Estimates (Machlin, Yu, Zodet,
#   Jan 2005). See R/REFERENCES.md.
options(survey.lonely.psu = "adjust")

dir.create(here::here("data"),   showWarnings = FALSE)
dir.create(here::here("output"), showWarnings = FALSE)

message("Setup complete. All packages loaded. R version: ", R.version$version.string)
message("data/ and output/ directories ready.")
