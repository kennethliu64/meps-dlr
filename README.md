# DLR Dental MEPS Analysis

Evaluating the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization using MEPS survey data.

## Research Questions

1. Did dental visit frequency change among DLR-affected MA residents?
2. Did total dental spending and out-of-pocket spending change?
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

Download **Stata format** (`.dta`) files from [AHRQ](https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp),
unzip, and place the `.dta` files in `data/`. Update filenames in `R/01_download_data.R` if yours differ.

## Setup

```r
# Install all packages (run once)
source("R/00_setup.R")
```

Requires R >= 4.3.0. Installs all CRAN dependencies (`haven`, `tidyverse`, `survey`, etc.).

## Running the Analysis

```r
source("R/00_setup.R")          # 1. Install/load packages
source("R/01_download_data.R")  # 2. Load local .ssp files into data/*.rds
source("R/02_survey_design.R")  # 3. Build survey design objects
source("R/03_analysis.R")       # 4. Run Q1-Q3 estimates + Table 1 + chart
```

Each script saves `.rds` files to `data/` so later scripts can be run independently
once earlier ones have completed.

## Outputs

| File | Description |
|------|-------------|
| `output/<label>_q1_visits.csv` | Weighted mean/total dental visits |
| `output/<label>_q2_spending.csv` | Weighted mean total + OOP dental spending |
| `output/<label>_q3_service_mix.csv` | Proportions of each procedure type |
| `output/<label>_service_mix.png` | Bar chart of service mix |
| `output/<label>_table1_cohort.html` | Descriptive table of the DLR cohort |
| `output/<label>_*_adjusted.csv` | Covariate-adjusted model results |

## Repository Structure

```
meps-dlr/
├── CLAUDE.md               Project context for Claude Code
├── README.md
├── .gitignore
├── R/
│   ├── 00_setup.R          Install + load packages
│   ├── config.R            A priori covariate set and model formulas
│   ├── 01_download_data.R  Load .ssp files from data/
│   ├── 02_survey_design.R  Build survey design objects
│   └── 03_analysis.R       Q1-Q3 estimates, Table 1, service mix chart
├── data/                   Populated by script 01 — gitignored
└── output/                 Populated by script 03 — gitignored
```

## Switching Between National and State-Level Data

The pipeline is data-agnostic. To analyze a different population, swap the `.ssp`
files in `data/` and re-run the scripts. The analysis code doesn't change.

For state-level data (e.g., MA restricted-use file from AHRQ), the file will
already contain only that state's respondents — no filtering needed.

## Updating for 2024

When HC-252 is released:
1. Update local file paths in `01_download_data.R` to the new `.ssp` filenames
2. Update weight: `PERWT23F` -> `PERWT24F` in `02_survey_design.R`
3. Stack years and activate the DiD scaffold

## Limitations

- **Self-insured misclassification**: MEPS cannot distinguish self-insured (ERISA; state-exempt)
  from fully-insured plans. ITT attenuation expected.
- **No premiums data**: MEPS does not contain premium information. Annual reporting under
  211 CMR 156.07 may be a complementary source.
