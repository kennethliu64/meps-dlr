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
| `DVTPRV23` | Private insurance dental payments — **the DLR filter** | HC-251 |
| `DVTOT23` | Total dental visits (Q1 outcome) | HC-251 |
| `DVTEXP23` | Total dental expenditures (Q2 outcome) | HC-251 |
| `DVTSLF23` | Out-of-pocket dental expenditures (Q2 outcome) | HC-251 |
| `PERWT23F` | Person-level analysis weight | HC-251 |
| `VARSTR` | Variance stratum | HC-251 |
| `VARPSU` | Variance PSU | HC-251 |
| `EXAMEX`–`ORTHDONX` | Procedure type flags (Q3 outcomes) | HC-248B |

## DLR cohort filter

`DVTPRV23 > 0` identifies people whose dental care was paid at least partly by private
insurance — the proxy for DLR-affected individuals.

**Important limitation**: MEPS does not distinguish self-insured (ERISA-exempt) from
fully-insured plans. Self-insured plan members are misclassified as DLR-affected.
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
R/01_download_data.R    # Download HC-251 + HC-248B via MEPS R package → data/*.rds
R/02_survey_design.R    # Build full / DLR / MA-DLR survey designs → data/*.rds
R/03_dummy_analysis.R   # Q1–Q3 estimates + Table 1 + service mix chart → output/
```

## Updating for 2024

When HC-252 (2024 FYC) is released:
1. Change `year = 2023` → `year = 2024` in `01_download_data.R`
2. Update weight variable: `PERWT23F` → `PERWT24F` in `02_survey_design.R`
3. Stack 2023 + 2024 data and activate the DiD model structure (see scaffold in a future
   `04_did_models.R` script)

## A priori minimal covariate set (per research design doc)

`AGE23X`, `SEX`, `RACEV2X`, `POVCAT23`, `INSURC23`, `RTHLTH53` + survey design variables.
