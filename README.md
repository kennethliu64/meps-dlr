# DLR Dental MEPS Analysis

Evaluating the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data.

## Research Questions

1. Did dental care access and visit frequency change among DLR-affected MA residents?
2. Did total, out-of-pocket, and insurer dental spending change?
3. Did the mix of dental services utilized change?

## Design

Pre-post (and eventually difference-in-differences) using MEPS 2023 (pre) and 2024 (post,
pending data release). The DLR cohort is defined as individuals with dental insurance at
any point in 2023 (`DNTINS31_M23 == 1 | DNTINS23_M23 == 1`).

> All estimates are **intention-to-treat**: MEPS does not distinguish self-insured
> (ERISA-exempt) from fully-insured plans, so effects are likely attenuated toward null.

## Data Sources

| File | MEPS Name | Description |
|------|-----------|-------------|
| HC-251 | FYC 2023 | Full-Year Consolidated Person-Level File |
| HC-248B | DV 2023 | Dental Visits Event-Level File |

Download the **Stata format** (`.dta`) zip files from AHRQ, unzip, and place the `.dta` files in `data/`:

| File | Data | Codebook |
|------|------|----------|
| HC-251 | [h251dta.zip](https://meps.ahrq.gov/data_files/pufs/h251/h251dta.zip) | [h251cb.pdf](https://meps.ahrq.gov/data_files/pufs/h251/h251cb.pdf) |
| HC-248B | [h248bdta.zip](https://meps.ahrq.gov/data_files/pufs/h248b/h248bdta.zip) | [h248bcb.pdf](https://meps.ahrq.gov/data_files/pufs/h248b/h248bcb.pdf) |

Update filenames in `R/01_download_data.R` if yours differ.

## Setup

```r
# Install all packages (run once)
source("R/00_setup.R")
```

Requires R >= 4.3.0. Installs all CRAN dependencies (`haven`, `tidyverse`, `survey`, etc.).

## Running the Analysis

```r
source("R/00_setup.R")          # 1. Install/load packages
source("R/01_download_data.R")  # 2. Load local .dta files into data/*.rds
source("R/02_survey_design.R")  # 3. Build survey design objects
source("R/03_analysis.R")       # 4. Run Q1-Q3 estimates + Table 1 + chart
```

Each script saves `.rds` files to `data/` so later scripts can be run independently
once earlier ones have completed.

## Outputs

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
├── CLAUDE.md               Project context for Claude Code
├── README.md
├── .gitignore
├── R/
│   ├── 00_setup.R          Install + load packages
│   ├── config.R            A priori covariate set and model formulas
│   ├── 01_download_data.R  Load .dta files from data/
│   ├── 02_survey_design.R  Build survey design objects
│   └── 03_analysis.R       Q1-Q3 estimates, Table 1, service mix chart
├── data/                   Populated by script 01 — gitignored
└── output/                 Populated by script 03 — gitignored
```

## Switching Between National and State-Level Data

The pipeline is data-agnostic. To analyze a different population, swap the `.dta`
files in `data/` and re-run the scripts. The analysis code doesn't change.

For state-level data (e.g., MA restricted-use file from AHRQ), the file will
already contain only that state's respondents — no filtering needed.

## Updating for 2024

When HC-252 (2024 FYC) and HC-249B (2024 Dental Visits) are released, edit the
three lines at the top of `run_all.R`:

```r
year     <- 2024L
fyc_file <- "h252.dta"   # update to actual FYC filename
dv_file  <- "h249b.dta"  # update to actual dental visits filename
```

All variable names, file paths, and output labels derive from `year` automatically
via `R/config.R`. No other files need editing for a standard year update.

> **Note on dental insurance filter variables**: The `DNTINS` variable naming
> pattern (`DNTINS31_M{yr}` / `DNTINS23_M{yr}`) has been stable across recent
> panel years. Verify against the 2024 codebook before running.

## Limitations

- **Self-insured misclassification**: MEPS cannot distinguish self-insured (ERISA; state-exempt)
  from fully-insured plans. ITT attenuation expected.
- **No premiums data**: MEPS does not contain premium information. Annual reporting under
  211 CMR 156.07 may be a complementary source.
