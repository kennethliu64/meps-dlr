# =============================================================================
# synth_analysis.R
# Synthetic control driver (Abadie-Diamond-Hainmueller). Builds a synthetic
# MA from a weighted combination of non-MA donor states using pre-period
# dental outcomes + covariate means, then estimates the 2024 treatment effect
# as actual MA minus synthetic MA.
#
# Sourced from run_all.R LAST, after stack_state_panel.R.
#
# Preconditions (script self-gates and exits cleanly if any fail):
#   1. output/state_panel_long.csv exists.
#   2. `treated_state` appears in the panel.
#   3. At least 3 pre-period years are present (< post_period_start).
#   4. At least 1 post-period year is present (>= post_period_start).
#
# Output (one set per outcome in synth_outcomes):
#   output/synth_<outcome>_path.png         — observed MA vs synthetic MA
#   output/synth_<outcome>_gaps.png         — treatment-effect gap
#   output/synth_<outcome>_weights.csv      — donor weights
#   output/synth_<outcome>_balance.csv      — predictor balance table
#   output/synth_summary.html               — combined effect summary
#
# See R/REFERENCES.md [ADH-10, Synth-R] for the methodology and the
# Synth::dataprep() contract.
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

out_dir <- here::here("output")

long_path <- file.path(out_dir, paste0("state_panel_long", dev_suffix(), ".csv"))

if (!file.exists(long_path)) {
  message("synth_analysis.R: ", long_path, " not found. ",
          "Skipping SC — run stack_state_panel.R first.")
  return(invisible(NULL))
}

panel_long <- read_csv(long_path, show_col_types = FALSE)

# =============================================================================
# 1. Preconditions / gating
# =============================================================================

if (!treated_state %in% panel_long$state) {
  message("synth_analysis.R: treated_state `", treated_state,
          "` not in panel. Skipping SC.")
  return(invisible(NULL))
}

all_years  <- sort(unique(panel_long$year))
pre_years  <- all_years[all_years <  post_period_start]
post_years <- all_years[all_years >= post_period_start]

if (length(pre_years) < 3) {
  message("synth_analysis.R: only ", length(pre_years), " pre-period year(s) ",
          "(< ", post_period_start, "). Synth requires at least 3. Skipping SC.")
  return(invisible(NULL))
}
if (length(post_years) < 1) {
  message("synth_analysis.R: no post-period year (>= ", post_period_start,
          "). Skipping SC — re-run once ", post_period_start, "+ data is available.")
  return(invisible(NULL))
}

message("\nSynthetic control:")
message("  Treated:   ", treated_state)
message("  Pre-years: ", paste(pre_years,  collapse = ", "))
message("  Post-years:", paste(post_years, collapse = ", "))

# =============================================================================
# 2. Unit IDs
# =============================================================================
# Synth::dataprep() requires numeric unit.variable; state_id from
# stack_state_panel.R fulfills that. treatment.identifier is the state_id
# of the treated unit; controls.identifier is everything else.

ma_state_id    <- unique(panel_long$state_id[panel_long$state == treated_state])
donor_state_ids <- setdiff(unique(panel_long$state_id), ma_state_id)

if (length(donor_state_ids) < 2) {
  message("synth_analysis.R: only ", length(donor_state_ids),
          " donor state(s). Synth needs at least 2. Skipping SC.")
  return(invisible(NULL))
}

# =============================================================================
# 3. Map outcome stems to year-suffixed column names in the stacked panel.
# =============================================================================
# synth_outcomes is set in run_all.R as stems (e.g., "DVTOT", "DVTEXP").
# state_panel.R uses canonical names: any_visit, visits, totexp, oopexp, prvexp.
# Accept either form; map to state_panel.R's canonical _mean columns.

stem_to_col <- c(
  DVTOT  = "visits_mean",
  DVTSLF = "oopexp_mean",
  DVTPRV = "prvexp_mean",
  DVTEXP = "totexp_mean",
  # also accept canonical names directly
  visits    = "visits_mean",
  any_visit = "any_visit_mean",
  totexp    = "totexp_mean",
  oopexp    = "oopexp_mean",
  prvexp    = "prvexp_mean"
)

outcome_cols <- stem_to_col[synth_outcomes]
if (any(is.na(outcome_cols))) {
  stop("Unrecognized synth_outcomes entries: ",
       paste(synth_outcomes[is.na(outcome_cols)], collapse = ", "),
       ". Allowed stems: ", paste(names(stem_to_col), collapse = ", "), ".")
}
names(outcome_cols) <- synth_outcomes

# =============================================================================
# 4. Predictor set — covariate means shared across all SC fits.
# =============================================================================
# Take every column ending in _mean EXCEPT outcome columns and _se columns.

all_mean_cols <- grep("_mean$", names(panel_long), value = TRUE)
outcome_mean_set <- unique(stem_to_col)
predictor_cols   <- setdiff(all_mean_cols, outcome_mean_set)

if (length(predictor_cols) == 0) {
  stop("No covariate predictors found in state_panel_long.csv. ",
       "Check that state_panel.R wrote age_mean + factor-indicator _mean columns.")
}
message("  Predictors: ", length(predictor_cols), " covariate columns.")

# =============================================================================
# 5. Per-outcome Synth fit
# =============================================================================

# Coerce to plain data.frame: Synth::dataprep() does NOT accept tibbles.
panel_df <- as.data.frame(panel_long)

summary_rows <- list()

for (stem in synth_outcomes) {
  outcome_col <- outcome_cols[[stem]]
  message("\n  Fitting SC for outcome: ", stem, " (", outcome_col, ")")

  # Special predictors = pre-period outcome values, one per pre-year.
  # This is the Abadie-Diamond-Hainmueller pattern [ADH-10]: match the
  # treated trajectory, not just covariate levels.
  special_preds <- lapply(pre_years, function(yy) list(outcome_col, yy, "mean"))

  dp <- try(
    Synth::dataprep(
      foo                   = panel_df,
      predictors            = predictor_cols,
      predictors.op         = "mean",
      special.predictors    = special_preds,
      dependent             = outcome_col,
      unit.variable         = "state_id",
      unit.names.variable   = "state",
      time.variable         = "year",
      treatment.identifier  = ma_state_id,
      controls.identifier   = donor_state_ids,
      time.predictors.prior = pre_years,
      time.optimize.ssr     = pre_years,
      time.plot             = c(pre_years, post_years)
    ),
    silent = TRUE
  )
  if (inherits(dp, "try-error")) {
    message("    dataprep() failed: ", attr(dp, "condition")$message)
    next
  }

  so <- try(Synth::synth(data.prep.obj = dp), silent = TRUE)
  if (inherits(so, "try-error")) {
    message("    synth() failed: ", attr(so, "condition")$message)
    next
  }

  tab <- Synth::synth.tab(dataprep.res = dp, synth.res = so)

  # ---- Outputs ---------------------------------------------------------------
  # path.plot / gaps.plot write to the active device; wrap with png().
  png(file.path(out_dir, paste0("synth_", stem, "_path.png")),
      width = 900, height = 600, res = 120)
  Synth::path.plot(dataprep.res = dp, synth.res = so,
                   Ylab = outcome_col, Xlab = "Year",
                   Main = paste0("Synthetic ", treated_state, " \u2014 ", stem))
  dev.off()

  png(file.path(out_dir, paste0("synth_", stem, "_gaps.png")),
      width = 900, height = 600, res = 120)
  Synth::gaps.plot(dataprep.res = dp, synth.res = so,
                   Ylab = paste0(outcome_col, " gap"), Xlab = "Year",
                   Main = paste0("Gap: ", treated_state,
                                 " minus synthetic \u2014 ", stem))
  dev.off()

  # Donor weights + predictor balance (tab$tab.w is a weight-by-donor frame;
  # tab$tab.pred shows treated vs synthetic vs donor-avg predictor values).
  write_csv(
    as.data.frame(tab$tab.w),
    file.path(out_dir, paste0("synth_", stem, "_weights.csv"))
  )
  write_csv(
    as.data.frame(tab$tab.pred),
    file.path(out_dir, paste0("synth_", stem, "_balance.csv"))
  )

  # ---- Treatment effect: actual MA minus synthetic MA, per post-year -------
  y1 <- as.numeric(dp$Y1plot)            # treated observed outcome trajectory
  y0 <- as.numeric(dp$Y0plot %*% so$solution.w)  # synthetic counterfactual
  all_times <- as.numeric(rownames(dp$Y1plot))

  for (py in post_years) {
    idx <- which(all_times == py)
    if (length(idx) == 0) next
    summary_rows[[length(summary_rows) + 1]] <- tibble(
      outcome    = stem,
      year       = py,
      ma_actual  = y1[idx],
      synthetic  = y0[idx],
      effect     = y1[idx] - y0[idx]
    )
  }

  message("    ", stem, " \u2014 ",
          "MA 2024 effect (actual - synth): ",
          round(summary_rows[[length(summary_rows)]]$effect, 4))
}

# =============================================================================
# 6. Combined effect summary
# =============================================================================

if (length(summary_rows) > 0) {
  summary_tbl <- bind_rows(summary_rows)
  summary_gt <- summary_tbl |>
    gt() |>
    tab_header(
      title    = paste0("Synthetic control treatment effects \u2014 ", treated_state),
      subtitle = "Actual treated outcome minus synthetic counterfactual, by year."
    ) |>
    fmt_number(columns = c(ma_actual, synthetic, effect), decimals = 3) |>
    tab_source_note(md(paste0(
      "Donor pool: ", length(donor_state_ids), " states. ",
      "Pre-period match years: ",
      paste(pre_years, collapse = ", "), ". ",
      if (isTRUE(dev_inject_states))
        "**DEV MODE** \u2014 synthetic pseudo-states; not interpretable as real SC.",
      " See R/REFERENCES.md [ADH-10, Synth-R]."
    )))

  summary_path <- file.path(out_dir, "synth_summary.html")
  gt::gtsave(summary_gt, summary_path)
  message("  Saved: ", summary_path)
} else {
  message("  No outcomes fit successfully \u2014 no synth_summary.html written.")
}

message("\nsynth_analysis.R complete.")
