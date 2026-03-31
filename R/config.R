# =============================================================================
# config.R
# Central configuration: year-specific variable names, file paths, covariate
# set, and model formulas. Sourced by all analysis scripts.
#
# When running via run_all.R, `year` and file names are set there.
# When running a script standalone, defaults below apply.
#
# Usage in any script:
#   source(here::here("R", "config.R"))
#   svyglm(reformulate(covars_apriori, response = var_visits), design = design_dlr)
# =============================================================================

# =============================================================================
# Year — set in run_all.R; defaults to 2023 for standalone script runs
# =============================================================================

if (!exists("year"))     year     <- 2023L
if (!exists("fyc_file")) fyc_file <- "h251.dta"
if (!exists("dv_file"))  dv_file  <- "h248b.dta"

yr <- year %% 100L  # two-digit suffix used in MEPS variable names (e.g. 23)

# =============================================================================
# Year-specific variable names
# =============================================================================
# MEPS appends a two-digit year suffix to most person-level variables.
# All scripts reference these objects rather than hardcoded names so that
# changing `year` in run_all.R propagates everywhere automatically.
#
# NOTE: DNTINS variable names also encode the interview round (e.g. "31_M23").
# The pattern below (DNTINS31_M{yr} | DNTINS23_M{yr}) holds for 2022–2023.
# Verify against the codebook if using an earlier panel year.

var_weight  <- paste0("PERWT",  yr, "F")   # person-level analysis weight
var_visits  <- paste0("DVTOT",  yr)        # total dental visits (Q1)
var_totexp  <- paste0("DVTEXP", yr)        # total dental expenditures (Q2)
var_oopexp  <- paste0("DVTSLF", yr)        # out-of-pocket expenditures (Q2)
var_prvexp  <- paste0("DVTPRV", yr)        # private insurer payout (Q2)
var_age     <- paste0("AGE",    yr, "X")   # age (continuous covariate)
var_povcat  <- paste0("POVCAT", yr)        # poverty category (factor covariate)
var_insurc  <- paste0("INSURC", yr)        # any insurance coverage (Table 1)
var_dntins1 <- paste0("DNTINS31_M", yr)   # dental insurance eligibility filter (part 1)
var_dntins2 <- paste0("DNTINS23_M", yr)   # dental insurance eligibility filter (part 2)
# Allow overrides from run_all.R when auto-derived names don't match the file
if (exists("dntins1_override")) var_dntins1 <- dntins1_override
if (exists("dntins2_override")) var_dntins2 <- dntins2_override

# =============================================================================
# Intermediate file paths (derived from year)
# =============================================================================

fyc_rds         <- here::here("data", paste0("fyc_",         year, ".rds"))
dv_rds          <- here::here("data", paste0("dv_",          year, ".rds"))
design_full_rds <- here::here("data", paste0("design_full_", year, ".rds"))
design_dlr_rds  <- here::here("data", paste0("design_dlr_",  year, ".rds"))

# =============================================================================
# A priori covariate set
# =============================================================================
# Defined before data collection based on subject-matter knowledge.
# These are the minimum confounders considered stable and causally prior
# to both insurance status and dental utilization.
#
#   var_age   — age (continuous); older individuals use more dental care
#   SEX       — sex (1=Male, 2=Female); no year suffix in MEPS
#   RACEV2X   — race (MEPS Version 2 race variable); no year suffix
#   var_povcat — income as % of poverty line (1=Poor ... 5=High income)
#   EMPST53   — employment status; round-based suffix, consistent across years

covars_apriori <- c(var_age, "SEX", "RACEV2X", var_povcat, "EMPST53")

# formula_apriori has no left-hand side — attach an outcome with reformulate():
#   reformulate(covars_apriori, response = var_visits)
formula_apriori <- reformulate(covars_apriori)

# =============================================================================
# Analysis label (used as output file prefix)
# =============================================================================

if (!exists("label")) label <- paste0("dlr_", year)

# =============================================================================
# Print config to console when sourced
# =============================================================================

message("Config loaded (year = ", year, "):")
message("  Weight:    ", var_weight)
message("  Outcomes:  ", var_visits, ", ", var_totexp, ", ", var_oopexp, ", ", var_prvexp)
message("  Covariates (", length(covars_apriori), "): ", paste(covars_apriori, collapse = ", "))
