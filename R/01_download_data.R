# =============================================================================
# 01_download_data.R
# Load MEPS HC-251 (Full-Year Consolidated, 2023) and HC-248B (Dental Visits,
# 2023) from local Stata (.dta) files.
#
# Download the files yourself from AHRQ:
#   HC-251:  https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp
#   HC-248B: same site, search for "Dental Visits" under 2023 event files
#
# Select "Data File, Stata format" (.dta inside a .zip). Unzip and place the
# .dta files in the data/ folder. Update filenames below if yours differ.
#
# To update for 2024: swap filenames and update variable suffixes throughout.
#
# Output: data/fyc_2023.rds   (HC-251: person-level)
#         data/dv_2023.rds    (HC-248B: dental visits, event-level)
# =============================================================================

source(here::here("R", "00_setup.R"))

dir.create(here("data"), showWarnings = FALSE)

# =============================================================================
# Configuration — update filenames here if yours differ
# =============================================================================

local_fyc_path <- here("data", "h251.dta")   # HC-251: Full-Year Consolidated
local_dv_path  <- here("data", "h248b.dta")  # HC-248B: Dental Visits

# =============================================================================
# 1. Person-Level File — HC-251 (Full-Year Consolidated)
# =============================================================================

message("Loading HC-251 (2023 Full-Year Consolidated)...")

if (!file.exists(local_fyc_path)) {
  stop("File not found: ", local_fyc_path,
       "\nDownload HC-251 (Stata format) from https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp",
       "\nunzip it, and place the .dta file in data/.")
}

fyc_raw <- haven::read_dta(local_fyc_path)
message("  Rows: ", nrow(fyc_raw), " | Cols: ", ncol(fyc_raw))

# Convert all variable names to uppercase for consistent access
names(fyc_raw) <- toupper(names(fyc_raw))

# ---- Sanity checks on key variables ----------------------------------------

required_fyc_vars <- c(
  "DNTINS31_M23", # Dental insurance Round 3/Period 1 (eligibility filter)
  "DNTINS23_M23", # Dental insurance R5/R3 through 12/31/2023 (eligibility filter)
  "DVTPRV23",     # Private insurance dental payments (outcome)
  "DVTOT23",      # Total dental visits (Q1 outcome)
  "DVTEXP23",     # Total dental expenditures (Q2 outcome)
  "DVTSLF23",     # Out-of-pocket dental expenditures (Q2 outcome)
  "PERWT23F",     # Person-level analysis weight
  "VARSTR",       # Variance stratum
  "VARPSU",       # Variance PSU
  "DUPERSID"      # Person identifier (links to event files)
)

missing_fyc <- setdiff(required_fyc_vars, names(fyc_raw))
if (length(missing_fyc) > 0) {
  stop("Required variables missing from HC-251: ", paste(missing_fyc, collapse = ", "))
}
message("  All required variables present in HC-251.")

# ---- Save ------------------------------------------------------------------
saveRDS(fyc_raw, here("data", "fyc_2023.rds"))
message("  Saved: data/fyc_2023.rds")

# =============================================================================
# 2. Dental Visits Event-Level File — HC-248B
# =============================================================================

message("\nLoading HC-248B (2023 Dental Visits)...")

if (!file.exists(local_dv_path)) {
  stop("File not found: ", local_dv_path,
       "\nDownload HC-248B (Stata format) from https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp",
       "\nunzip it, and place the .dta file in data/.")
}

dv_raw <- haven::read_dta(local_dv_path)
message("  Rows: ", nrow(dv_raw), " | Cols: ", ncol(dv_raw))

names(dv_raw) <- toupper(names(dv_raw))

# ---- Check for procedure-type variables ------------------------------------

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
