# DLR Dental MEPS Analysis

Evaluating the impact of Massachusetts' **Dental Loss Ratio (DLR) law** (effective 2024)
on dental care utilization among privately-insured Massachusetts residents.

## Research Questions

1. Did dental visit frequency change among DLR-affected MA residents?
2. Did total dental spending and out-of-pocket spending change?
3. Did the mix of dental services utilized change?

## Design

Pre-post (and eventually difference-in-differences) using MEPS 2023 (pre) and 2024 (post,
pending data release). The DLR cohort is defined as individuals with `DVTPRV23 > 0`
(private insurance paid something toward dental care).

> All estimates are **intention-to-treat**: MEPS does not distinguish self-insured
> (ERISA-exempt) from fully-insured plans, so effects are likely attenuated toward null.

## Data Sources

| File | MEPS Name | Description |
|------|-----------|-------------|
| HC-251 | FYC 2023 | Full-Year Consolidated Person-Level File |
| HC-248B | DV 2023 | Dental Visits Event-Level File |

Downloaded automatically by `R/01_download_data.R` via the
[MEPS R package](https://github.com/HHS-AHRQ/MEPS). No manual download needed.

## Setup

```r
# 1. Install all packages (run once)
source("R/00_setup.R")
```

Requires R ≥ 4.3.0. Installs the MEPS package from GitHub and all CRAN dependencies.

## Running the Analysis

```r
source("R/00_setup.R")            # 1. Install/load packages
source("R/01_download_data.R")    # 2. Download + cache MEPS data
source("R/02_survey_design.R")    # 3. Build survey design objects
source("R/03_dummy_analysis.R")   # 4. Run Q1–Q3 estimates + Table 1 + chart
```

Each script saves `.rds` files to `data/` so later scripts can be run independently
once earlier ones have completed.

## Outputs

| File | Description |
|------|-------------|
| `output/q1_visits.csv` | Weighted mean/total dental visits |
| `output/q2_spending.csv` | Weighted mean total + OOP dental spending |
| `output/q3_service_mix.csv` | Proportions of each procedure type |
| `output/service_mix.png` | Bar chart of service mix |
| `output/table1_cohort.html` | Descriptive table of the DLR cohort |

## Repository Structure

```
dlr-dental-meps/
├── CLAUDE.md               Project context for Claude Code (auto-read each session)
├── README.md
├── .gitignore
├── R/
│   ├── 00_setup.R          Install + load packages
│   ├── 01_download_data.R  Download HC-251 + HC-248B via MEPS R package
│   ├── 02_survey_design.R  Build survey design objects (full / DLR / MA-DLR)
│   └── 03_dummy_analysis.R Q1–Q3 estimates, Table 1, service mix chart
├── data/                   Populated by script 01 — gitignored
└── output/                 Populated by script 03 — gitignored
```

## Updating for 2024

When HC-252 is released (~late 2025/2026):
1. Change `year = 2023` → `year = 2024` in `01_download_data.R`
2. Update weight: `PERWT23F` → `PERWT24F` in `02_survey_design.R`
3. Stack years and activate the DiD scaffold

## Limitations

- **Self-insured misclassification**: MEPS cannot distinguish self-insured (ERISA; state-exempt)
  from fully-insured plans. ITT attenuation expected.
- **Small MA sample**: Expect ~200–400 MA respondents in the public-use file. Confidence
  intervals will be wide.
- **State variable**: The public-use FYC may not include `STATECD`. Set `has_state <- TRUE`
  in `02_survey_design.R` once you have the restricted-use file.
- **No premiums data**: MEPS does not contain premium information. Annual reporting under
  211 CMR 156.07 may be a complementary source.
