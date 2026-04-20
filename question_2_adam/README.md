# Question 2: ADaM ADSL Dataset Creation

Builds a CDISC-compliant ADaM Subject-Level Analysis Dataset (ADSL) from five SDTM source domains using the `{admiral}` pharmaverse package. The DM domain is the base; four custom variables are derived on top per the assessment spec.

## Inputs

| Source | Purpose |
|---|---|
| `pharmaversesdtm::dm` | Demographics. The base ADSL domain (every ADSL row starts from a DM row). |
| `pharmaversesdtm::ex` | Exposure. Used for `TRTSDTM`, `TRTEDTM`, and `LSTAVLDT` source 4. |
| `pharmaversesdtm::ds` | Disposition. Used for `LSTAVLDT` source 3. |
| `pharmaversesdtm::ae` | Adverse Events. Used for `LSTAVLDT` source 2. |
| `pharmaversesdtm::vs` | Vital Signs. Used for `LSTAVLDT` source 1. |

## Approach

The script follows the standard `{admiral}` ADSL programming pipeline, modeled on the pharmaverse ADSL example:

1. Read in the five SDTM source domains and apply `convert_blanks_to_na()`
2. Build the ADSL base from DM (drop `DOMAIN`, set `TRT01P`/`TRT01A` from `ARM`/`ACTARM`)
3. Derive `AGEGR9` / `AGEGR9N` using `derive_vars_cat()` with a lookup table
4. Derive `TRTSDTM` / `TRTSTMF` (first valid dose) and `TRTEDTM` / `TRTSDT` / `TRTEDT` using `derive_vars_dtm()` + `derive_vars_merged()` + `derive_vars_dtm_to_dt()`
5. Derive `ITTFL` using `mutate()` + `if_else()`
6. Derive `LSTAVLDT` using `derive_vars_extreme_event()` across four sources (VS, AE, DS, exposure)
7. Save outputs and print a QC summary to the log

## Variables Delivered

**Base (carried from DM):** `STUDYID`, `USUBJID`, `SUBJID`, `SITEID`, `AGE`, `AGEU`, `SEX`, `RACE`, `ARM`, `ACTARM`, `TRT01P`, `TRT01A`

**Custom (required by assessment):**

- `AGEGR9` / `AGEGR9N`: age groups `<18`, `18 - 50`, `>50` and numeric codes `1`, `2`, `3`
- `TRTSDTM` / `TRTSTMF`: first valid dose datetime and its imputation flag
- `ITTFL`: intent-to-treat flag (`Y` if `ARM` populated, else `N`)
- `LSTAVLDT`: last known alive date, max across vital signs, AE onset, disposition, and exposure

**Infrastructure (needed by LSTAVLDT):** `TRTEDTM`, `TRTSDT`, `TRTEDT`

## Folder Contents

```
question_2_adam/
├── README.md                                    (this file)
├── create_adsl.R                                (main script)
├── adsl.csv                                     (output dataset)
├── execution_log.txt                            (evidence of error-free run)
├── ADS_Question_2_-_Scope.pdf                   (variable-by-variable derivation reference)
└── ADS_Question_2_-_Coding_Explanations.pdf     (step-by-step code walkthrough)
```

For the full derivation logic, `{admiral}` function argument choices, and imputation rules, refer to the two PDFs.

## How to Run

Open `question_2_adam.Rproj` in RStudio, then:

```r
source("create_adsl.R")
```

The script sets its own working directory and writes outputs alongside itself.

## References

- ADaMIG v1.3 Section 3.2: ADSL Specification
- `{admiral}` ADSL vignette: https://pharmaverse.github.io/admiral/cran-release/articles/adsl.html
- `{admiral}` package documentation: https://pharmaverse.github.io/admiral/
- Pharmaverse ADSL example: https://pharmaverse.github.io/examples/adam/adsl.html
