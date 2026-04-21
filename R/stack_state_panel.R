# =============================================================================
# stack_state_panel.R
# Read every per-year state-panel CSV written by R/state_panel.R and stack
# them into one long balanced panel for Synth::dataprep().
#
# Sourced from run_all.R AFTER the per-year loop and 04_compare_years.R.
#
# Input:  output/<label>_state_panel.csv   (one per year in `years`)
# Output: output/state_panel_long.csv      (stacked long panel, one row per
#                                            state × year, with state_id added)
#
# The `label` prefix on inputs follows 03_analysis.R's out_path() convention
# and carries the _dev suffix when dev_inject_states = TRUE. To avoid crossing
# real and dev outputs, we match the dev/non-dev branch via dev_inject_states.
#
# See R/REFERENCES.md [Synth-R]: Synth::dataprep() requires a LONG-format
# balanced panel with a numeric `unit.variable` — hence the state_id column
# derived from alphabetical ordering of state names.
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

if (!exists("years")) {
  stop("Set `years` in run_all.R before sourcing this script.")
}

out_dir <- here::here("output")

# Per-year label follows the same convention as config.R's `label`; dev-mode
# outputs end in _dev_state_panel.csv and must not be mixed with real data.
panel_label <- function(y) paste0("dlr_", y, dev_suffix())

# =============================================================================
# 1. Read each year's CSV
# =============================================================================

read_state_panel <- function(y) {
  path <- file.path(out_dir, paste0(panel_label(y), "_state_panel.csv"))
  if (!file.exists(path)) {
    message("  Missing: ", path, " (skipping year ", y, ")")
    return(NULL)
  }
  read_csv(path, show_col_types = FALSE)
}

panels <- lapply(years, read_state_panel)
panels <- panels[!vapply(panels, is.null, logical(1))]

if (length(panels) == 0) {
  message("stack_state_panel.R: no per-year state panels found. ",
          "Run 01-03 + state_panel.R for at least one year first.")
  return(invisible(NULL))
}

# =============================================================================
# 2. Stack (bind_rows gracefully handles differing factor-level columns
#    across years — e.g., a rare race category absent in one year's panel).
# =============================================================================

panel_long <- bind_rows(panels)

# =============================================================================
# 3. Assign stable integer state_id by alphabetical sort of state names.
# =============================================================================
# Synth::dataprep() requires `unit.variable` numeric. We use a stable,
# deterministic mapping so that reruns with the same state set produce the
# same state_id values. Unknown states in later years inherit higher ids.

state_levels <- sort(unique(panel_long$state))
panel_long <- panel_long |>
  mutate(
    state_id = match(state, state_levels),
    year     = as.integer(year)
  ) |>
  relocate(state, state_id, year)

# =============================================================================
# 4. Panel balance check
# =============================================================================

n_years  <- length(unique(panel_long$year))
n_states <- length(state_levels)
n_rows   <- nrow(panel_long)
expected <- n_years * n_states

if (n_rows != expected) {
  warning(
    "Panel is unbalanced: ", n_rows, " rows vs ", expected,
    " expected (", n_states, " states \u00d7 ", n_years, " years). ",
    "Synth::dataprep() requires a balanced panel — missing (state, year) ",
    "cells will cause an error. Check per-year state_panel CSVs."
  )
} else {
  message("  Panel balanced: ", n_states, " states \u00d7 ", n_years, " years = ",
          n_rows, " rows.")
}

# =============================================================================
# 5. Save
# =============================================================================

long_path <- file.path(out_dir, paste0("state_panel_long", dev_suffix(), ".csv"))
write_csv(panel_long, long_path)
message("  Saved: ", long_path)
