# =============================================================================
# 01_download_data.R
# Load MEPS HC-251 (Full-Year Consolidated, 2023) and HC-248B (Dental Visits,
# 2023). Supports two data sources — configure below:
#
#   data_source = "api"   — download directly from AHRQ via the MEPS R package
#                           (public-use files; no local files needed)
#   data_source = "local" — read from local .ssp files you have obtained
#                           separately (e.g. restricted-use files from AHRQ)
#                           Place files in data/ and set paths in the config.
#
# Either way, output is identical: cached .rds files in data/.
#
# To update for 2024: change year = 2023 → year = 2024 in the API section,
# or update the local file paths. Also update PERWT23F → PERWT24F in
# 02_survey_design.R.
#
# Output: data/fyc_2023.rds   (HC-251: person-level)
#         data/dv_2023.rds    (HC-248B: dental visits, event-level)
# =============================================================================

source(here::here("R", "00_setup.R"))

dir.create(here("data"), showWarnings = FALSE)

# =============================================================================
# Configuration
# =============================================================================

# Switch between "api" (MEPS R package) and "local" (.ssp files you provide)
data_source <- "api"

# Local file paths — only used when data_source = "local"
# Place the .ssp files in data/ and update filenames as needed.
# .ssp is SAS Transport (XPT) format; haven::read_xpt() handles it.
local_fyc_path <- here("data", "h251.ssp")   # HC-251: Full-Year Consolidated
local_dv_path  <- here("data", "h248b.ssp")  # HC-248B: Dental Visits

# =============================================================================
# Helper: load a single MEPS file from the configured source
# =============================================================================

load_meps_file <- function(source, year, type, local_path, label) {
  if (source == "api") {
    message("  Downloading ", label, " from AHRQ (year=", year, ", type=", type, ")...")
    MEPS::read_MEPS(year = year, type = type)
  } else if (source == "local") {
    if (!file.exists(local_path)) {
      stop("Local file not found: ", local_path,
           "\nPlace the .ssp file there or switch data_source to 'api'.")
    }
    message("  Reading ", label, " from local file: ", local_path, "...")
    haven::read_xpt(local_path)
  } else {
    stop("Unknown data_source '", source, "'. Use 'api' or 'local'.")
  }
}

# =============================================================================
# 1. Person-Level File — HC-251 (Full-Year Consolidated)
# =============================================================================

message("Loading HC-251 (2023 Full-Year Consolidated) [source: ", data_source, "]...")
fyc_raw <- load_meps_file(data_source, year = 2023, type = "FYC",
                          local_path = local_fyc_path,
                          label = "HC-251")
message("  Rows: ", nrow(fyc_raw), " | Cols: ", ncol(fyc_raw))

# Convert all variable names to uppercase for consistent access
# (MEPS package may return mixed case depending on version)
names(fyc_raw) <- toupper(names(fyc_raw))

# ---- Sanity checks on key variables ----------------------------------------

required_fyc_vars <- c(
  "DVTPRV23",   # Private insurance dental payments (DLR filter)
  "DVTOT23",    # Total dental visits (Q1 outcome)
  "DVTEXP23",   # Total dental expenditures (Q2 outcome)
  "DVTSLF23",   # Out-of-pocket dental expenditures (Q2 outcome)
  "PERWT23F",   # Person-level analysis weight
  "VARSTR",     # Variance stratum
  "VARPSU",     # Variance PSU
  "DUPERSID"    # Person identifier (links to event files)
)

missing_fyc <- setdiff(required_fyc_vars, names(fyc_raw))
if (length(missing_fyc) > 0) {
  stop("Required variables missing from HC-251: ", paste(missing_fyc, collapse = ", "))
}
message("  All required variables present in HC-251.")

# ---- Check for state variable ----------------------------------------------
# The public-use FYC file may or may not include state identifiers depending
# on the MEPS release. The restricted-use file uses STATECD.
# We check for both common names and warn gracefully if neither is found.

state_var_candidates <- c("STATECD", "STATERY23", "STATE23", "STFIPS23")
state_var <- intersect(state_var_candidates, names(fyc_raw))

if (length(state_var) == 0) {
  warning(
    "No state identifier variable found in HC-251 (checked: ",
    paste(state_var_candidates, collapse = ", "), ").\n",
    "This is expected for the public-use file. Script 02 will use the national ",
    "DLR cohort (DVTPRV23 > 0) as a placeholder.\n",
    "Once you have the restricted-use file with STATECD, set `has_state <- TRUE` ",
    "in 02_survey_design.R to activate the MA filter."
  )
  message("  State variable: NOT FOUND — national DLR cohort will be used.")
} else {
  message("  State variable found: ", state_var[1])
  # Confirm MA (FIPS 25) is represented
  ma_n <- sum(fyc_raw[[state_var[1]]] == 25, na.rm = TRUE)
  message("  Rows with state == 25 (MA): ", ma_n)
}

# ---- Save ------------------------------------------------------------------
saveRDS(fyc_raw, here("data", "fyc_2023.rds"))
message("  Saved: data/fyc_2023.rds")

# =============================================================================
# 2. Dental Visits Event-Level File — HC-248B
# =============================================================================

message("\nLoading HC-248B (2023 Dental Visits) [source: ", data_source, "]...")
dv_raw <- load_meps_file(data_source, year = 2023, type = "DV",
                         local_path = local_dv_path,
                         label = "HC-248B")
message("  Rows: ", nrow(dv_raw), " | Cols: ", ncol(dv_raw))

names(dv_raw) <- toupper(names(dv_raw))

# ---- Check for procedure-type variables ------------------------------------
# Procedure flags run from EXAMEX to ORTHDONX in the HC-248B codebook:
#   EXAMEX   — examination
#   XRAYX    — X-ray
#   CLNNGX   — cleaning / prophylaxis
#   FLRIDEX  — fluoride treatment
#   SEALNTX  — dental sealant
#   FILLNGX  — filling
#   CROWNX   — crown
#   ROOTCAX  — root canal
#   EXTRACTX — extraction
#   IMPLNTX  — implant
#   BRIDGEX  — bridge / fixed partial denture
#   DENTURX  — denture / removable partial denture
#   ORTHDONX — orthodontics

procedure_vars <- c(
  "DUPERSID",
  "EXAMEX", "XRAYX", "CLNNGX", "FLRIDEX", "SEALNTX",
  "FILLNGX", "CROWNX", "ROOTCAX", "EXTRACTX", "IMPLNTX",
  "BRIDGEX", "DENTURX", "ORTHDONX"
)

missing_dv <- setdiff(procedure_vars, names(dv_raw))
if (length(missing_dv) > 0) {
  warning(
    "Some procedure variables not found in HC-248B: ",
    paste(missing_dv, collapse = ", "),
    "\nVerify against the HC-248B codebook for this panel year."
  )
}
message("  Procedure variables found: ",
        length(intersect(procedure_vars, names(dv_raw))), " / ", length(procedure_vars))

saveRDS(dv_raw, here("data", "dv_2023.rds"))
message("  Saved: data/dv_2023.rds")

message("\n01_download_data.R complete.")
