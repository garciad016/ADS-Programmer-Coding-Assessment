# Question 3, Task 2: AE Visualizations
# Creates two plots for adverse events reporting using {ggplot2}
#
# Input:  pharmaverseadam::adae, pharmaverseadam::adsl
# Output: ae_severity_by_treatment.png, top10_ae_with_ci.png
#
# Reference: ggplot2 documentation - https://ggplot2.tidyverse.org/

# Load libraries
library(dplyr)
library(ggplot2)

# --- Set up execution log -----------------------------------------------------
# Captures console output + messages/warnings as evidence of clean run

log_con <- file("execution_log_visualizations.txt", open = "wt")
sink(log_con, split = TRUE)            # stdout -> log AND console
sink(log_con, type = "message")        # messages/warnings/errors -> log

cat("Question 3 Task 2: AE Visualizations Execution Log\n")
cat("Run time: ", format(Sys.time()), "\n")
cat("ggplot2:  ", as.character(packageVersion("ggplot2")), "\n\n")

# Load data
adsl <- pharmaverseadam::adsl |>
  filter(ACTARM != "Screen Failure")  # Exclude subjects who were never treated
adae <- pharmaverseadam::adae |>
  filter(TRTEMFL == "Y")  # added filter, assuming only AEs that started or worsened after first dose

# Plot 1: AE Severity Distribution by Treatment (Heatmap)
#
# - x-axis: Treatment arm (ACTARM)
# - y-axis: Severity level (AESEV: MILD, MODERATE, SEVERE)
# - fill:   Count of AEs (color intensity)
# - Each row in adae = one event (no deduplication needed)

# Order severity levels so they display logically on y-axis (MILD at bottom, SEVERE at top)
adae <- adae |>
  mutate(AESEV = factor(AESEV, levels = c("MILD", "MODERATE", "SEVERE")))

# Pre-aggregate counts - geom_tile() needs summarized data unlike geom_bar()
ae_severity_counts <- adae |>
  count(ACTARM, AESEV, name = "n")

p1 <- ggplot(ae_severity_counts, aes(x = ACTARM, y = AESEV, fill = n)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = n), size = 5, fontface = "bold") +  # display counts inside tiles
  scale_fill_gradient(low = "#DEEBF7", high = "#08519C") +  # colour-blind accessibility
  labs(
    title = "AE severity distribution by treatment",
    x = "Treatment Arm",
    y = "Severity/Intensity",
    fill = "Count of AEs"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10)),
    panel.grid = element_blank()
  )

# Save as PNG
ggsave("ae_severity_by_treatment.png", plot = p1, width = 8, height = 6, dpi = 300)

cat("Plot 1 saved to ae_severity_by_treatment.png\n")

# Plot 2: Top 10 Most Frequent AEs with 95% Clopper-Pearson CIs
#
# - Total n subject count across all treatment arms
# - AETERM used per assessment instructions
# - Each subject counted once per AETERM
# - Incidence = subjects with AE / total N from ADSL
# - 95% CI via binom.test() which uses the Clopper-Pearson exact method
#
# References:
# binom.test docs: https://www.rdocumentation.org/packages/stats/versions/3.6.2/topics/binom.test
# CI for proportions: https://rcompanion.org/handbook/H_02.html

n_total <- nrow(adsl)  # total subjects (denominator)

# Count unique subjects per AETERM and keep the top 10
top10_ae <- adae |>
  distinct(USUBJID, AETERM) |>           # one row per subject per AETERM
  count(AETERM, name = "n_subjects") |>  # subjects per AETERM
  slice_max(n_subjects, n = 10)

# binom.test() performs an exact test for a yes/no outcome (had AE or didn't).
# x = subjects with AE, n = total subjects.
# $conf.int gives the 95% Clopper-Pearson CI as a proportion (0-1).
top10_ae <- top10_ae |>
  rowwise() |>                           # binom.test() needs one row at a time
  mutate(
    pct      = n_subjects / n_total * 100,                         # incidence %
    ci_lower = binom.test(n_subjects, n_total)$conf.int[1] * 100,  # CI lower bound
    ci_upper = binom.test(n_subjects, n_total)$conf.int[2] * 100   # CI upper bound
  ) |>
  ungroup()

# Order by incidence so highest appears at bottom of plot
top10_ae <- top10_ae |>
  mutate(AETERM = reorder(AETERM, pct))

p2 <- ggplot(top10_ae, aes(x = pct, y = AETERM)) +
  # dot = incidence %, whiskers = 95% CI
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper),
                height = 0.3, linewidth = 0.5) +
  geom_point(size = 2) +
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", n_total, " subjects; 95% Clopper-Pearson CIs"),
    x = "Percentage of Patients (%)",
    y = NULL
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5)
  )

# Save as PNG
ggsave("top10_ae_with_ci.png", plot = p2, width = 8, height = 6, dpi = 300)

cat("Plot 2 saved to top10_ae_with_ci.png\n")

# --- Execution summary --------------------------------------------------------

cat("\nExecution Summary\n")
cat("ADSL subjects (treated, post-SF filter):", nrow(adsl), "\n")
cat("TEAE records (TRTEMFL == Y):            ", nrow(adae), "\n\n")

cat("Plot 1 - severity by treatment (ACTARM x AESEV counts):\n")
print(ae_severity_counts)

cat("\nPlot 2 - top 10 AEs (incidence % with 95% CI):\n")
print(top10_ae |> select(AETERM, n_subjects, pct, ci_lower, ci_upper))

cat("\nScript completed without errors.\n")

# Close log
sink(type = "message")
sink()
close(log_con)