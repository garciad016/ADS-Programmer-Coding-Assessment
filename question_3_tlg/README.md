# Question 3: TLG Adverse Events Reporting

Produces three regulatory-style safety outputs from the `pharmaverseadam::adsl` and `pharmaverseadam::adae` ADaM datasets: a hierarchical TEAE summary table, an AE severity heatmap, and a top 10 AEs forest plot with 95% Clopper-Pearson confidence intervals.

## Inputs

| Source | Purpose |
|---|---|
| `pharmaverseadam::adsl` | Subject-level dataset (one row per subject). Used as the denominator for all percentages in the three outputs. |
| `pharmaverseadam::adae` | Adverse events dataset (one row per event per subject). Source of AESOC, AETERM, AESEV, ACTARM, and TRTEMFL. |

## Approach

The work is split across two scripts. The summary table and the two visualizations have different data preparation requirements, so they live separately:

**Script 1 (`01_create_ae_summary_table.R`):**

1. Read ADSL and ADAE from `pharmaverseadam`
2. Filter ADAE to `TRTEMFL == "Y"` (treatment-emergent only)
3. Build the hierarchical table using `gtsummary::tbl_hierarchical()` with `variables = c(AESOC, AETERM)`, `by = ACTARM`, `id = USUBJID`, `denominator = adsl`
4. Add total column via `add_overall()`, sort by descending frequency via `sort_hierarchical()`
5. Save as HTML via `gt::gtsave()`

**Script 2 (`02_create_visualizations.R`):**

1. Read ADSL and ADAE, filter ADSL to `ACTARM != "Screen Failure"` and ADAE to `TRTEMFL == "Y"`
2. Build the severity heatmap with `geom_tile()` + `geom_text()` on `count(ACTARM, AESEV)` (event-level counts, no deduplication)
3. Build the top 10 AEs forest plot: dedup via `distinct(USUBJID, AETERM)`, count per `AETERM`, compute incidence percentages and 95% Clopper-Pearson CIs using `binom.test()$conf.int`, plot with `geom_pointrange()`
4. Save both as PNGs at 300 DPI

## Outputs Delivered

- **TEAE Summary Table (HTML).** Hierarchical rows with AESOC as parent and AETERM indented beneath. One column per `ACTARM` plus a Total column, n (%) cells with ADSL as denominator, sorted by descending frequency. Mirrors FDA Table 10 from the Cardinal catalogue.
- **AE Severity Heatmap (PNG).** Three severity levels (MILD / MODERATE / SEVERE) by three treatment arms. Tile color shows count intensity, exact counts printed inside each tile. Colour-blind accessible blue gradient.
- **Top 10 AEs with 95% CIs (PNG).** Forest plot of the 10 most common AETERMs by unique subject count across all treated arms. Observed incidence percentages with Clopper-Pearson 95% CIs drawn as horizontal whiskers.

## Folder Contents

```
question_3_tlg/
├── README.md                                      (this file)
├── 01_create_ae_summary_table.R                   (summary table script)
├── 02_create_visualizations.R                     (visualizations script)
├── ae_summary_table.html                          (TEAE summary table)
├── ae_severity_by_treatment.png                   (severity heatmap)
├── top10_ae_with_ci.png                           (top 10 AEs forest plot)
├── execution_log_summary_table.txt                (log for script 1)
├── execution_log_visualizations.txt               (log for script 2)
├── ADS_Question_3_-_Scope.pdf                     (deliverable-by-deliverable reference)
└── ADS_Question_3_-_Coding_Explanations.pdf       (step-by-step code walkthrough)
```

For full details on the `tbl_hierarchical()` argument choices, Clopper-Pearson math, and design decisions (heatmap vs bar chart, severity ordering, denominator handling), refer to the two PDFs.

## How to Run

Open `question_3_tlg.Rproj` in RStudio, then:

```r
source("01_create_ae_summary_table.R")
source("02_create_visualizations.R")
```

Each script sets its own working directory and writes outputs alongside itself.

## References

- Cardinal FDA TLG catalogue: https://pharmaverse.github.io/cardinal/quarto/index-catalog.html
- `{gtsummary}` package documentation: https://www.danieldsjoberg.com/gtsummary/
- `{ggplot2}` documentation: https://ggplot2.tidyverse.org/
- `binom.test()` documentation: https://stat.ethz.ch/R-manual/R-devel/library/stats/html/binom.test.html
