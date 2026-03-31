# CLAUDE.md — DLR Dental MEPS Analysis

This file is read automatically by Claude Code at the start of every session.
It captures the project context so you don't have to re-explain it each time.

## What this project does

Evaluates the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data. The DLR law requires dental insurers
to spend a minimum share of premium revenue on patient care.

Research questions:
1. Did dental care **access and frequency** change among DLR-affected MA residents?
   - Access: probability of any dental visit (`I(DVTOT23 > 0)`, binary)
   - Frequency: unconditional annual visit count, including zero for non-visitors (`DVTOT23`)
2. Did **dental spending** change?
   - Total expenditures (`DVTEXP23`) — all-source spending per person
   - Out-of-pocket (`DVTSLF23`) — patient burden
   - Private insurance payments (`DVTPRV23`) — insurer payout per person; relevant to DLR but zero for insured individuals with no dental visits
3. Did the **mix of dental services** change? (`EXAMINEX`–`ORTHDONX`)

## Key variables

| Variable | Description | Q | File |
|----------|-------------|---|------|
| `DNTINS31_M23` | Dental insurance, any time in Round 3/Period 1 (early 2023) — **eligibility filter (part 1)** | — | HC-251 |
| `DNTINS23_M23` | Dental insurance, any time R5/R3 through 12/31/2023 (later 2023) — **eligibility filter (part 2)** | — | HC-251 |
| `DVTOT23` | Total dental visits | Q1 | HC-251 |
| `DVTEXP23` | Total dental expenditures (all sources) | Q2 | HC-251 |
| `DVTSLF23` | Out-of-pocket dental expenditures | Q2 | HC-251 |
| `DVTPRV23` | Annual total of private insurance payments for dental care — captures insurer payout but is zero for insured individuals who had no visits or whose insurer paid nothing; **not used as eligibility filter** | Q2 | HC-251 |
| `EXAMINEX`–`ORTHDONX` | Procedure type flags | Q3 | HC-248B |
| `PERWT23F` | Person-level analysis weight | — | HC-251 |
| `VARSTR` | Variance stratum | — | HC-251 |
| `VARPSU` | Variance PSU | — | HC-251 |

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

`DVTPRV23` is a **Q2 outcome variable**: how much did private insurance pay? It captures
the insurer payout side of the DLR formula. Note that MEPS does not collect premium
data, so the loss ratio itself cannot be computed; `DVTPRV23` is the closest available
proxy for insurer payout behavior. It should be analyzed alongside `DVTEXP23` and
`DVTSLF23`, not used as a sample selection criterion.

**Limitation**: MEPS does not distinguish self-insured (ERISA-exempt) from fully-insured
dental plans. Self-insured plan holders are misclassified as DLR-affected.
All estimates are **intention-to-treat** and likely attenuated toward null.

## Survey design rules

- Set `options(survey.lonely.psu = "adjust")` before any `svydesign()` call (done in
  `00_setup.R`). MEPS has strata with a single PSU; without this option the `survey`
  package throws an error or uses an inferior variance estimator.
- Design variables: `id = ~VARPSU`, `strata = ~VARSTR`, `weights = ~PERWT23F`, `nest = TRUE`
- ALWAYS use `subset(design, condition)` to filter subpopulations — never filter the
  raw data frame before calling `svydesign()`. Filtering rows first discards strata/PSU
  combinations and breaks variance estimation. This applies even when merging auxiliary
  data (e.g., HC-248B): merge onto the full person-level frame, build the design from
  the full frame, then `subset()`.
- Categorical covariates (`SEX`, `RACEV2X`, `POVCAT23`, `EMPST53`) must be R factors
  before entering `svydesign()`. This is done in `02_survey_design.R`. Never pass
  integer-coded categories to `svyglm` as numeric — it imposes a spurious ordinal slope.
- Visit-level data (HC-248B) has no visit-level weights. Collapse to person level
  (`any(flag == 1)` per person), merge onto the full HC-251 frame, then apply person
  weights via the design object.

## Scripts (run in order)

```
R/00_setup.R            # Install + load packages (run once)
R/config.R              # A priori covariate set and model formulas (sourced by analysis scripts)
R/01_download_data.R    # Load HC-251 + HC-248B from local .dta files → data/*.rds
R/02_survey_design.R    # Build survey design objects → data/*.rds
R/03_analysis.R         # Q1–Q3 estimates + adjusted models + Table 1 → output/
```

## Data setup

Download **Stata format** (.dta) files from AHRQ and place them in `data/`:
- `h251.dta` — HC-251 Full-Year Consolidated 2023
- `h248b.dta` — HC-248B Dental Visits 2023

Update filenames in `01_download_data.R` if yours differ.

## Switching between national and state-level data

The pipeline is data-agnostic. To analyze a different population, swap the `.dta`
files in `data/` and re-run the scripts. The analysis code doesn't change.

For state-level data (e.g., MA restricted-use file from AHRQ), the file will
already contain only that state's respondents — no state-code filtering is needed.

## Covariate set (defined in config.R)

| Variable | Type | Reference level |
|----------|------|----------------|
| `AGE23X` | Continuous | — |
| `SEX` | Factor | Male |
| `RACEV2X` | Factor | White |
| `POVCAT23` | Factor | Poor |
| `EMPST53` | Factor | Employed |

Factors are coded in `02_survey_design.R` before the design object is built; the
reference levels above are the first level of each factor (R default).

Access as a formula via `formula_apriori`. Attach an outcome with `update(formula_apriori, outcome ~ .)`.

## Model choices

| Outcome | Model family | Rationale |
|---------|-------------|-----------|
| `I(DVTOT23 > 0)` (any visit, Q1) | `quasibinomial()` | Binary; estimates probability of any dental contact |
| `DVTOT23` (visit count, Q1) | `quasipoisson()` | Count; Poisson log-link avoids negative predictions; quasi accounts for overdispersion |
| `DVTEXP23`, `DVTSLF23`, `DVTPRV23` (spending, Q2) | `gaussian()` on `log(y + 1)` | Common approximation for right-skewed spending; the +1 shift handles zeros but makes coefficients harder to interpret in dollar terms |

**Current adjusted models are baseline description only.** The `svyglm` models in
`03_analysis.R` estimate covariate-outcome associations with no treatment variable —
they describe the 2023 cohort, not a DLR law effect. When 2024 data is added, a
difference-in-differences treatment indicator replaces this structure.

## Updating for 2024

When HC-252 (2024 FYC) and HC-249B (2024 Dental Visits) are released:
1. Update local file paths in `01_download_data.R` to the new .dta filenames
2. Update weight variable: `PERWT23F` → `PERWT24F` in `02_survey_design.R`
3. Update dental insurance filter variables: `DNTINS31_M23`/`DNTINS23_M23` → 2024 equivalents in `02_survey_design.R` and `03_analysis.R` (verify names against HC-252 codebook)
4. Update all outcome variable suffixes `23` → `24` throughout `03_analysis.R`
5. Stack 2023 + 2024 data and activate the DiD model structure
