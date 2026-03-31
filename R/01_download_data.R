# =============================================================================
# 01_download_data.R
# Load MEPS Full-Year Consolidated and Dental Visits files from local Stata
# (.dta) files and save as .rds for downstream scripts.
#
# Download the files from AHRQ and unzip into data/:
#   Each zip contains a single .dta file. Place them in data/ and set
#   fyc_file / dv_file in run_all.R (or the defaults in config.R apply).
#
# Output: data/fyc_<year>.rds   (person-level)
#         data/dv_<year>.rds    (dental visits, event-level)
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

dir.create(here("data"), showWarnings = FALSE)

local_fyc_path <- here("data", fyc_file)
local_dv_path  <- here("data", dv_file)

# =============================================================================
# 1. Person-Level File — Full-Year Consolidated
# =============================================================================

message("Loading ", fyc_file, " (", year, " Full-Year Consolidated)...")

if (!file.exists(local_fyc_path)) {
  stop("File not found: ", local_fyc_path,
       "\nDownload the FYC Stata file from AHRQ, unzip, and place the .dta in data/.")
}

fyc_raw <- haven::read_dta(local_fyc_path)
message("  Rows: ", nrow(fyc_raw), " | Cols: ", ncol(fyc_raw))

# Convert all variable names to uppercase for consistent access
names(fyc_raw) <- toupper(names(fyc_raw))

# Strip haven labels — Stata imports carry labelled types that cause warnings
# in gtsummary and other packages; convert to plain R vectors
fyc_raw <- haven::zap_labels(fyc_raw)

# ---- Sanity checks on key variables ----------------------------------------

required_fyc_vars <- c(
  var_dntins1,  # Dental insurance eligibility filter (part 1)
  var_dntins2,  # Dental insurance eligibility filter (part 2)
  var_prvexp,   # Private insurance dental payments (outcome)
  var_visits,   # Total dental visits (Q1 outcome)
  var_totexp,   # Total dental expenditures (Q2 outcome)
  var_oopexp,   # Out-of-pocket dental expenditures (Q2 outcome)
  var_weight,   # Person-level analysis weight
  "VARSTR",     # Variance stratum
  "VARPSU",     # Variance PSU
  "DUPERSID"    # Person identifier (links to event files)
)

missing_fyc <- setdiff(required_fyc_vars, names(fyc_raw))
if (length(missing_fyc) > 0) {
  stop("Required variables missing from FYC file: ", paste(missing_fyc, collapse = ", "))
}
message("  All required variables present.")

# ---- Save ------------------------------------------------------------------
saveRDS(fyc_raw, fyc_rds)
message("  Saved: ", fyc_rds)

# =============================================================================
# 2. Dental Visits Event-Level File
# =============================================================================

message("\nLoading ", dv_file, " (", year, " Dental Visits)...")

if (!file.exists(local_dv_path)) {
  stop("File not found: ", local_dv_path,
       "\nDownload the Dental Visits Stata file from AHRQ, unzip, and place the .dta in data/.")
}

dv_raw <- haven::read_dta(local_dv_path)
message("  Rows: ", nrow(dv_raw), " | Cols: ", ncol(dv_raw))

names(dv_raw) <- toupper(names(dv_raw))
dv_raw <- haven::zap_labels(dv_raw)

# ---- Check for procedure-type variables ------------------------------------

procedure_vars <- c(
  "DUPERSID",
  "EXAMINEX", "JUSTXRYX", "CLENTETX", "FLUORIDX", "SEALANTX",
  "FILLINGX", "ROOTCANX", "GUMSURGX", "ORALSURX", "IMPLANTX",
  "BRIDGESX", "DENTPROX", "DENTOTHX", "ORTHDONX"
)

missing_dv <- setdiff(procedure_vars, names(dv_raw))
if (length(missing_dv) > 0) {
  warning(
    "Some procedure variables not found in dental visits file: ",
    paste(missing_dv, collapse = ", "),
    "\nVerify against the codebook for this panel year."
  )
}
message("  Procedure variables found: ",
        length(intersect(procedure_vars, names(dv_raw))), " / ", length(procedure_vars))

saveRDS(dv_raw, dv_rds)
message("  Saved: ", dv_rds)

message("\n01_download_data.R complete.")
