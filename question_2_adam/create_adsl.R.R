# --- Question 2: ADaM ADSL Dataset Creation using {admiral} ------------------
# Daniel Garcia
# Input:  pharmaversesdtm::dm, ::ex, ::ds, ::ae, ::vs
# Output: adsl.csv

# References:
#   - https://pharmaverse.github.io/examples/adam/adsl.html
#   - https://pharmaverse.github.io/admiral/articles/adsl.html
#   - CDISC ADaMIG v1.3, Section 3.2: https://www.cdisc.org/system/files/members/standard/foundational/ADaMIG_v1.3.pdf

library(admiral)
library(dplyr, warn.conflicts = FALSE)
library(pharmaversesdtm)
library(lubridate)
library(stringr)

# --- Set up execution log -----------------------------------------------------
# Captures console output + messages/warnings as evidence of clean run

log_con <- file("execution_log_adsl.txt", open = "wt")
sink(log_con, split = TRUE)            # stdout -> log AND console
sink(log_con, type = "message")        # messages/warnings/errors -> log

cat("Question 2: ADSL Execution Log\n")
cat("Run time: ", format(Sys.time()), "\n")
cat("admiral:  ", as.character(packageVersion("admiral")), "\n\n")

# --- Read in Data --------------------------
# convert_blanks_to_na() turns SAS blank strings into R NA values.

dm <- pharmaversesdtm::dm %>% convert_blanks_to_na()
ex <- pharmaversesdtm::ex %>% convert_blanks_to_na()
ds <- pharmaversesdtm::ds %>% convert_blanks_to_na()
ae <- pharmaversesdtm::ae %>% convert_blanks_to_na()
vs <- pharmaversesdtm::vs %>% convert_blanks_to_na()


# --- ADSL Base from DM ----------------------
# DM is one-row-per-subject with all Required ADSL variables.
# TRT01P = planned treatment, mapped from ARM.
# TRT01A = actual treatment, mapped from ACTARM.

adsl <- dm %>%
  select(-DOMAIN) %>%
  mutate(TRT01P = ARM, TRT01A = ACTARM)


# --- Derived Variable #1: AGEGR9 / AGEGR9N - Age Grouping ---------------------

# Key decisions:
#   - Used derive_vars_cat() over case_when() to stay in the admiral ecosystem.
#     It creates both text (AGEGR9) and numeric (AGEGR9N) in one call.
#   - is.na(AGE) goes first in the lookup since first match wins - prevents
#     NA ages from falling into a numeric bin.
#
# Logic:
#   1. Define lookup with conditions and output values.
#   2. derive_vars_cat() evaluates top-to-bottom, first match wins.

agegr9_lookup <- exprs(
  ~condition, ~AGEGR9, ~AGEGR9N,
  is.na(AGE), NA_character_, NA_real_,
  AGE < 18, "<18", 1,
  between(AGE, 18, 50), "18 - 50", 2,
  !is.na(AGE), ">50", 3
)

adsl <- adsl %>%
  derive_vars_cat(definition = agegr9_lookup)


# --- Derived Variable #2: TRTSDTM / TRTSTMF - Treatment Start Datetime -------------------------

# Key decisions:
#   - Valid dose: EXDOSE > 0, or zero dose for placebo arms (per spec NOTE).
#     Without the placebo check, all placebo subjects would be filtered out.
#   - TRTEDTM derived here because LSTAVLDT source 4 needs its date version (TRTEDT)
#   - No imputation flag for TRTEDTM - spec only requires TRTSTMF
#
# Logic:
#   1. derive_vars_dtm() converts text dates to datetimes and imputes missing time.
#   2. derive_vars_merged() merges columns from another dataset into ADSL.
#      Filters to valid doses, picks the earliest per subject.
#   3. Same but picks the last -> TRTEDTM
#   4. derive_vars_dtm_to_dt() strips time, keeps date only.

# Convert text dates to datetimes, impute start times to 00:00:00, end to 23:59:59
ex_with_datetimes <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC,
    new_vars_prefix = "EXST",            # names output: "EXST" + "DTM" = EXSTDTM, + "TMF" = EXSTTMF
    ignore_seconds_flag = TRUE            # per spec: don't flag if only seconds imputed
  ) %>%
  derive_vars_dtm(
    dtc = EXENDTC,
    new_vars_prefix = "EXEN",
    time_imputation = "last"              # end times impute to 23:59:59
  )

# Filter to valid doses, pick first per subject -> TRTSDTM + TRTSTMF
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_with_datetimes,
    # Valid dose filter: got drug (EXDOSE > 0) or placebo (EXDOSE == 0 + PLACEBO) + complete date
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  )

# Same but pick last -> TRTEDTM (needed for LSTAVLDT source 4, no flag per spec)
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_with_datetimes,
    filter_add = (EXDOSE > 0 |
                    (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))) &
      !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM),
    order = exprs(EXENDTM, EXSEQ),
    mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  )

# Strip time: TRTSDTM -> TRTSDT, TRTEDTM -> TRTEDT
adsl <- adsl %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM))


# --- Derived Variable #3: ITTFL - Intent-to-Treat Flag -------------------------------

# Key decisions:
#   - No admiral function - population flags are study-specific, so mutate + if_else
#     is the standard approach per the admiral documentation.
#   - Screen Failure subjects have ARM = "Screen Failure" (not NA), so they get "Y".
#     Spec says "Y if ARM not missing" - Screen Failure is not missing. Followed literally.
#
# Logic:
#   1. ARM is populated -> "Y". ARM is missing -> "N".

adsl <- adsl %>%
  mutate(ITTFL = if_else(!is.na(ARM), "Y", "N"))


# --- Derived Variable #4: LSTAVLDT - Last Known Alive Date ----------------------------

# Key decisions:
#   - Used derive_vars_extreme_event() - the standard admiral pattern for composite
#     "last known alive" derivations from the ADSL vignette.
#   - Source 4 uses TRTEDT (derived above), not raw EX data, since the valid dose
#     filter was already applied when deriving TRTEDTM.
#
# Logic:
#   1. derive_vars_extreme_event() pools dates from multiple sources, picks the
#      latest (mode = "last") per subject.
#   2. Each event() defines a source, a qualifying condition, and the date to extract.
#   3. convert_dtc_to_dt() converts character dates to numeric inside each event.

adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      # Source 1: Vital signs - at least one result recorded + complete date
      event(
        dataset_name = "vs",
        order = exprs(VSDTC, VSSEQ),
        condition = (!is.na(VSSTRESN) | !is.na(VSSTRESC)) &  # actual result, not skipped
          !is.na(VSDTC),                                       # complete date
        set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(VSDTC))
      ),
      # Source 2: Adverse events - complete onset date
      event(
        dataset_name = "ae",
        order = exprs(AESTDTC, AESEQ),
        condition = !is.na(AESTDTC),
        set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(AESTDTC))
      ),
      # Source 3: Disposition - complete disposition date
      event(
        dataset_name = "ds",
        order = exprs(DSSTDTC, DSSEQ),
        condition = !is.na(DSSTDTC),
        set_values_to = exprs(LSTAVLDT = convert_dtc_to_dt(DSSTDTC))
      ),
      # Source 4: Exposure - last valid dose date (TRTEDT derived above)
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDT),
        set_values_to = exprs(LSTAVLDT = TRTEDT)
      )
    ),
    source_datasets = list(vs = vs, ae = ae, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTAVLDT, event_nr),
    mode = "last",
    new_vars = exprs(LSTAVLDT)
  )


# --- Save Output --------------------------------------------------------------

write.csv(adsl, file = "adsl.csv", row.names = FALSE, na = "")


# --- Execution summary --------------------------------------------------------

cat("\nExecution Summary\n")
cat("ADSL created: ", nrow(adsl), "rows x", ncol(adsl), "cols\n\n")

cat("AGEGR9 distribution:\n")
print(table(adsl$AGEGR9, useNA = "ifany"))

cat("\nITTFL distribution:\n")
print(table(adsl$ITTFL, useNA = "ifany"))

cat("\nDerivation population checks (non-NA counts):\n")
cat("  TRTSDTM: ", sum(!is.na(adsl$TRTSDTM)), "/", nrow(adsl), "\n")
cat("  TRTSTMF: ", sum(!is.na(adsl$TRTSTMF)), "/", nrow(adsl), "\n")
cat("  LSTAVLDT:", sum(!is.na(adsl$LSTAVLDT)), "/", nrow(adsl), "\n")

cat("\nScript completed without errors.\n")

# Close log
sink(type = "message")
sink()
close(log_con)