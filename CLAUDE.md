# CLAUDE.md — DLR Dental MEPS Analysis

This file is read automatically by Claude Code at the start of every session.
It captures the project context so you don't have to re-explain it each time.

## What this project does

Evaluates the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data. The DLR law requires dental insurers
to spend a minimum share of premium revenue on patient care.

Research questions:
1. Did dental care **access and frequency** change among DLR-affected MA residents?
   - Access: probability of any dental visit (`I(var_visits > 0)`, binary)
   - Frequency: unconditional annual visit count, including zero for non-visitors (`var_visits`)
2. Did **dental spending** change?
   - Total expenditures (`var_totexp`) — all-source spending per person
   - Out-of-pocket (`var_oopexp`) — patient burden
   - Private insurance payments (`var_prvexp`) — insurer payout per person; relevant to DLR but zero for insured individuals with no dental visits
3. Did the **mix of dental services** change? (`EXAMINEX`–`ORTHDONX`)

## Pipeline entry point

**Edit `run_all.R`, then `source("run_all.R")`.**

```r
# run_all.R — edit these three lines, then source the file
year     <- 2023L        # Survey year
fyc_file <- "h251.dta"  # FYC filename in data/
dv_file  <- "h248b.dta" # Dental visits filename in data/

# Optional: override dental insurance filter variable names
# (uncomment if auto-derived names don't exist in the file)
# dntins1_override <- "DNTINS31_M23"
# dntins2_override <- "DNTINS23_M23"
```

All year-specific variable names, file paths, and output labels are derived
automatically from `year` by `R/config.R`. **No other files need editing** for a
standard year change.

## Key variables

Variable names below are year-specific; `config.R` derives them automatically.
The config variable names (e.g. `var_visits`) are what the code uses.

| Config var | MEPS pattern | Description | Q | File |
|------------|-------------|-------------|---|------|
| `var_dntins1` | `DNTINS31_M{yr}` | Dental insurance, early survey year — **eligibility filter (part 1)** | — | FYC |
| `var_dntins2` | `DNTINS23_M{yr}` | Dental insurance, late survey year — **eligibility filter (part 2)** | — | FYC |
| `var_visits` | `DVTOT{yr}` | Total dental visits | Q1 | FYC |
| `var_totexp` | `DVTEXP{yr}` | Total dental expenditures (all sources) | Q2 | FYC |
| `var_oopexp` | `DVTSLF{yr}` | Out-of-pocket dental expenditures | Q2 | FYC |
| `var_prvexp` | `DVTPRV{yr}` | Annual total of private insurance payments for dental care — captures insurer payout but is zero for insured individuals who had no visits or whose insurer paid nothing; **not used as eligibility filter** | Q2 | FYC |
| `var_weight` | `PERWT{yr}F` | Person-level analysis weight | — | FYC |
| — | `EXAMINEX`–`ORTHDONX` | Procedure type flags | Q3 | Dental Visits |
| — | `VARSTR` | Variance stratum | — | FYC |
| — | `VARPSU` | Variance PSU | — | FYC |

## DLR cohort filter

```r
var_dntins1 == 1 | var_dntins2 == 1
```

Anyone with dental insurance at any point in the survey year. MEPS collects insurance
data across multiple interview rounds, so two variables cover complementary windows of
the year. Using OR captures anyone with dental coverage during any part of the year.

**Why dental-specific variables and not `var_prvexp > 0`**: Using `var_prvexp > 0`
conditions on the outcome (private insurance paid for dental care), which excludes
dentally-insured people who didn't go to the dentist — exactly the group where the DLR
law may have had an effect. `DNTINS` variables define eligibility by coverage status,
not utilization.

`var_prvexp` is a **Q2 outcome variable**: how much did private insurance pay? It captures
the insurer payout side of the DLR formula. Note that MEPS does not collect premium
data, so the loss ratio itself cannot be computed; `var_prvexp` is the closest available
proxy for insurer payout behavior. It should be analyzed alongside `var_totexp` and
`var_oopexp`, not used as a sample selection criterion.

**Limitation**: MEPS does not distinguish self-insured (ERISA-exempt) from fully-insured
dental plans. Self-insured plan holders are misclassified as DLR-affected.
All estimates are **intention-to-treat** and likely attenuated toward null.

## Survey design rules

- Set `options(survey.lonely.psu = "adjust")` before any `svydesign()` call (done in
  `00_setup.R`). MEPS has strata with a single PSU; without this option the `survey`
  package throws an error or uses an inferior variance estimator.
- Design variables: `id = ~VARPSU`, `strata = ~VARSTR`, `weights = ~<var_weight>`, `nest = TRUE`
- ALWAYS use `subset(design, condition)` to filter subpopulations — never filter the
  raw data frame before calling `svydesign()`. Filtering rows first discards strata/PSU
  combinations and breaks variance estimation. This applies even when merging auxiliary
  data (e.g., dental visits file): merge onto the full person-level frame, build the
  design from the full frame, then `subset()`.
- Categorical covariates (`SEX`, `RACEV2X`, `var_povcat`, `EMPST53`) must be R factors
  before entering `svydesign()`. This is done in `02_survey_design.R`. Never pass
  integer-coded categories to `svyglm` as numeric — it imposes a spurious ordinal slope.
- Visit-level data (dental visits file) has no visit-level weights. Collapse to person
  level (`any(flag == 1)` per person), merge onto the full FYC frame, then apply person
  weights via the design object.

## Scripts (run in order via run_all.R)

```
run_all.R               ← EDIT THIS, then source("run_all.R")
R/00_setup.R            # Install + load packages (also run once standalone)
R/config.R              # Derives all variable names from year (sourced automatically, don't run directly)
R/01_download_data.R    # Load FYC + dental visits from local .dta files → data/*.rds
R/02_survey_design.R    # Build survey design objects → data/*.rds
R/03_analysis.R         # Q1–Q3 estimates + adjusted models + Table 1 → output/
```

Individual scripts can be sourced standalone — they default to `year = 2023` if `year`
is not already set in the session.

## Switching between national and state-level data

The pipeline is data-agnostic. To analyze a different population, swap the `.dta`
files in `data/` and update the filenames in `run_all.R`. The analysis code doesn't change.

For state-level data (e.g., MA restricted-use file from AHRQ), the file will
already contain only that state's respondents — no state-code filtering is needed.

## Covariate set (defined in config.R)

| Config variable | MEPS pattern | Type | Reference level |
|----------------|-------------|------|----------------|
| `var_age` | `AGE{yr}X` | Continuous | — |
| `SEX` | `SEX` | Factor | Male |
| `RACEV2X` | `RACEV2X` | Factor | White |
| `var_povcat` | `POVCAT{yr}` | Factor | Poor |
| `EMPST53` | `EMPST53` | Factor | Employed |

Factors are coded in `02_survey_design.R` before the design object is built; the
reference levels above are the first level of each factor (R default).

Access as a formula via `formula_apriori`. Attach an outcome with
`update(formula_apriori, as.formula(paste0("outcome ~ .")))`.

## Model choices

| Config var | Model family | Rationale |
|------------|-------------|-----------|
| `I(var_visits > 0)` (any visit, Q1) | `quasibinomial()` | Binary; estimates probability of any dental contact |
| `var_visits` (visit count, Q1) | `quasipoisson()` | Count; Poisson log-link avoids negative predictions; quasi accounts for overdispersion |
| `var_totexp`, `var_oopexp`, `var_prvexp` (spending, Q2) | `gaussian()` on `log(y + 1)` | Common approximation for right-skewed spending; the +1 shift handles zeros but makes coefficients harder to interpret in dollar terms |

**Current adjusted models are baseline description only.** The `svyglm` models in
`03_analysis.R` estimate covariate-outcome associations with no treatment variable —
they describe the survey year cohort, not a DLR law effect. When 2024 data is added,
a `post` indicator and synthetic control structure replace this baseline-only form.

## Updating for 2024

When HC-252 (2024 FYC) and HC-249B (2024 Dental Visits) are released, edit
the config block at the top of `run_all.R`:

```r
year     <- 2024L
fyc_file <- "h252.dta"
dv_file  <- "h249b.dta"
```

All variable names, paths, and output labels derive from `year` automatically.
No other files need editing for a standard year update.

> **Dental insurance filter variables**: The pipeline auto-derives
> `DNTINS31_M{yr}` / `DNTINS23_M{yr}` from `year`. If these names don't exist in
> the file, `01_download_data.R` will print every `DNTINS*` variable it finds and
> tell you exactly what to set. Uncomment and edit `dntins1_override` /
> `dntins2_override` in `run_all.R` with the correct names, then re-run.

After running both years separately, stack the harmonized data and activate the
synthetic control + covariate-adjusted comparison structure.
