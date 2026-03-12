# =============================================================================
# 03_descriptives_table1.R
# Produce unweighted and survey-weighted Table 1 for the analytic sample.
# Saves HTML tables to output/tables/ and prints sample sizes to console.
#
# Input:  data/analytic_sample_2023.rds  (from 02_analytic_sample.R)
#         data/survey_design_2023.rds    (from 02_analytic_sample.R)
# Output: output/tables/table1_unweighted.html
#         output/tables/table1_weighted.html
# =============================================================================

library(tidyverse)
library(survey)
library(srvyr)
library(gtsummary)
library(here)

# Ensure output directory exists
dir.create(here("output", "tables"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. Load data
# =============================================================================

message("Loading analytic sample and survey design...")

analytic   <- readRDS(here("data", "analytic_sample_2023.rds"))
svy_design <- readRDS(here("data", "survey_design_2023.rds"))

# =============================================================================
# 2. Define variables for Table 1
# =============================================================================

# Variables to display, in order
table1_vars <- c(
  # Demographics
  "age23x", "sex", "racev2x", "hispanx",
  # SES
  "povcat23", "educyr", "empst53",
  # Insurance
  "insurc23",
  # Health
  "rthlth53", "anylmi23",
  # Outcomes
  "any_dental_visit", "dvtot23", "dvtexp23", "dvtslf23"
)

# Human-readable labels for the table
var_labels <- list(
  age23x          ~ "Age (years)",
  sex             ~ "Sex",
  racev2x         ~ "Race",
  hispanx         ~ "Hispanic ethnicity",
  povcat23        ~ "Income category (% FPL)",
  educyr          ~ "Years of education",
  empst53         ~ "Employment status",
  insurc23        ~ "Insurance coverage type",
  rthlth53        ~ "Self-rated health",
  anylmi23        ~ "Any activity limitation",
  any_dental_visit ~ "Any dental visit (0/1)",
  dvtot23         ~ "Total dental visits (n)",
  dvtexp23        ~ "Total dental expenditures ($)",
  dvtslf23        ~ "Out-of-pocket dental expenditures ($)"
)

# =============================================================================
# 3. Unweighted Table 1
# =============================================================================

message("Building unweighted Table 1...")

tbl_unweighted <- analytic |>
  select(all_of(table1_vars)) |>
  tbl_summary(
    label       = var_labels,
    missing     = "ifany",
    missing_text = "(Missing)",
    statistic   = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = list(
      all_continuous()  ~ 1,
      all_categorical() ~ c(0, 1)
    )
  ) |>
  add_n() |>
  modify_header(label ~ "**Variable**") |>
  modify_caption("**Table 1. Analytic sample characteristics (unweighted), MA 2023**") |>
  bold_labels()

# =============================================================================
# 4. Weighted Table 1 using the survey design object
# =============================================================================

message("Building survey-weighted Table 1...")

# Convert survey design to srvyr format for gtsummary compatibility
svy_srvyr <- as_survey_design(svy_design)

tbl_weighted <- svy_srvyr |>
  select(all_of(table1_vars)) |>
  tbl_svysummary(
    label       = var_labels,
    missing     = "ifany",
    missing_text = "(Missing)",
    statistic   = list(
      all_continuous()  ~ "{mean} ({sd})",
      all_categorical() ~ "{n_unweighted} ({p}%)"
    ),
    digits = list(
      all_continuous()  ~ 1,
      all_categorical() ~ c(0, 1)
    )
  ) |>
  modify_header(label ~ "**Variable**") |>
  modify_caption(
    "**Table 1. Analytic sample characteristics (survey-weighted), MA 2023**"
  ) |>
  bold_labels()

# =============================================================================
# 5. Print sample sizes to console
# =============================================================================

unweighted_n <- nrow(analytic)
weighted_n   <- round(sum(analytic$perwt23f))

message("\n--- Sample Size Summary ---")
message("  Unweighted N : ", format(unweighted_n, big.mark = ","))
message("  Weighted N   : ", format(weighted_n,   big.mark = ","),
        "  (sum of perwt23f, represents MA privately-insured dental users)")

# =============================================================================
# 6. Print tables to console
# =============================================================================

message("\nUnweighted Table 1:")
print(tbl_unweighted)

message("\nWeighted Table 1:")
print(tbl_weighted)

# =============================================================================
# 7. Save tables as HTML
# =============================================================================

message("\nSaving tables to output/tables/...")

tbl_unweighted |>
  as_gt() |>
  gt::gtsave(here("output", "tables", "table1_unweighted.html"))

tbl_weighted |>
  as_gt() |>
  gt::gtsave(here("output", "tables", "table1_weighted.html"))

message("  Saved: output/tables/table1_unweighted.html")
message("  Saved: output/tables/table1_weighted.html")

message("\n03_descriptives_table1.R complete.")
