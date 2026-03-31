# =============================================================================
# config.R
# Central configuration for covariate sets and model formulas.
# Sourced by all analysis scripts — change covariates here, nowhere else.
#
# Usage in any script:
#   source(here::here("R", "config.R"))
#   svyglm(update(formula_apriori, dvtot23 ~ .), design = design_dlr)
# =============================================================================

# =============================================================================
# A priori covariate set
# =============================================================================
# Defined before data collection based on subject-matter knowledge.
# These are the minimum confounders considered stable and causally prior
# to both insurance status and dental utilization.
#
#   AGE23X   — age (continuous); older individuals use more dental care
#   SEX      — sex (1=Male, 2=Female)
#   RACEV2X  — race (MEPS Version 2 race variable)
#   POVCAT23 — income as % of poverty line (1=Poor … 5=High income)
#   EMPST53  — employment status (affects insurance access and time for care)

covars_apriori <- c("AGE23X", "SEX", "RACEV2X", "POVCAT23", "EMPST53")

# Formula with no left-hand side — use update() to attach an outcome:
#   update(formula_apriori, dvtot23 ~ .)
formula_apriori <- as.formula(
  paste("~", paste(covars_apriori, collapse = " + "))
)

# =============================================================================
# Print covariate set to console when sourced
# =============================================================================

message("Covariate set loaded:")
message("  A priori  (", length(covars_apriori), "): ",
        paste(covars_apriori, collapse = ", "))
