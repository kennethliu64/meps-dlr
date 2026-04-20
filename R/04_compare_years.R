# =============================================================================
# 04_compare_years.R
# Cross-year comparison: harmonize the per-year Q1/Q2/Q3 CSVs written by
# 03_analysis.R into a single long-format frame and render a combined
# HTML summary table with years as columns and metrics as rows.
#
# Input:  output/dlr_<year>_q1_visits.csv       (Q1: access + frequency)
#         output/dlr_<year>_q2_spending.csv     (Q2: spending)
#         output/dlr_<year>_q3_service_mix.csv  (Q3: service mix)
#         — one set per year in `years` (set in run_all.R)
#
# Output: output/compare_years.html       — combined HTML summary table
#         output/compare_years_long.csv   — stacked long-format data
# =============================================================================

source(here::here("R", "00_setup.R"))

if (!exists("years")) {
  stop("Set `years` in run_all.R before sourcing this script.")
}

out_dir <- here::here("output")

# =============================================================================
# 1. Read and harmonize the three per-year CSVs
# =============================================================================
# The three CSVs have different column schemas by design:
#   Q1: metric / estimate / se / ci_lower / ci_upper
#   Q2: outcome / mean / se / ci_lower / ci_upper
#   Q3: procedure / proportion / se        (no pre-computed CI)
# This step renames columns to a common schema and, for Q3, computes Wald
# 95% CIs from SE to match what survey::confint.svystat() produces internally.

q3_wald_ci <- function(est, se) {
  z <- stats::qnorm(0.975)
  list(
    lower = pmax(0, est - z * se),
    upper = pmin(1, est + z * se)
  )
}

read_q1 <- function(y) {
  path <- file.path(out_dir, paste0("dlr_", y, "_q1_visits.csv"))
  if (!file.exists(path)) return(NULL)
  read_csv(path, show_col_types = FALSE) |>
    transmute(
      year     = as.integer(y),
      question = "Q1. Access and frequency",
      metric,
      estimate, se, ci_lower, ci_upper
    )
}

read_q2 <- function(y) {
  path <- file.path(out_dir, paste0("dlr_", y, "_q2_spending.csv"))
  if (!file.exists(path)) return(NULL)
  read_csv(path, show_col_types = FALSE) |>
    transmute(
      year     = as.integer(y),
      question = "Q2. Spending",
      # Strip two-digit year suffix from MEPS variable names so the same
      # metric aligns across years (DVTEXP23 and DVTEXP22 both -> DVTEXP).
      metric   = sub("[0-9]{2}$", "", outcome),
      estimate = mean,
      se, ci_lower, ci_upper
    )
}

read_q3 <- function(y) {
  path <- file.path(out_dir, paste0("dlr_", y, "_q3_service_mix.csv"))
  if (!file.exists(path)) return(NULL)
  df <- read_csv(path, show_col_types = FALSE)
  ci <- q3_wald_ci(df$proportion, df$se)
  tibble(
    year     = as.integer(y),
    question = "Q3. Service mix",
    metric   = as.character(df$procedure),
    estimate = df$proportion,
    se       = df$se,
    ci_lower = ci$lower,
    ci_upper = ci$upper
  )
}

long <- bind_rows(
  map_dfr(years, read_q1),
  map_dfr(years, read_q2),
  map_dfr(years, read_q3)
)

if (nrow(long) == 0) {
  stop("No per-year CSVs found in ", out_dir,
       ". Run the per-year pipeline (01-03) for at least one year first.")
}

# =============================================================================
# 2. Metric display labels + per-metric formatters
# =============================================================================
# Each metric has a semantic display label and a formatter that turns its raw
# numeric estimate + CI into a user-facing string. Q3 labels duplicate the
# mapping from 03_analysis.R:197-212 — the cost of duplication is small and
# keeps 04_compare_years.R a standalone reader.

metric_labels <- c(
  # Q1
  prob_any_visit = "Any dental visit",
  mean_visits    = "Mean visits per person",
  total_visits   = "Total visits (population)",
  # Q2
  DVTEXP = "Total expenditures",
  DVTSLF = "Out-of-pocket",
  DVTPRV = "Insurer payout",
  # Q3
  EXAMINEX = "Examination",
  JUSTXRYX = "X-ray",
  CLENTETX = "Cleaning",
  FLUORIDX = "Fluoride",
  SEALANTX = "Sealant",
  FILLINGX = "Filling",
  ROOTCANX = "Root canal",
  GUMSURGX = "Gum surgery",
  ORALSURX = "Oral surgery/extraction",
  IMPLANTX = "Implant",
  BRIDGESX = "Bridge",
  DENTPROX = "Dental prosthesis",
  DENTOTHX = "Other dental",
  ORTHDONX = "Orthodontics"
)

fmt_pct    <- function(e, lo, hi) paste0(
  scales::percent(e,  accuracy = 0.1), " (",
  scales::percent(lo, accuracy = 0.1), "\u2013",
  scales::percent(hi, accuracy = 0.1), ")")
fmt_num    <- function(e, lo, hi) paste0(
  sprintf("%.2f", e), " (",
  sprintf("%.2f", lo), "\u2013",
  sprintf("%.2f", hi), ")")
fmt_comma  <- function(e, lo, hi) paste0(
  scales::comma(round(e)), " (",
  scales::comma(round(lo)), "\u2013",
  scales::comma(round(hi)), ")")
fmt_dollar <- function(e, lo, hi) paste0(
  scales::dollar(e,  accuracy = 1), " (",
  scales::dollar(lo, accuracy = 1), "\u2013",
  scales::dollar(hi, accuracy = 1), ")")

format_cell <- function(question, metric, est, lo, hi) {
  if (anyNA(c(est, lo, hi))) return(NA_character_)
  if (question == "Q1. Access and frequency") {
    switch(metric,
      prob_any_visit = fmt_pct(est, lo, hi),
      mean_visits    = fmt_num(est, lo, hi),
      total_visits   = fmt_comma(est, lo, hi)
    )
  } else if (question == "Q2. Spending") {
    fmt_dollar(est, lo, hi)
  } else {
    fmt_pct(est, lo, hi)
  }
}

long <- long |>
  mutate(
    metric_label = coalesce(metric_labels[metric], metric),
    display      = pmap_chr(
      list(question, metric, estimate, ci_lower, ci_upper),
      format_cell
    )
  )

# Preserve display order: metrics appear in the order they were declared in
# metric_labels (Q1 metrics first, Q2 next, Q3 in service-mix order).
# Metrics not in the mapping (shouldn't happen, but guard anyway) sort last.
metric_order <- c(names(metric_labels), setdiff(long$metric, names(metric_labels)))
long <- long |>
  mutate(metric = factor(metric, levels = metric_order)) |>
  arrange(question, metric, year)

# =============================================================================
# 3. Save long-format CSV (the building block for future synthetic control)
# =============================================================================

long_out <- long |>
  mutate(metric = as.character(metric)) |>
  select(year, question, metric, metric_label, estimate, se, ci_lower, ci_upper, display)

long_csv_path <- file.path(out_dir, "compare_years_long.csv")
write_csv(long_out, long_csv_path)
message("Saved: ", long_csv_path)

# =============================================================================
# 4. Build combined HTML table (gt)
# =============================================================================

wide <- long |>
  select(question, metric, metric_label, year, display) |>
  mutate(year = paste0("y_", year)) |>
  pivot_wider(
    id_cols     = c(question, metric, metric_label),
    names_from  = year,
    values_from = display
  ) |>
  arrange(question, metric)

year_cols <- paste0("y_", sort(as.integer(years)))
year_labels <- setNames(as.character(sort(as.integer(years))), year_cols)

tbl <- wide |>
  select(-metric) |>
  rename(Metric = metric_label) |>
  gt(groupname_col = "question", rowname_col = "Metric") |>
  cols_label(.list = as.list(year_labels)) |>
  tab_header(
    title    = "Cross-year comparison \u2014 DLR dental MEPS cohort",
    subtitle = paste0("Years: ", paste(sort(as.integer(years)), collapse = ", "),
                      ". Cells show estimate (95% CI).")
  ) |>
  tab_source_note(md(paste0(
    "Survey-weighted estimates from MEPS Full-Year Consolidated + Dental Visits files. ",
    "Q3 CIs are Wald (estimate \u00b1 1.96\u00b7SE), matching ",
    "`survey::confint.svystat()`. Q2 expenditures are dollars per person per year."
  ))) |>
  sub_missing(missing_text = "\u2014") |>
  tab_options(table.font.size = 12, data_row.padding = px(4))

html_path <- file.path(out_dir, "compare_years.html")
gt::gtsave(tbl, html_path)
message("Saved: ", html_path)

message("\n04_compare_years.R complete (", length(years), " year(s)).")
