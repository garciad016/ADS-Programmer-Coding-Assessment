# Analytical Data Science Programmer Coding Assessment

Submission for the Roche ADS Programmer (Early Development) coding assessment. Covers the CDISC clinical data pipeline from raw eCRF data through SDTM, ADaM, and TLG (tables, listings, graphs) using the open-source pharmaverse R ecosystem.

**Author:** Daniel Garcia
**R version:** 4.5.3

---

## Repository Structure

```
.
├── README.md
├── .gitignore
├── question_1_sdtm/      # Q1: SDTM DS domain creation via {sdtm.oak}
├── question_2_adam/      # Q2: ADaM ADSL dataset creation via {admiral}
└── question_3_tlg/       # Q3: TEAE summary table + AE visualizations
```

Each question folder contains its own script(s), output files, execution log(s), and `.Rproj` file. See the README inside each folder for question-specific details.

---

## Question Summaries

**Question 1 — SDTM DS Domain.** Transforms raw disposition eCRF data into a CDISC-compliant SDTM Disposition domain with 12 variables. Mapping logic is driven by the aCRF programming notes and implemented using `{sdtm.oak}` algorithm functions.

**Question 2 — ADaM ADSL Dataset.** Builds a subject-level ADSL from five SDTM source domains (DM, EX, DS, AE, VS) using `{admiral}`. Derives four custom variables on top of the DM backbone: AGEGR9/AGEGR9N, TRTSDTM/TRTSTMF, ITTFL, and LSTAVLDT.

**Question 3 — TLG Adverse Events Reporting.** Three regulatory-style safety outputs from pharmaverse ADaM data: a hierarchical TEAE summary table using `{gtsummary}` (FDA Table 10 style), an AE severity heatmap, and a top-10 AEs forest plot with 95% Clopper-Pearson confidence intervals.

---

## Setup

```r
install.packages(c(
  "sdtm.oak", "pharmaverseraw", "pharmaversesdtm",
  "admiral", "pharmaverseadam",
  "gtsummary", "gt", "ggplot2",
  "dplyr", "stringr", "lubridate"
))
```

Open the `.Rproj` inside a question folder, then run the script(s). Working directory sets automatically and all outputs land alongside the script.


## Youtube Playlist Link: https://www.youtube.com/watch?v=WrSMHc4lpgA&list=PL9S_qvAAoDPRXkwetEax7m7pgSXshKwsQ
