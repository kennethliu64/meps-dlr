# =============================================================================
# 03_analysis.R
# Weighted estimates for all three research questions.
#
# Point `design_path` at whichever design object you want to analyze —
# the analysis is identical regardless of whether the cohort is national,
# state-level, or any other subpopulation. Build the design you need in
# 02_survey_design.R, save it as an .rds, and point this script at it.
#
# Q1: Dental visit frequency
# Q2: Total and out-of-pocket dental expenditures
# Q3: Dental service mix (procedure flags from dental visits event file)
#
# Input:  data/design_dlr_<year>.rds   (from 02_survey_design.R)
#         data/design_full_<year>.rds  (from 02_survey_design.R)
#         data/dv_<year>.rds           (from 01_download_data.R)
# Output: output/<label>_table1_cohort.html   — survey-weighted cohort characteristics
#         output/<label>_descriptive.html     — formatted Q1/Q2/Q3 results (human-readable)
#         output/<label>_models.html          — all 5 adjusted models in one table
#         output/<label>_service_mix.png      — bar chart of procedure mix
#         output/<label>_q1_visits.csv        — raw Q1 estimates (programmatic use)
#         output/<label>_q2_spending.csv      — raw Q2 estimates (programmatic use)
#         output/<label>_q3_service_mix.csv   — raw Q3 estimates (programmatic use)
# =============================================================================

source(here::here("R", "00_setup.R"))
source(here::here("R", "config.R"))

dir.create(here("output"), showWarnings = FALSE)

# =============================================================================
# 1. Load data
# =============================================================================

message("Loading survey design and dental visits data...")
design_analysis <- readRDS(design_dlr_rds)
design_full     <- readRDS(design_full_rds)  # needed for Q3
dv_raw          <- readRDS(dv_rds)

analytic <- design_analysis$variables

# Pre-compute cohort size in both forms for consistent use in all outputs.
# - dlr_n          : unweighted respondent count (statistical basis / precision)
# - dlr_weighted_n : population represented by the cohort (substantive estimate)
# Standard MEPS reporting convention: show weighted N as the headline figure
# with unweighted n in parentheses so readers can assess both.
dlr_n          <- nrow(analytic)
dlr_weighted_n <- round(sum(analytic[[var_weight]]))

fmt_pop <- function(x) {
  if (x >= 1e6) paste0(format(round(x / 1e6, 1), nsmall = 1), "M")
  else if (x >= 1e3) paste0(format(round(x / 1e3, 1), nsmall = 1), "K")
  else format(round(x), big.mark = ",")
}

dlr_n_label <- paste0(
  "Weighted N\u2009=\u2009", fmt_pop(dlr_weighted_n),
  " (unweighted n\u2009=\u2009", format(dlr_n, big.mark = ","), ")"
)

message("  Cohort (", label, "): ",
        format(dlr_n, big.mark = ","), " unweighted | ",
        fmt_pop(dlr_weighted_n), " weighted")

out_path <- function(filename) here("output", paste0(label, "_", filename))

# =============================================================================
# Q1 — Dental visit frequency
# =============================================================================

message("\nQ1: Dental visit access and frequency...")

f_any_visit <- as.formula(paste0("~I(as.numeric(", var_visits, " > 0))"))
f_visits    <- as.formula(paste0("~", var_visits))

q1_any   <- svymean(f_any_visit, design = design_analysis, na.rm = TRUE)
q1_mean  <- svymean(f_visits,    design = design_analysis, na.rm = TRUE)
q1_total <- svytotal(f_visits,   design = design_analysis, na.rm = TRUE)

message("  Weighted prob any visit: ", round(coef(q1_any), 3),
        " (SE: ", round(SE(q1_any), 3), ")")
message("  Weighted mean visits:    ", round(coef(q1_mean), 3),
        " (SE: ", round(SE(q1_mean), 3), ")")

q1_ci_any   <- confint(q1_any)
q1_ci_mean  <- confint(q1_mean)
q1_ci_total <- confint(q1_total)

q1_out <- tibble(
  metric   = c("prob_any_visit", "mean_visits", "total_visits"),
  estimate = c(coef(q1_any),       coef(q1_mean),       coef(q1_total)),
  se       = c(SE(q1_any),         SE(q1_mean),         SE(q1_total)),
  ci_lower = c(q1_ci_any[, 1],     q1_ci_mean[, 1],     q1_ci_total[, 1]),
  ci_upper = c(q1_ci_any[, 2],     q1_ci_mean[, 2],     q1_ci_total[, 2])
)
write_csv(q1_out, out_path("q1_visits.csv"))
message("  Saved: ", out_path("q1_visits.csv"))

# =============================================================================
# Q2 — Total and out-of-pocket dental spending
# =============================================================================

message("\nQ2: Dental spending...")

f_spending <- as.formula(paste0("~", var_totexp, " + ", var_oopexp, " + ", var_prvexp))
q2_mean <- svymean(f_spending, design = design_analysis, na.rm = TRUE)

message("  Weighted mean total expenditure:   $", round(coef(q2_mean)[var_totexp], 2))
message("  Weighted mean OOP expenditure:     $", round(coef(q2_mean)[var_oopexp], 2))
message("  Weighted mean insurer payout:      $", round(coef(q2_mean)[var_prvexp], 2))

q2_ci <- confint(q2_mean)

q2_out <- tibble(
  outcome  = names(coef(q2_mean)),
  mean     = coef(q2_mean),
  se       = SE(q2_mean),
  ci_lower = q2_ci[, 1],
  ci_upper = q2_ci[, 2]
)
write_csv(q2_out, out_path("q2_spending.csv"))
message("  Saved: ", out_path("q2_spending.csv"))

# =============================================================================
# Q3 — Dental service mix (from event-level file)
# =============================================================================

message("\nQ3: Dental service mix...")

procedure_vars <- c(
  "EXAMINEX", "JUSTXRYX", "CLENTETX", "FLUORIDX", "SEALANTX",
  "FILLINGX", "ROOTCANX", "GUMSURGX", "ORALSURX", "IMPLANTX",
  "BRIDGESX", "DENTPROX", "DENTOTHX", "ORTHDONX"
)

existing_proc_vars <- intersect(procedure_vars, names(dv_raw))

if (length(existing_proc_vars) == 0) {
  stop("No procedure variables found in dental visits file. ",
       "Verify the file against the codebook for this panel year.")
}

# Collapse visit-level flags to person level: did this person have *any* visit
# of each type? The dental visits file has no visit-level weights; the
# AHRQ-recommended approach is to aggregate to person level and apply person
# weights via the design object. This also avoids inflating proportions for
# frequent visitors.
dv_person <- dv_raw |>
  select(DUPERSID, all_of(existing_proc_vars)) |>
  group_by(DUPERSID) |>
  summarise(
    across(all_of(existing_proc_vars),
           ~ as.integer(any(.x == 1, na.rm = TRUE)),
           .names = "{.col}"),
    .groups = "drop"
  )

# Merge onto the FULL person-level frame (from design_full), then subset.
# IMPORTANT: svydesign() must be built from the complete sample so that all
# strata/PSU combinations are present for correct variance estimation.
# Merging onto the filtered analytic frame would silently discard strata,
# breaking SEs — the same anti-pattern as filtering before svydesign().
fyc_q3 <- design_full$variables |>
  left_join(dv_person, by = "DUPERSID") |>
  mutate(across(all_of(existing_proc_vars),
                ~ replace_na(.x, 0L)))  # persons with no dental visits → 0

weight_formula <- as.formula(paste0("~", var_weight))

design_q3 <- svydesign(
  id      = ~VARPSU,
  strata  = ~VARSTR,
  weights = weight_formula,
  data    = fyc_q3,
  nest    = TRUE
)
design_q3 <- subset(design_q3,
                    eval(parse(text = paste0(var_dntins1, " == 1 | ", var_dntins2, " == 1"))))

svy_formula_q3 <- as.formula(paste("~", paste(existing_proc_vars, collapse = " + ")))
q3_means <- svymean(svy_formula_q3, design = design_q3, na.rm = TRUE)

service_props <- tibble(
  procedure  = names(coef(q3_means)),
  proportion = coef(q3_means),
  se         = SE(q3_means)
) |>
  mutate(procedure = factor(procedure, levels = existing_proc_vars)) |>
  arrange(desc(proportion))

print(service_props, n = Inf)
write_csv(service_props, out_path("q3_service_mix.csv"))
message("  Saved: ", out_path("q3_service_mix.csv"))

# ---- Bar chart of service mix -----------------------------------------------

service_labels <- c(
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

p_mix <- service_props |>
  mutate(proc_label = service_labels[as.character(procedure)]) |>
  ggplot(aes(x = reorder(proc_label, proportion), y = proportion)) +
  geom_col(fill = "#2166ac", alpha = 0.85) +
  geom_text(aes(label = scales::percent(proportion, accuracy = 0.1)),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = paste0("Dental service mix — ", label),
    subtitle = paste0("DLR cohort \u2014 ", dlr_n_label),
    x        = NULL,
    y        = "Proportion of persons with any visit of type",
    caption  = paste0("Source: MEPS dental visits + FYC ", year,
                      ". Person-level weighted prevalence.")
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(out_path("service_mix.png"), p_mix, width = 8, height = 5, dpi = 150)
message("  Saved: ", out_path("service_mix.png"))

# =============================================================================
# Covariate-adjusted models
# =============================================================================

message("\nFitting covariate-adjusted models...")

f_q1_any <- as.formula(paste0("I(", var_visits, " > 0) ~ ."))
f_q1     <- as.formula(paste0(var_visits, " ~ ."))
f_q2a    <- as.formula(paste0("log(", var_totexp, " + 1) ~ ."))
f_q2b    <- as.formula(paste0("log(", var_oopexp, " + 1) ~ ."))
f_q2c    <- as.formula(paste0("log(", var_prvexp, " + 1) ~ ."))

fit_q1_any <- svyglm(update(formula_apriori, f_q1_any),
                     design = design_analysis, family = quasibinomial())
fit_q1     <- svyglm(update(formula_apriori, f_q1),
                     design = design_analysis, family = quasipoisson())
fit_q2a    <- svyglm(update(formula_apriori, f_q2a),
                     design = design_analysis, family = gaussian())
fit_q2b    <- svyglm(update(formula_apriori, f_q2b),
                     design = design_analysis, family = gaussian())
fit_q2c    <- svyglm(update(formula_apriori, f_q2c),
                     design = design_analysis, family = gaussian())

tbl_models <- tbl_merge(
  list(
    tbl_regression(fit_q1_any, exponentiate = TRUE),
    tbl_regression(fit_q1,     exponentiate = TRUE),
    tbl_regression(fit_q2a,    exponentiate = FALSE),
    tbl_regression(fit_q2b,    exponentiate = FALSE),
    tbl_regression(fit_q2c,    exponentiate = FALSE)
  ),
  tab_spanner = c(
    "**Any visit** (OR)",
    "**Visit count** (IRR)",
    "**Total spend** (log \u03b2)",
    "**OOP spend** (log \u03b2)",
    "**Insurer payout** (log \u03b2)"
  )
) |>
  modify_caption(paste0(
    "**Covariate-adjusted models — ", label, "**<br>",
    "OR = odds ratio; IRR = incidence rate ratio; ",
    "log \u03b2 = coefficient on log(y+1) scale."
  )) |>
  bold_labels()

tbl_models |>
  as_gt() |>
  gt::gtsave(out_path("models.html"))
message("  Saved: ", out_path("models.html"))

# =============================================================================
# Formatted descriptive results (Q1 + Q2 + Q3 in one HTML)
# =============================================================================

message("\nBuilding formatted descriptive results...")

q3_ci <- confint(q3_means)

q1_gt <- tibble(
  Metric = c("Any dental visit", "Mean visits per person", "Total visits (population)"),
  Estimate = c(
    scales::percent(coef(q1_any),    accuracy = 0.1),
    sprintf("%.2f",                  coef(q1_mean)),
    scales::comma(round(            coef(q1_total)))
  ),
  `95% CI` = c(
    paste0(scales::percent(q1_ci_any[, 1],   0.1), "\u2013", scales::percent(q1_ci_any[, 2],   0.1)),
    paste0(sprintf("%.2f", q1_ci_mean[, 1]),  "\u2013", sprintf("%.2f", q1_ci_mean[, 2])),
    paste0(scales::comma(round(q1_ci_total[, 1])), "\u2013", scales::comma(round(q1_ci_total[, 2])))
  )
) |>
  gt() |>
  tab_header(title = "Q1: Dental visit access and frequency") |>
  tab_source_note(paste0(
    "Survey-weighted. DLR cohort: individuals with dental insurance at any point in the survey year. ",
    dlr_n_label, "."
  ))

q2_gt <- tibble(
  Outcome = c("Total expenditures", "Out-of-pocket", "Insurer payout"),
  `Mean (survey-weighted)` = scales::dollar(coef(q2_mean), accuracy = 1),
  `95% CI` = paste0(
    scales::dollar(q2_ci[, 1], accuracy = 1), "\u2013",
    scales::dollar(q2_ci[, 2], accuracy = 1)
  )
) |>
  gt() |>
  tab_header(title = "Q2: Dental spending (annual per-person)") |>
  tab_source_note(paste0(
    "Survey-weighted. ", var_prvexp, " is zero for insured individuals with no dental visits. ",
    dlr_n_label, "."
  ))

q3_gt <- service_props |>
  mutate(
    Procedure  = service_labels[as.character(procedure)],
    Prevalence = scales::percent(proportion, accuracy = 0.1),
    `95% CI`   = paste0(
      scales::percent(pmax(0, q3_ci[as.character(procedure), 1]), 0.1), "\u2013",
      scales::percent(q3_ci[as.character(procedure), 2], 0.1)
    )
  ) |>
  select(Procedure, Prevalence, `95% CI`) |>
  gt() |>
  tab_header(title = "Q3: Dental service mix") |>
  tab_source_note(paste0(
    "Person-level weighted prevalence: proportion of DLR cohort with any visit of each type. ",
    dlr_n_label, "."
  ))

writeLines(
  paste0(
    "<!DOCTYPE html><html><head>",
    "<style>body{font-family:sans-serif;margin:2em;max-width:900px}</style>",
    "</head><body>",
    "<h1>Descriptive Results \u2014 ", label, "</h1>",
    "<p style='color:#555;margin-top:-0.5em'>", dlr_n_label, "</p>",
    gt::as_raw_html(q1_gt), "<br>",
    gt::as_raw_html(q2_gt), "<br>",
    gt::as_raw_html(q3_gt),
    "</body></html>"
  ),
  out_path("descriptive.html")
)
message("  Saved: ", out_path("descriptive.html"))

# =============================================================================
# Descriptive Table 1
# =============================================================================

message("\nBuilding cohort descriptive table (Table 1)...")

# Table 1 shows exactly the covariates used in the regression models —
# no more, no less. Outcomes are reported separately in descriptive.html.
table_vars <- intersect(covars_apriori, names(analytic))

tbl <- design_analysis |>
  tbl_svysummary(
    include    = all_of(table_vars),
    statistic  = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    missing = "ifany"
  ) |>
  add_stat_label(
    label = list(
      all_continuous()  ~ "Mean (SD)",
      all_categorical() ~ "Weighted N (%)"
    )
  ) |>
  modify_caption(paste0("**Table 1. Cohort characteristics (survey-weighted) — ", label, "**")) |>
  modify_footnote(all_stat_cols() ~ paste0(
    "Unweighted n\u2009=\u2009", format(dlr_n, big.mark = ","), "."
  )) |>
  bold_labels()

tbl |>
  as_gt() |>
  gt::gtsave(out_path("table1_cohort.html"))

message("  Saved: ", out_path("table1_cohort.html"))

message("\n03_analysis.R complete (", label, ").")
