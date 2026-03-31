# DLR Dental MEPS Analysis

Evaluating the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data.

## Research Questions

1. Did dental care access and visit frequency change among DLR-affected MA residents?
2. Did total, out-of-pocket, and insurer dental spending change?
3. Did the mix of dental services utilized change?

## Design

**Treated unit**: Massachusetts dental-insured residents
**Pre-period**: 2023 and earlier (before DLR takes effect)
**Post-period**: 2024+ (DLR in effect)
**Counterfactual**: Synthetic control — a weighted combination of other states whose
pre-2024 dental outcomes and covariate profile best match MA's pre-period trajectory.

No other US state has a dental loss ratio law, so no single real state serves as a
valid comparison. The synthetic control constructs a "synthetic MA" from the donor
pool of all other states. The treatment effect is actual MA 2024 minus synthetic
MA 2024, with covariate adjustment via regression.

The DLR cohort is individuals with dental insurance at any point in the survey year.

> **Intention-to-treat**: MEPS does not distinguish self-insured (ERISA-exempt) from
> fully-insured plans. Self-insured plan holders are not subject to the MA DLR mandate,
> so effects are likely attenuated toward null.

## Data Sources

Download the **Stata format** (`.dta`) zip files from AHRQ, unzip, and place the `.dta`
files in `data/`:

Links below are for the 2023 files (the default in `run_all.R`). For other years,
find the equivalent files on the [MEPS data files page](https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp).

| File | Data | Codebook | Description |
|------|------|----------|-------------|
| HC-251 | [h251dta.zip](https://meps.ahrq.gov/data_files/pufs/h251/h251dta.zip) | [h251cb.pdf](https://meps.ahrq.gov/data_files/pufs/h251/h251cb.pdf) | FYC 2023 — Full-Year Consolidated |
| HC-248B | [h248bdta.zip](https://meps.ahrq.gov/data_files/pufs/h248b/h248bdta.zip) | [h248bcb.pdf](https://meps.ahrq.gov/data_files/pufs/h248b/h248bcb.pdf) | Dental Visits 2023 |

## Setup

Requires R >= 4.3.0. Install all dependencies once:

```r
source("R/00_setup.R")
```

## Running the Analysis

**Step 1.** Edit the config block at the top of `run_all.R`:

```r
year     <- 2023L        # Survey year
fyc_file <- "h251.dta"  # FYC filename in data/
dv_file  <- "h248b.dta" # Dental visits filename in data/
```

**Step 2.** Source the pipeline:

```r
source("run_all.R")
```

That's it. `run_all.R` sources all four scripts in order. All variable names, file paths,
and output labels are derived automatically from `year` via `R/config.R` — no other files
need editing when changing the survey year.

### Running individual scripts

Each script can also be sourced standalone (it will default to `year = 2023`):

```r
source("R/01_download_data.R")  # Load .dta files → data/*.rds
source("R/02_survey_design.R")  # Build survey design objects → data/*.rds
source("R/03_analysis.R")       # Q1–Q3 estimates, Table 1, chart → output/
```

Earlier scripts must have been run at least once before later ones, since they produce
the `.rds` files that downstream scripts read.

## Outputs

All output files are prefixed with `<label>` (e.g. `dlr_2023`) so runs for different
years never overwrite each other.

| File | Description |
|------|-------------|
| `output/<label>_table1_cohort.html` | Survey-weighted cohort characteristics |
| `output/<label>_descriptive.html` | Formatted Q1/Q2/Q3 results with % and $ formatting |
| `output/<label>_models.html` | All 5 covariate-adjusted models in one table |
| `output/<label>_service_mix.png` | Bar chart of dental procedure mix |
| `output/<label>_q1_visits.csv` | Raw Q1 estimates (programmatic use) |
| `output/<label>_q2_spending.csv` | Raw Q2 estimates (programmatic use) |
| `output/<label>_q3_service_mix.csv` | Raw Q3 estimates (programmatic use) |

## Repository Structure

```
meps-dlr/
├── run_all.R               Pipeline entry point — edit year/filenames here
├── CLAUDE.md               Project context for Claude Code
├── README.md
├── .gitignore
├── R/
│   ├── 00_setup.R          Install + load packages
│   ├── config.R            Derives all variable names from year (sourced automatically)
│   ├── 01_download_data.R  Load .dta files from data/
│   ├── 02_survey_design.R  Build survey design objects
│   └── 03_analysis.R       Q1–Q3 estimates, Table 1, service mix chart
├── data/                   Populated by script 01 — gitignored
└── output/                 Populated by script 03 — gitignored
```

## Switching Between National and State-Level Data

The pipeline is data-agnostic. To analyze a different population, swap the `.dta`
files in `data/` and update the filenames in `run_all.R`. The analysis code doesn't change.

For state-level data (e.g., MA restricted-use file from AHRQ), the file will
already contain only that state's respondents — no filtering needed.

## Roadmap

### Step 1 — Pre-period baseline (current)
Run the single-year pipeline for 2023 (and optionally earlier years). Each year
produces a `dlr_<year>_*.html` output describing the MA DLR cohort in that year.
More pre-period years strengthen the synthetic control matching step.

### Step 2 — Add 2024 post-period data
When HC-252 (2024 FYC) and HC-249B (2024 Dental Visits) are released, edit
`run_all.R`:

```r
year     <- 2024L
fyc_file <- "h252.dta"
dv_file  <- "h249b.dta"
```

Then `source("run_all.R")`. All variable names and output labels update automatically.

> **Dental insurance filter variables**: The pipeline auto-derives the `DNTINS` variable
> names from `year`. If those names don't exist in your file, `01_download_data.R` will
> print every `DNTINS*` variable it finds and tell you what to set. Uncomment and edit
> `dntins1_override` / `dntins2_override` in `run_all.R`, then re-run.

### Step 3 — Synthetic control (requires restricted-use MEPS)
MEPS public-use files do not include state identifiers. Constructing the synthetic
control donor pool (all non-MA states) requires the MEPS restricted-use file from
AHRQ, which requires a data use agreement.

Once available, a new `R/04_synthetic_control.R` script will:
1. Stack pre- and post-period national data with a `post` indicator and state ID
2. Construct the synthetic MA using the donor pool of other states
3. Compare actual MA 2024 to synthetic MA 2024 with covariate adjustment

## Limitations

- **Self-insured misclassification**: MEPS cannot distinguish self-insured (ERISA; state-exempt)
  from fully-insured plans. ITT attenuation expected.
- **No premiums data**: MEPS does not contain premium information. Annual reporting under
  211 CMR 156.07 may be a complementary source.
