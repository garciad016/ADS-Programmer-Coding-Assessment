# Question 1: SDTM DS Domain Creation using {sdtm.oak} - Daniel Garcia
#
# Input:  pharmaverseraw::ds_raw
# Output: SDTM DS domain with 12 variables (categorized based on SDTMIG)
#   Identifiers: STUDYID, DOMAIN, USUBJID, DSSEQ
#   Topic:       DSTERM
#   Qualifiers:  DSDECOD, DSCAT
#   Timing:      VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
#
# aCRF Mapping Summary:
#   DSTERM:   IT.DSTERM (when OTHERSP null) or OTHERSP (when not null)
#   DSDECOD:  IT.DSDECOD via CT C66727 (when OTHERSP null) or OTHERSP (when not null)
#   DSCAT:    "OTHER EVENT" / "PROTOCOL MILESTONE" / "DISPOSITION EVENT" (conditional)
#   DSSTDTC:  IT.DSSTDAT -> ISO 8601
#   DSDTC:    DSDTCOL + DSTMCOL -> ISO 8601
#   VISIT:    INSTANCE via CT "VISIT"
#   VISITNUM: INSTANCE via CT "VISITNUM"
#
# References:
#   SDTMIG:     https://www.cdisc.org/system/files/members/standard/foundational/SDTMIG%20v3.4-FINAL_2022-07-21.pdf
#   aCRF:       https://github.com/pharmaverse/pharmaverseraw/blob/main/vignettes/articles/aCRFs/Subject_Disposition_aCRF.pdf
#   Algorithms: https://pharmaverse.github.io/sdtm.oak/articles/algorithms.html
#   CRAN manual:https://cran.r-project.org/web/packages/sdtm.oak/sdtm.oak.pdf
#   CT:         https://github.com/pharmaverse/examples/blob/main/metadata/sdtm_ct.csv
#   Example:    https://pharmaverse.github.io/sdtm.oak/articles/interventions_domain.html
#   Example:    https://pharmaverse.github.io/examples/sdtm/ae.html

library(sdtm.oak)
library(pharmaverseraw)
library(pharmaversesdtm)
library(dplyr)

# --- Set up execution log -----------------------------------------------------
# Captures console output + messages/warnings

log_con <- file("execution_log_ds_domain.txt", open = "wt")
sink(log_con, split = TRUE)            # stdout -> log AND console
sink(log_con, type = "message")        # messages/warnings/errors -> log

cat("Question 1: DS Domain Execution Log\n")
cat("Run time: ", format(Sys.time()), "\n")
cat("sdtm.oak: ", as.character(packageVersion("sdtm.oak")), "\n\n")

# --- Step 1. Read in data -----------------------------------------------------

ds_raw <- pharmaverseraw::ds_raw
dm <- pharmaversesdtm::dm  # needed by derive_study_day() for RFSTDTC

# --- Step 2. Create oak_id_vars -----------------------------------------------
# Tracking columns ({sdtm.oak} uses these to merge mapped variables back to rows)

ds_raw <- ds_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", raw_src = "ds_raw")

# Data quality fix #1: ds_raw has "Ambul Ecg Removal" but study_ct expects
# "Ambul ECG Removal". assign_ct() does exact matching.
ds_raw$INSTANCE <- gsub("Ecg", "ECG", ds_raw$INSTANCE)

# --- Step 3. Read in CT -------------------------------------------------------
# assign_ct() expects columns: codelist_code, collected_value, term_value

study_ct <- read.csv("sdtm_ct.csv")

# --- Step 4. Map topic variable -----------------------------------------------
# aCRF: "If OTHERSP is null then map IT.DSTERM to DSTERM"
#       "If OTHERSP is not null then map OTHERSP to DSDECOD and also to DSTERM"
# assign_no_ct: one-to-one mapping with no CT restrictions
# condition_add: filters raw data so the mapping only applies to matching rows

ds <-
  assign_no_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) | OTHERSP == ""),
    raw_var = "IT.DSTERM",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  ) %>%
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) & OTHERSP != ""),
    raw_var = "OTHERSP",
    tgt_var = "DSTERM",
    id_vars = oak_id_vars()
  )

# --- Step 5. Map qualifiers and timing ----------------------------------------

ds <- ds %>%
  
  # DSDECOD
  # aCRF: "If OTHERSP is null then map IT.DSDECOD to DSDECOD"
  #       "If OTHERSP is not null then map OTHERSP to DSDECOD"
  # assign_ct: one-to-one mapping with CT - reads raw value, filters study_ct
  #   to codelist C66727, matches collected_value, returns term_value
  #   e.g. "Adverse Event" -> "ADVERSE EVENT"
  assign_ct(
    raw_dat = condition_add(ds_raw, is.na(OTHERSP) | OTHERSP == ""),
    raw_var = "IT.DSDECOD",
    tgt_var = "DSDECOD",
    ct_spec = study_ct,
    ct_clst = "C66727",
    id_vars = oak_id_vars()
  ) %>%
  # When OTHERSP is not null, no CT - copy directly
  assign_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) & OTHERSP != ""),
    raw_var = "OTHERSP",
    tgt_var = "DSDECOD",
    id_vars = oak_id_vars()
  ) %>%
  
  # DSCAT - three cases from two aCRF yellow boxes:
  #   aCRF IT.DSDECOD box: "If IT.DSDECOD = Randomized -> PROTOCOL MILESTONE
  #                         else DISPOSITION EVENT"
  #   aCRF OTHERSP box:    "If OTHERSP is not null -> OTHER EVENT"
  # hardcode_no_ct: stamps a fixed value; raw_var only checked for NA, not copied
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, !is.na(OTHERSP) & OTHERSP != ""),
    raw_var = "OTHERSP",
    tgt_var = "DSCAT",
    tgt_val = "OTHER EVENT",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, (is.na(OTHERSP) | OTHERSP == "") & IT.DSDECOD == "Randomized"),
    raw_var = "IT.DSTERM",
    tgt_var = "DSCAT",
    tgt_val = "PROTOCOL MILESTONE",
    id_vars = oak_id_vars()
  ) %>%
  hardcode_no_ct(
    raw_dat = condition_add(ds_raw, (is.na(OTHERSP) | OTHERSP == "") & IT.DSDECOD != "Randomized"),
    raw_var = "IT.DSTERM",
    tgt_var = "DSCAT",
    tgt_val = "DISPOSITION EVENT",
    id_vars = oak_id_vars()
  )

# --- Timing ---

ds <- ds %>%
  # DSSTDTC - aCRF: "Map IT.DSSDAT to DSSTDTC in ISO8601 format"
  # assign_datetime: parses raw date string using raw_fmt, outputs ISO 8601
  # raw_fmt "m-d-y" matches actual format ("01-02-2014")
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = c("m-d-y"),
    id_vars = oak_id_vars()
  ) %>%
  # DSDTC - aCRF: "Map DSDTCOL & DSTMCOL to DSDTC in ISO8601 format"
  # Two raw columns combined into one datetime
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC",
    raw_fmt = c("m-d-y", "H:M"),
    id_vars = oak_id_vars()
  ) %>%
  # VISIT - no VISIT column in ds_raw; INSTANCE has visit values ("Baseline", etc.)
  # assign_ct translates via "VISIT" codelist ("Baseline" -> "BASELINE")
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  # VISITNUM - same column (INSTANCE), different codelist ("Baseline" -> 3)
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  ) %>%
  # Data quality fix: SDTMIG requires VISITNUM to be numeric. The study_ct
  # VISITNUM codelist returns text labels like "UNSCHEDULED 6.1" for unscheduled
  # visits, so strip the prefix and cast to numeric (6.1 for ex)
  mutate(VISITNUM = as.numeric(gsub("UNSCHEDULED ", "", VISITNUM)))

# --- Step 6. Derived identifiers and study day --------------------------------

ds <- ds %>%
  dplyr::mutate(
    STUDYID = ds_raw$STUDY,
    DOMAIN  = "DS",
    USUBJID = paste0("01-", ds_raw$PATNUM)
  ) %>%
  # DSSEQ - auto-numbers each record per subject, ordered by event date
  derive_seq(
    tgt_var  = "DSSEQ",
    rec_vars = c("USUBJID", "DSSTDTC")
  ) %>%
  # DSSTDY = how many days into the study the disposition event happened.
  # Calculated as event date (DSSTDTC) minus study start date (RFSTDTC from DM,
  # joined on USUBJID).
  #
  # NOTE: Screen failures never started the study, so they have no RFSTDTC to
  # subtract from. DSSTDY comes back NA for those rows - expected, not a bug.
  derive_study_day(
    sdtm_in       = .,
    dm_domain     = dm,
    tgdt          = "DSSTDTC",   # target date, the event we want the study day for
    refdt         = "RFSTDTC",   # reference date, the study start (Day 1)
    study_day_var = "DSSTDY"     # name of the output column
  )

# --- Step 7. Select and export ------------------------------------------------

ds_final <- ds %>%
  select(STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD,
         DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY) %>%
  arrange(USUBJID, DSSEQ)

write.csv(ds_final, "ds_domain.csv", row.names = FALSE)

# --- Execution summary --------------------------------------------------------

cat("\nExecution Summary\n")
cat("DS domain created: ", nrow(ds_final), "rows x", ncol(ds_final), "cols\n")
cat("Unique subjects:   ", length(unique(ds_final$USUBJID)), "\n\n")

cat("DSCAT distribution (confirms all 3 conditional branches fired):\n")
print(table(ds_final$DSCAT, useNA = "ifany"))

cat("\nDate parsing check (should be 0 NAs if formats matched):\n")
cat("  DSSTDTC NAs:", sum(is.na(ds_final$DSSTDTC)), "\n")
cat("  DSDTC NAs:  ", sum(is.na(ds_final$DSDTC)), "\n")

cat("\nVISITNUM type check (should be numeric per SDTMIG):\n")
cat("  class:", class(ds_final$VISITNUM), "\n")
cat("  NAs:  ", sum(is.na(ds_final$VISITNUM)), "\n")

cat("\nDSSTDY NA check (expected non-zero for screen failures):\n")
cat("  Total NAs:         ", sum(is.na(ds_final$DSSTDY)), "\n")
cat("  SCREEN FAILURE NAs:", sum(is.na(ds_final$DSSTDY) & ds_final$DSDECOD == "SCREEN FAILURE"), "\n")

cat("\nScript completed without errors.\n")

# Close log
sink(type = "message")
sink()
close(log_con)