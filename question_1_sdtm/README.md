# Question 1: SDTM DS Domain Creation

Transforms raw disposition eCRF data from `pharmaverseraw::ds_raw` into a CDISC-compliant SDTM Disposition (DS) domain with 12 variables, using the `{sdtm.oak}` pharmaverse package.

## Inputs

| Source | Purpose |
|---|---|
| `pharmaverseraw::ds_raw` | Raw disposition eCRF data. This is the source being transformed. |
| `pharmaversesdtm::dm` | Needed by `derive_study_day()` to pull `RFSTDTC` for the `DSSTDY` calculation. |
| `sdtm_ct.csv` | Study controlled terminology. Translates eCRF dropdown values into CDISC standard terms. |

## Approach

The script follows the standard `{sdtm.oak}` programming workflow, modeled on the pharmaverse AE example:

1. Read in raw data
2. Generate `oak_id_vars` (the tracking columns that link raw rows to SDTM output)
3. Load controlled terminology
4. Map the topic variable (`DSTERM`)
5. Map qualifiers and timing variables (`DSDECOD`, `DSCAT`, `VISIT`, `VISITNUM`, `DSSTDTC`, `DSDTC`)
6. Derive identifiers and study day (`STUDYID`, `DOMAIN`, `USUBJID`, `DSSEQ`, `DSSTDY`)

Mapping logic comes from the aCRF programming notes (yellow boxes). The choice of `{sdtm.oak}` algorithm (`assign_no_ct`, `assign_ct`, `hardcode_no_ct`, `assign_datetime`) depends on the type of field on the aCRF: free text, coded dropdown, not collected, or date/time. Conditional mappings (for example, cases where `OTHERSP` is not null) are handled with `condition_add()`.

## Variables Delivered

`STUDYID`, `DOMAIN`, `USUBJID`, `DSSEQ`, `DSTERM`, `DSDECOD`, `DSCAT`, `VISITNUM`, `VISIT`, `DSDTC`, `DSSTDTC`, `DSSTDY`

## Data Quality Issues Found and Fixed

| Issue | Fix |
|---|---|
| `raw_fmt = "m/d/y"` produced all-NA dates; actual format uses dashes (`"01-02-2014"`). | Changed `raw_fmt` to `"m-d-y"`. |
| `ds_raw` has `"Ambul Ecg Removal"` but `study_ct` has `"Ambul ECG Removal"`, so `assign_ct()` couldn't match. | `gsub("Ecg", "ECG", ds_raw$INSTANCE)` |
| `study_ct` VISITNUM codelist returns text like `"UNSCHEDULED 6.1"`, but SDTMIG requires numeric. | Stripped the `"UNSCHEDULED "` prefix and cast to numeric. |

## Folder Contents

```
question_1_sdtm/
├── README.md                                    (this file)
├── 01_create_ds_domain.R                        (main script)
├── ds_domain.csv                                (output dataset)
├── execution_log.txt                            (evidence of error-free run)
├── ADS_Question_1_-_Scope.pdf                   (variable-by-variable mapping reference)
└── ADS_Question_1_-_Coding_Explanations.pdf     (step-by-step code walkthrough)
```

For a full breakdown of the 12 SDTM variables, the algorithm behind each mapping, and the aCRF yellow-box logic, refer to the two PDFs.

## How to Run

Open `question_1_sdtm.Rproj` in RStudio, then:

```r
source("01_create_ds_domain.R")
```

The script sets its own working directory and writes outputs alongside itself.

## References

- SDTMIG v3.4 Section 6.2.4: DS Domain Specification
- `{sdtm.oak}` CRAN manual: https://cran.r-project.org/web/packages/sdtm.oak/sdtm.oak.pdf
- `{sdtm.oak}` algorithms: https://pharmaverse.github.io/sdtm.oak/articles/algorithms.html
- Pharmaverse AE example: https://pharmaverse.github.io/examples/sdtm/ae.html
- Disposition aCRF: https://github.com/pharmaverse/pharmaverseraw/blob/main/vignettes/articles/aCRFs/Subject_Disposition_aCRF.pdf
