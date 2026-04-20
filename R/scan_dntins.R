# =============================================================================
# scan_dntins.R
# One-shot pre-scan helper for multi-year runs.
#
# Usage: fill in `years` and `fyc_files` at the top of run_all.R, then
#   source("R/scan_dntins.R")
# It reads every FYC file named in fyc_files, prints every DNTINS* variable
# found, and emits a copy-pasteable skeleton of dntins1_vars / dntins2_vars
# to paste into run_all.R before sourcing run_all.R for the actual loop.
#
# DNTINS variable naming varies by panel year (e.g. DNTINS31_M22, DNTINS31_M23),
# so we cannot safely guess them for unfamiliar years — inspect each file once,
# commit the right names, then the loop is deterministic.
# =============================================================================

source(here::here("R", "00_setup.R"))

if (!exists("years") || !exists("fyc_files")) {
  stop("Set `years` and `fyc_files` in run_all.R before sourcing this script.")
}

missing_keys <- setdiff(as.character(years), names(fyc_files))
if (length(missing_keys)) {
  stop("`fyc_files` is missing entries for year(s): ",
       paste(missing_keys, collapse = ", "),
       ". Add them (or remove from `years`).")
}

scan_one <- function(y, fyc_file) {
  path <- here::here("data", fyc_file)
  if (!file.exists(path)) {
    message("\n[", y, "] File not found: ", path)
    message("     Download the FYC Stata file from AHRQ, unzip, place in data/, and re-run.")
    return(invisible(NULL))
  }
  message("\n[", y, "] Reading ", fyc_file, " ...")
  fyc <- haven::read_dta(path)
  names(fyc) <- toupper(names(fyc))
  found <- sort(grep("^DNTINS", names(fyc), value = TRUE))
  yr <- as.integer(y) %% 100L
  guess1 <- paste0("DNTINS31_M", yr)
  guess2 <- paste0("DNTINS23_M", yr)
  guess1_ok <- guess1 %in% found
  guess2_ok <- guess2 %in% found
  message("     DNTINS* variables in this file (", length(found), "):")
  if (length(found) > 0) {
    for (v in found) message("       ", v)
  } else {
    message("       (none)")
  }
  message("     Auto-derived guess:  ", guess1, " ", if (guess1_ok) "\u2713" else "\u2717",
          " | ", guess2, " ", if (guess2_ok) "\u2713" else "\u2717")
  list(
    year   = y,
    found  = found,
    dntins1 = if (guess1_ok) guess1 else NA_character_,
    dntins2 = if (guess2_ok) guess2 else NA_character_
  )
}

results <- Map(scan_one, as.character(years), fyc_files[as.character(years)])

# =============================================================================
# Copy-pasteable skeleton for run_all.R
# =============================================================================

quoted <- function(x) if (is.na(x)) "NA_character_" else paste0("\"", x, "\"")
row_str <- function(r, field) {
  sprintf("  \"%s\" = %s", r$year, quoted(r[[field]]))
}

message("\n", strrep("=", 75))
message("Paste into run_all.R (edit any entry marked NA_character_ to the correct name):")
message(strrep("=", 75))
message("dntins1_vars <- c(")
message(paste(vapply(results, row_str, character(1), field = "dntins1"), collapse = ",\n"))
message(")")
message("dntins2_vars <- c(")
message(paste(vapply(results, row_str, character(1), field = "dntins2"), collapse = ",\n"))
message(")")
message(strrep("=", 75))

invisible(results)
