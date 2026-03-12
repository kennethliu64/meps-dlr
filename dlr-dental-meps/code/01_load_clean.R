# =============================================================================
# 01_load_clean.R
# Load raw MEPS files, subset to Massachusetts residents, retain relevant
# variables, and save cleaned RDS objects for downstream scripts.
#
# Prerequisites:
#   - Raw MEPS files placed in data/ with exact filenames:
#       data/h251.ssp   (HC-251: 2023 Full-Year Consolidated Person-Level File)
#       data/h248b.ssp  (HC-248B: 2023 Dental Visits Event-Level File)
#   - Packages loaded via 00_packages.R
# =============================================================================

library(tidyverse)
library(haven)
library(here)
library(labelled)

# =============================================================================
# PART 1 — Person-Level File (HC-251)
# =============================================================================

message("Loading 2023 person-level file (HC-251)...")

# .ssp files are SAS Transport (XPT) format — use haven::read_xpt()
person_raw <- haven::read_xpt(here("data", "h251.ssp"))

message("  Rows loaded: ", nrow(person_raw))
message("  Converting variable names to lowercase...")

# Convert all variable names to lowercase for consistent tidyverse access
person_raw <- person_raw |>
  rename_with(tolower)

# ---- Verify state variable ---------------------------------------------------
# MEPS 2023 person-level file uses STATERY23 for state of residence (FIPS code).
# Massachusetts FIPS code = 25.
# Confirm the variable exists before filtering.
if (!"statery23" %in% names(person_raw)) {
  stop(
    "Variable 'statery23' not found. Check the HC-251 codebook for the correct ",
    "state-of-residence variable name for this panel year."
  )
}

message("  Filtering to Massachusetts residents (STATERY23 == 25)...")

ma_person <- person_raw |>
  filter(statery23 == 25)

message("  Massachusetts residents retained: ", nrow(ma_person))

# ---- Select relevant variables -----------------------------------------------
# Outcomes (dental utilization and spending):
#   dvtot23   — total number of dental visits
#   dvtexp23  — total dental expenditures ($)
#   dvtslf23  — out-of-pocket dental expenditures ($)
#   dvtprv23  — dental expenditures paid by private insurance ($)
#              (used to identify DLR-affected individuals in 02_analytic_sample.R)
#
# Demographics:
#   age23x    — age as of 12/31/2023 (final edit)
#   sex       — sex (1=Male, 2=Female)
#   racev2x   — race (MEPS Version 2 race variable; -1=Inapplicable)
#   hispanx   — Hispanic ethnicity indicator
#
# Socioeconomic status:
#   povcat23  — family income as % of poverty line category (1–5)
#   faminc23  — family income ($)
#   educyr    — years of education (person-level)
#   empst53   — employment status (round 5, closest to year-end)
#
# Insurance:
#   insurc23  — insurance coverage status, full year (1=Any private, 2=Public only,
#               3=Uninsured, etc.) — see HC-251 codebook for full detail
#
# Health status:
#   rthlth53  — perceived health status (1=Excellent … 5=Poor; round 5)
#   anylmi23  — any limitation in activities due to health condition (0/1)
#
# Survey design variables (required for svydesign()):
#   perwt23f  — final person-level analysis weight
#   varstr    — variance estimation stratum
#   varpsu    — variance estimation PSU (primary sampling unit)
#
# Person identifier:
#   dupersid  — unique person ID (links to event-level files)

vars_to_keep <- c(
  # Outcomes
  "dvtot23", "dvtexp23", "dvtslf23", "dvtprv23",
  # Demographics
  "age23x", "sex", "racev2x", "hispanx",
  # SES
  "povcat23", "faminc23", "educyr", "empst53",
  # Insurance
  "insurc23",
  # Health
  "rthlth53", "anylmi23",
  # Survey design
  "perwt23f", "varstr", "varpsu",
  # ID
  "dupersid"
)

# Check that all expected variables are present
missing_vars <- setdiff(vars_to_keep, names(ma_person))
if (length(missing_vars) > 0) {
  warning(
    "The following expected variables were NOT found in HC-251 and will be skipped:\n  ",
    paste(missing_vars, collapse = ", "),
    "\nVerify variable names against the HC-251 codebook."
  )
  vars_to_keep <- intersect(vars_to_keep, names(ma_person))
}

ma_clean <- ma_person |>
  select(all_of(vars_to_keep))

message("  Variables retained: ", ncol(ma_clean))
message("  Saving to data/ma_2023_clean.rds...")

saveRDS(ma_clean, here("data", "ma_2023_clean.rds"))
message("  Saved: data/ma_2023_clean.rds")

# =============================================================================
# PART 2 — Dental Visits Event-Level File (HC-248B)
# =============================================================================

message("\nLoading 2023 dental visits file (HC-248B)...")

dental_raw <- haven::read_xpt(here("data", "h248b.ssp"))

message("  Rows loaded: ", nrow(dental_raw))

dental_raw <- dental_raw |>
  rename_with(tolower)

# ---- Dental procedure type variables ----------------------------------------
# HC-248B contains indicators for type of dental procedure performed at each visit.
# Based on the HC-248B codebook, procedure-type indicators run from EXAMEX through
# ORTHDONX. The full list of procedure flag variables (0/1) is:
#
#   examex    — examination
#   xrayx     — X-ray
#   clnngx    — cleaning / prophylaxis
#   flridex   — fluoride treatment
#   sealntx   — dental sealant
#   fillngx   — filling (restoration)
#   crownx    — crown
#   rootcax   — root canal
#   extractx  — tooth extraction
#   implntx   — dental implant
#   bridgex   — bridge / fixed partial denture
#   denturx   — denture / removable partial denture
#   orthdonx  — orthodontic treatment
#
# NOTE: Variable names and availability may differ slightly across MEPS panel years.
# Verify against the HC-248B codebook if any are missing at runtime.

procedure_vars <- c(
  "examex", "xrayx", "clnngx", "flridex", "sealntx",
  "fillngx", "crownx", "rootcax", "extractx", "implntx",
  "bridgex", "denturx", "orthdonx"
)

# Keep person ID (to link back to person file) plus all procedure-type variables
vars_dental <- c("dupersid", procedure_vars)

missing_dental_vars <- setdiff(vars_dental, names(dental_raw))
if (length(missing_dental_vars) > 0) {
  warning(
    "The following expected dental procedure variables were NOT found in HC-248B ",
    "and will be skipped:\n  ",
    paste(missing_dental_vars, collapse = ", "),
    "\nVerify variable names against the HC-248B codebook."
  )
  vars_dental <- intersect(vars_dental, names(dental_raw))
}

dental_clean <- dental_raw |>
  select(all_of(vars_dental))

message("  Variables retained: ", ncol(dental_clean))
message("  Unique persons with dental visits: ",
        n_distinct(dental_clean$dupersid))
message("  Saving to data/dental_visits_2023_clean.rds...")

saveRDS(dental_clean, here("data", "dental_visits_2023_clean.rds"))
message("  Saved: data/dental_visits_2023_clean.rds")

message("\n01_load_clean.R complete.")
