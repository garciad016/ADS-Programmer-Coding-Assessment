# Question 3, Task 1: TEAE Summary Table (FDA Table 10)
# Creates a treatment-emergent adverse events summary table using {gtsummary}
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: ae_summary_table.html
#
# Key logic:
#   - Filter adae to treatment-emergent AEs only (TRTEMFL == "Y")
#   - Rows: AESOC as parent, AETERM indented beneath
#   - Count each subject once per term (not raw event counts)
#   - Percentages based on all subjects in ADSL per arm
#   - Columns: one per treatment arm (ACTARM) + Total
#   - Sorted by most common SOC/AETERM first
#
# Reference: Cardinal FDA Table 10 example
# https://pharmaverse.github.io/cardinal/quarto/catalog/fda-table_10/
# tbl_hierarchical.R: https://www.danieldsjoberg.com/gtsummary/reference/tbl_hierarchical.html

# Load libraries
library(dplyr)
library(gtsummary)

# --- Set up execution log -----------------------------------------------------
# Captures console output + messages/warnings as evidence of clean run

log_con <- file("execution_log_ae_summary.txt", open = "wt")
sink(log_con, split = TRUE)            # stdout -> log AND console
sink(log_con, type = "message")        # messages/warnings/errors -> log

cat("Question 3 Task 1: TEAE Summary Table Execution Log\n")
cat("Run time:  ", format(Sys.time()), "\n")
cat("gtsummary: ", as.character(packageVersion("gtsummary")), "\n\n")

# Load data
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# --- Pre-processing ----------------------------------------------------------
# Filter to treatment-emergent AEs only
# TRTEMFL == "Y" means the AE started or worsened after first dose of study drug
adae_teae <- adae |>
  filter(TRTEMFL == "Y")

# --- Build table -------------------------------------------------------------
# Build hierarchical TEAE summary table
# tbl_hierarchical() counts unique subjects per AE term with nested rows
tbl <- adae_teae |>
  tbl_hierarchical(
    variables = c(AESOC, AETERM),         # row structure: SOC as parent, AETERM indented beneath
    by = ACTARM,                          # one column per treatment arm
    id = USUBJID,                         # count each subject once per term
    denominator = adsl,                   # percentages based on all subjects in ADSL
    overall_row = TRUE,                   # adds "Treatment Emergent AEs" row showing totals across all AEs
    label = "..ard_hierarchical_overall.." ~ "Treatment Emergent AEs"
  ) |>
  # Add Total column across all arms
  add_overall() |>
  # Sort by most common SOC/AETERM first
  sort_hierarchical()

# --- Save output -------------------------------------------------------------
# Save as HTML
tbl |>
  as_gt() |>
  gt::gtsave(filename = "ae_summary_table.html")

# --- Execution summary --------------------------------------------------------

cat("\nExecution Summary\n")
cat("TEAE records (TRTEMFL == Y):    ", nrow(adae_teae), "\n")
cat("Subjects with at least one TEAE:", length(unique(adae_teae$USUBJID)), "\n")
cat("Distinct SOCs:                  ", length(unique(adae_teae$AESOC)), "\n")
cat("Distinct AETERMs:               ", length(unique(adae_teae$AETERM)), "\n\n")

cat("ADSL denominators (per ACTARM):\n")
print(table(adsl$ACTARM, useNA = "ifany"))

cat("\nOutput: ae_summary_table.html\n")
cat("Script completed without errors.\n")

# Close log
sink(type = "message")
sink()
close(log_con)