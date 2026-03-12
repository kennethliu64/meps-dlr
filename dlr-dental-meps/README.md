# DLR Dental MEPS Analysis

## Project Overview

This project evaluates the impact of Massachusetts' **Dental Loss Ratio (DLR) law**
(effective 2024) on dental care utilization among Massachusetts residents with private
dental insurance. The DLR requirement mandates that dental insurers spend a minimum
proportion of premium revenue on patient care, with the goal of reducing administrative
overhead and improving access to dental services.

### Research Questions

1. Did the MA DLR law increase dental visit frequency among privately insured residents?
2. Did it change total dental expenditures and out-of-pocket dental spending?
3. Did it shift the mix of dental services utilized (e.g., preventive vs. restorative)?

### Analytic Design

The primary analysis uses a **difference-in-differences (DiD)** design:

- **Treated group**: Massachusetts residents with private dental insurance
  (directly subject to the DLR regulation)
- **Control group**: Comparable residents in states without DLR laws
- **Pre-period**: 2023 (one year before the law took effect)
- **Post-period**: 2024 (first year under the law)

> **Current status**: 2024 MEPS data are not yet publicly available. Scripts
> `04_primary_models.R` and `05_sensitivity.R` currently run baseline descriptive
> models on 2023 data only. The DiD model structure is scaffolded and commented
> out, ready to activate when 2024 data are released.

---

## Data Sources

All data come from the **Medical Expenditure Panel Survey (MEPS)**, administered by
the Agency for Healthcare Research and Quality (AHRQ):

| File | MEPS Name | Description |
|------|-----------|-------------|
| `h251.ssp` | HC-251 | 2023 Full-Year Consolidated Person-Level File |
| `h248b.ssp` | HC-248B | 2023 Dental Visits (Event-Level) File |

Data are available at: <https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp>

> **Note**: Raw MEPS `.ssp` files are **not included** in this repository due to
> AHRQ data use terms. You must download them yourself and place them in the `data/`
> directory with the exact filenames listed above before running any scripts.

### Key Outcome Variables (from HC-251)

| Variable | Description |
|----------|-------------|
| `dvtot23` | Total number of dental visits, 2023 |
| `dvtexp23` | Total dental expenditures, 2023 ($) |
| `dvtslf23` | Out-of-pocket dental expenditures, 2023 ($) |
| `dvtprv23` | Dental expenditures paid by private insurance, 2023 ($) |

---

## Repository Structure

```
dlr-dental-meps/
├── README.md               # This file
├── .gitignore
├── code/
│   ├── 00_packages.R       # Install and load all dependencies
│   ├── 01_load_clean.R     # Ingest raw MEPS files, subset to MA, save clean RDS
│   ├── 02_analytic_sample.R# Define analytic sample, create derived variables, set up survey design
│   ├── 03_descriptives_table1.R  # Weighted and unweighted Table 1
│   ├── 04_primary_models.R # Survey-weighted regression models (+ DiD scaffold)
│   └── 05_sensitivity.R    # Sensitivity analyses: minimal covariate models
├── data/                   # NOT tracked in git — place downloaded MEPS files here
└── output/
    ├── tables/             # CSV and HTML tables produced by scripts
    └── figures/            # Plots produced by scripts
```

---

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/your-org/dlr-dental-meps.git
cd dlr-dental-meps
```

### 2. Download MEPS data

1. Go to <https://meps.ahrq.gov/mepsweb/data_stats/download_data_files.jsp>
2. Download the following files:
   - **HC-251**: 2023 Full-Year Consolidated Data File → save as `data/h251.ssp`
   - **HC-248B**: 2023 Dental Visits File → save as `data/h248b.ssp`
3. The `.ssp` files are in SAS Transport (XPT) format — no conversion needed.

### 3. Install R dependencies

Open R (version ≥ 4.3.0 recommended) from the project root and run:

```r
source("code/00_packages.R")
```

This installs all required packages if not already present.

---

## How to Run

Run the scripts in order. Each script saves intermediate `.rds` files to `data/` so
that later scripts can be run independently once earlier ones have completed.

```r
source("code/00_packages.R")           # 1. Install/load packages
source("code/01_load_clean.R")         # 2. Load raw MEPS, subset to MA
source("code/02_analytic_sample.R")    # 3. Build analytic sample + survey design
source("code/03_descriptives_table1.R")# 4. Table 1 (unweighted + weighted)
source("code/04_primary_models.R")     # 5. Primary regression models
source("code/05_sensitivity.R")        # 6. Sensitivity / robustness checks
```

All output is written to `output/tables/` and `output/figures/`.

---

## Notes and Limitations

- **MEPS does not distinguish self-insured from fully-insured dental plans.**
  Self-insured plans are governed by ERISA and are not subject to state DLR mandates.
  All estimates are therefore **intention-to-treat** and likely attenuated toward null.
- **Cross-sectional baseline only (2023).** DiD estimates require 2024 MEPS data,
  expected to be released in late 2025 or 2026.
- **Small MA sample.** The MA-specific analytic sample in MEPS is modest; confidence
  intervals will be wide. Pooling multiple pre-treatment years (2021–2023) may be
  preferable once the DiD framework is activated.
- **Survey design**: All inferential models use MEPS complex survey design weights
  (`perwt23f`), strata (`varstr`), and PSUs (`varpsu`) via the `survey` package.

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `tidyverse` | Data manipulation and visualization |
| `haven` | Read SAS Transport (`.ssp` / XPT) files |
| `survey` | Complex survey-weighted regression |
| `srvyr` | Tidy interface to `survey` |
| `gtsummary` | Publication-ready Table 1 |
| `broom` | Tidy model output |
| `labelled` | Variable labels from MEPS files |
| `here` | Reproducible file paths |

---

## Citation

If you use this code, please cite:

> [Your Name]. (2025). *DLR Dental MEPS Analysis*. GitHub.
> https://github.com/your-org/dlr-dental-meps

MEPS data citation:
> Agency for Healthcare Research and Quality. Medical Expenditure Panel Survey,
> 2023 Full-Year Consolidated File (HC-251) and Dental Visits File (HC-248B).
> Rockville, MD: AHRQ. https://meps.ahrq.gov
