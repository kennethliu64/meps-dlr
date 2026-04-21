# References

Citations backing the statistical, survey-design, and causal-inference
choices in this pipeline. In-code comments cite these by short tag
(`[AHRQ-SE]`, `[Manning-98]`, etc.); the full entry is here.

## Survey design and variance estimation

### `[AHRQ-SE]` AHRQ — Computing Standard Errors for MEPS Estimates
Machlin S, Yu W, Zodet M. Rockville, MD: Agency for Healthcare Research
and Quality; January 2005.
<https://meps.ahrq.gov/survey_comp/standard_errors.jsp>

Key recommendations used by this pipeline:

- **Design variables.** "The MEPS public use files include variables to
  obtain weighted estimates and to implement a Taylor-series approach to
  estimate standard errors for weighted survey estimates. These variables,
  which jointly reflect the MEPS survey design, include the estimation
  weight, sampling strata, and primary sampling unit (PSU)."
  → validates `id = ~VARPSU`, `strata = ~VARSTR`, `weights = ~<var_weight>`
  in `02_survey_design.R`.

- **Variance methods.** "Several methods for estimating standard errors
  for estimates from complex surveys have been developed, including the
  Taylor-series linearization method, balanced repeated replication, and
  the jack-knife method."
  → the pipeline uses Taylor by default (survey package default) and
  supports BRR via `variance_method = "BRR"` + the HC-036BRR file.

- **Singleton PSU.** SUDAAN's `missunit` option "specifies that if only
  one sample unit is encountered within a stage… the contribution of that
  unit toward the overall standard error is estimated using the
  difference in that unit's value and the overall mean value of the
  population." The R `survey` package exposes this via
  `options(survey.lonely.psu = "adjust")`.
  → see `00_setup.R`.

- **Subpopulation / subset analysis.** "Creating a special analysis file
  that contains only observations for the subgroup of interest may yield
  incorrect standard errors or an error message because all of the
  observations corresponding to a stage of the MEPS sample design may be
  deleted. Therefore, it is advisable to preserve the entire survey
  design structure for the program by reading in the entire person-level
  file."
  → validates the `subset(design_full, …)` pattern in
  `02_survey_design.R` and the merge-onto-full-frame-then-subset pattern
  for Q3 in `03_analysis.R`.

### `[AHRQ-BRR]` MEPS HC-036BRR — Replicates for Variance Estimation File
<https://meps.ahrq.gov/data_stats/download_data/pufs/h036brr/>

Supplementary file with balanced repeated replication weights for variance
estimation. Required when `variance_method = "BRR"` is set in
`run_all.R`. Merge on `DUPERSID`.

## Health-expenditure regression modeling

### `[Manning-98]` Manning WG. The logged dependent variable, heteroscedasticity, and the retransformation problem
*Journal of Health Economics* 17(3): 283–295 (1998).

Canonical reference for the retransformation bias when regressing
log-transformed expenditures back to dollar units. The pipeline presents
log(y+1) coefficients on the log scale without back-transformation and
cites this paper in the models.html footnote.

### `[Belotti-15]` Belotti F, Deb P, Manning WG, Norton EC. `twopm`: Two-part models
*Stata Journal* 15(1): 3–20 (2015).

Reference for two-part models of health expenditures: part 1 is a binary
model of any-use (logit/probit), part 2 is a GLM (Gamma with log link is
common) fit only on users. The pipeline offers this alongside the
log(y+1) Gaussian in `03_analysis.R`.

### `[Manning-Mullahy-01]` Manning WG, Mullahy J. Estimating log models: to transform or not to transform?
*Journal of Health Economics* 20(4): 461–494 (2001).

Guidance on choosing among log(y+1) OLS, log-scale GLM, and Gamma GLM.
Gamma GLM with log link is recommended when the spending distribution is
right-skewed and heteroscedastic — as is typical of dental spending.

## Synthetic control methodology

### `[ADH-10]` Abadie A, Diamond A, Hainmueller J. Synthetic control methods for comparative case studies
*Journal of the American Statistical Association* 105(490): 493–505 (2010).

Methodological foundation for the synthetic control approach. Constructs
the counterfactual treated unit as a convex combination of donor-pool
units whose pre-treatment characteristics best match the treated unit.

### `[Synth-R]` Abadie A, Diamond A, Hainmueller J. `Synth`: An R package for synthetic control methods
CRAN package, current version 1.1-9 (2025-10-19).
<https://cran.r-project.org/web/packages/Synth/>

R implementation used by `R/synth_analysis.R`. Key function:
`dataprep(foo, predictors, predictors.op, special.predictors, dependent,
unit.variable, time.variable, treatment.identifier, controls.identifier,
time.predictors.prior, time.optimize.ssr, time.plot, unit.names.variable)`.
Input must be a long-format balanced panel with numeric unit and time
identifiers.

## MEPS data methodology

### `[MEPS-MR33]` AHRQ Methodology Report #33 — Sample Designs of the MEPS Household Component
<https://meps.ahrq.gov/data_files/publications/mr33/mr33.shtml>

Describes the stratified multistage probability sample underlying the
VARSTR / VARPSU structure used throughout this pipeline.

### `[MEPS-MR26]` AHRQ Methodology Report #26 — Variance Estimation from MEPS Event Files
<https://meps.ahrq.gov/data_files/publications/mr26/mr26.shtml>

Referenced for the person-level collapse approach used on the dental
visits event file (`03_analysis.R` Q3 block): the event file has no
visit-level weights, so visit-level procedure flags are aggregated to
person level and then weighted via the person-level design.
