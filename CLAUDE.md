# CLAUDE.md — DLR Dental MEPS Analysis

This file is read automatically by Claude Code at the start of every session.
It captures the project context so you don't have to re-explain it each time.

## What this project does

Evaluates the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data. The DLR law requires dental insurers
to spend a minimum share of premium revenue on patient care.

Research questions:
1. Did dental visit frequency change among DLR-affected MA residents?
2. Did total and out-of-pocket dental spending change?
3. Did the mix of dental services change?

## Key variables

| Variable | Description | File |
|----------|-------------|------|
| `DNTINS31_M23` | Dental insurance, any time in Round 3/Period 1 (early 2023) — **eligibility filter (part 1)** | HC-251 |
| `DNTINS23_M23` | Dental insurance, any time R5/R3 through 12/31/2023 (later 2023) — **eligibility filter (part 2)** | HC-251 |
| `DVTPRV23` | Private insurance dental payments — **outcome variable, not filter** | HC-251 |
| `DVTOT23` | Total dental visits (Q1 outcome) | HC-251 |
| `DVTEXP23` | Total dental expenditures (Q2 outcome) | HC-251 |
| `DVTSLF23` | Out-of-pocket dental expenditures (Q2 outcome) | HC-251 |
| `PERWT23F` | Person-level analysis weight | HC-251 |
| `VARSTR` | Variance stratum | HC-251 |
| `VARPSU` | Variance PSU | HC-251 |
| `EXAMEX`–`ORTHDONX` | Procedure type flags (Q3 outcomes) | HC-248B |

## DLR cohort filter

```r
DNTINS31_M23 == 1 | DNTINS23_M23 == 1
```

Anyone with dental insurance at any point in 2023. MEPS collects insurance data
across multiple interview rounds, so two variables are needed to cover the full year:
- `DNTINS31_M23` — dental coverage in Round 3 / Period 1 (early 2023)
- `DNTINS23_M23` — dental coverage in R5/R3 through 12/31/2023 (later 2023)

**Why dental-specific variables and not DVTPRV23 > 0**: Using `DVTPRV23 > 0` conditions
on the outcome (private insurance paid for dental care), which excludes dentally-insured
people who didn't go to the dentist — exactly the group where the DLR law may have had
an effect. `DNTINS` variables define eligibility by coverage status, not utilization.

`DVTPRV23` is retained as an **outcome variable** (did private insurance pay? how much?).

**Limitation**: MEPS does not distinguish self-insured (ERISA-exempt) from fully-insured
dental plans. Self-insured plan holders are misclassified as DLR-affected.
All estimates are **intention-to-treat** and likely attenuated toward null.

## Survey design rules

- ALWAYS use `subset(design, condition)` to filter subpopulations — never filter the
  raw data frame before calling `svydesign()`. Filtering first breaks variance estimation.
- Design variables: `id = ~VARPSU`, `strata = ~VARSTR`, `weights = ~PERWT23F`, `nest = TRUE`
- Visit-level data (HC-248B) does not have its own weights; use person weights at the
  person level, not at the visit level.

## State identifier

The public-use MEPS file may not include a state variable. `02_survey_design.R` has a
`has_state <- FALSE` flag at the top. Set it to `TRUE` once you have the restricted-use
file with `STATECD`. Massachusetts FIPS code = **25**.

## Scripts (run in order)

```
R/00_setup.R            # Install + load packages (run once)
R/config.R              # A priori covariate sets and model formulas (sourced by analysis scripts)
R/01_download_data.R    # Download HC-251 + HC-248B via MEPS R package → data/*.rds
R/02_survey_design.R    # Build full / DLR survey designs → data/*.rds
R/03_dummy_analysis.R   # Q1–Q3 estimates + adjusted models + Table 1 → output/
R/04_ma_analysis.R      # MA-specific analysis (requires restricted-use file)
```

## Covariate sets (defined in config.R)

| Set | Variables | Use |
|-----|-----------|-----|
| `covars_apriori` | AGE23X, SEX, RACEV2X, POVCAT23, EMPST53 | Primary models |
| `covars_extended` | above + INSURC23, RTHLTH53 | Sensitivity / fuller models |

Access as formulas via `formula_apriori` and `formula_extended`. Attach an outcome with `update(formula_apriori, outcome ~ .)`.

## Updating for 2024

When HC-252 (2024 FYC) is released:
1. Change `year = 2023` → `year = 2024` in `01_download_data.R`
2. Update weight variable: `PERWT23F` → `PERWT24F` in `02_survey_design.R`
3. Stack 2023 + 2024 data and activate the DiD model structure (see scaffold in a future
   `04_did_models.R` script)

## A priori minimal covariate set (per research design doc)

`AGE23X`, `SEX`, `RACEV2X`, `POVCAT23`, `INSURC23`, `RTHLTH53` + survey design variables.
