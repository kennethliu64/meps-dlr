# =============================================================================
# state_panel.R
# Aggregate the DLR cohort to state level for one survey year, producing the
# per-(state, year) row that will eventually feed Synth::dataprep().
#
# Sourced from run_all.R inside the per-year loop after 03_analysis.R.
# Relies on design_dlr_rds (built in 02_survey_design.R) and the global `year`
# and `state_col` from run_all.R / config.R.
#
# Output: one row per state with:
#   state, year, n_unweighted, n_weighted,
#   <outcome>_mean, <outcome>_se, ...,
#   <covariate indicator>_mean, ..., age_mean
#
# See R/REFERENCES.md:
#   [AHRQ-SE]  Survey-weighted estimation, Taylor vs BRR.
#   [Synth-R]  dataprep() contract — long-format panel of numeric predictors
#              by (unit, time).
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

message("\nBuilding state-level aggregation for year ", year, "...")

design_state <- readRDS(design_dlr_rds)
analytic     <- design_state$variables

# Skip with a clear message if the state column is missing (e.g., public-use
# data with dev_inject_states = FALSE). The preceding pipeline should have
# already errored in 01_download_data.R, but guard here in case this script
# is invoked standalone on an older .rds.
if (!state_col %in% names(analytic)) {
  message("  Skipping state panel: `", state_col, "` not in design_dlr. ",
          "Either run with real state data or set dev_inject_states = TRUE.")
  return(invisible(NULL))
}

# svyby() expects the grouping variable as a formula.
state_formula <- as.formula(paste0("~", state_col))

# =============================================================================
# 1. Outcome means by state (survey-weighted)
# =============================================================================
# For each outcome, build a formula and call svyby(..., svymean). The "any
# visit" indicator needs I(.) in the formula; continuous outcomes use the raw
# column name. Each call returns a frame with one row per state, columns
# <outcome> and se.<outcome>.

outcome_specs <- list(
  any_visit = as.formula(paste0("~I(as.numeric(", var_visits, " > 0))")),
  visits    = as.formula(paste0("~", var_visits)),
  totexp    = as.formula(paste0("~", var_totexp)),
  oopexp    = as.formula(paste0("~", var_oopexp)),
  prvexp    = as.formula(paste0("~", var_prvexp))
)

outcome_frames <- lapply(names(outcome_specs), function(nm) {
  f <- outcome_specs[[nm]]
  res <- svyby(f, by = state_formula, design = design_state,
               FUN = svymean, na.rm = TRUE, vartype = "se")
  # svyby names the stat columns after the formula RHS (e.g., "DVTOT23" or
  # "I(as.numeric(DVTOT23 > 0))"). Rename to the canonical stem so columns
  # are aligned across years when stack_state_panel.R rbinds. Identify the
  # (single) statistic column vs its SE counterpart.
  se_col    <- grep("^se\\.", names(res), value = TRUE)
  est_col   <- setdiff(names(res), c(state_col, se_col))
  names(res)[names(res) == est_col] <- paste0(nm, "_mean")
  names(res)[names(res) == se_col]  <- paste0(nm, "_se")
  res
})

outcomes_wide <- Reduce(
  function(a, b) merge(a, b, by = state_col, all = TRUE),
  outcome_frames
)

# =============================================================================
# 2. Covariate means by state
# =============================================================================
# Continuous covariate: age mean.
# Factor covariates: we convert each to numeric indicator columns (one per
# non-reference level) so svymean returns a state-by-indicator matrix that
# can be used as Synth predictors. Reference levels get the intercept-style
# drop — their share is implied by 1 - sum(other shares).

# --- Age (continuous) --------------------------------------------------------
age_formula <- as.formula(paste0("~", var_age))
age_by_state <- svyby(age_formula, by = state_formula, design = design_state,
                      FUN = svymean, na.rm = TRUE, vartype = "se") |>
  as.data.frame()
names(age_by_state)[names(age_by_state) == var_age] <- "age_mean"
names(age_by_state)[names(age_by_state) == paste0("se.", var_age)] <- "age_se"

# --- Factor covariates: indicator means per non-reference level --------------
# Build indicator columns on the design's data frame, then svyby each one.
# Each indicator = I(factor == level). Mean across persons is the weighted
# share at that level.
factor_covars <- c("SEX", "RACEV2X", var_povcat, "EMPST53")

# Attach indicator columns to the design's underlying data so we can reference
# them by name in the svyby formula.
for (fv in factor_covars) {
  if (!fv %in% names(analytic)) next
  lv <- levels(analytic[[fv]])
  if (is.null(lv)) next
  # Drop reference (first) level — it's the baseline.
  for (l in lv[-1]) {
    col_name <- paste0(fv, "_", gsub("[^A-Za-z0-9]+", "", l))
    design_state$variables[[col_name]] <- as.integer(analytic[[fv]] == l)
  }
}

indicator_cols <- grep(
  paste0("^(", paste(factor_covars, collapse = "|"), ")_"),
  names(design_state$variables),
  value = TRUE
)

covars_by_state <- age_by_state
if (length(indicator_cols) > 0) {
  indic_formula <- as.formula(paste0("~", paste(indicator_cols, collapse = " + ")))
  indic_by_state <- svyby(indic_formula, by = state_formula, design = design_state,
                          FUN = svymean, na.rm = TRUE, vartype = "se") |>
    as.data.frame()
  # svyby names statistic columns by the variable, SE columns as se.<var>.
  for (col in indicator_cols) {
    names(indic_by_state)[names(indic_by_state) == col] <- paste0(col, "_mean")
    se_nm <- paste0("se.", col)
    if (se_nm %in% names(indic_by_state)) {
      names(indic_by_state)[names(indic_by_state) == se_nm] <- paste0(col, "_se")
    }
  }
  covars_by_state <- merge(covars_by_state, indic_by_state, by = state_col, all = TRUE)
}

# =============================================================================
# 3. Unweighted + weighted n per state
# =============================================================================

n_by_state <- analytic |>
  group_by(.data[[state_col]]) |>
  summarise(
    n_unweighted = n(),
    n_weighted   = sum(.data[[var_weight]], na.rm = TRUE),
    .groups      = "drop"
  ) |>
  rename(!!state_col := 1)

# =============================================================================
# 4. Combine and save
# =============================================================================

state_panel <- outcomes_wide |>
  merge(covars_by_state, by = state_col, all = TRUE) |>
  merge(n_by_state,      by = state_col, all = TRUE) |>
  mutate(year = as.integer(year)) |>
  rename(state = !!state_col) |>
  relocate(state, year, n_unweighted, n_weighted)

state_panel_path <- out_path("state_panel.csv")
write_csv(state_panel, state_panel_path)
message("  Saved: ", state_panel_path,
        " (", nrow(state_panel), " states)")
