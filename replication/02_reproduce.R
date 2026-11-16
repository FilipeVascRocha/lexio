# Reproduces every run of the thesis (2 markets x 2 shocks x 6 orderings = 24
# runs, each with 4 priority levels), writes every result and compares the
# indicators with the numbers published in the thesis.
#
# Data: replication/thesis_data/ (the attachment lexio-thesis-data-2018.zip
# of the GitHub release, downloaded if missing, or built by 01_declare_data.R).
#
# What the script does, for each market (fuels: CR x CNR x LAB; electricity:
# GD x GC x LAB):
#   1. runs coefficients/ + model_exact.yml: the coefficients and goals rounded
#      as in the computations of the thesis, so the problem is identical to the
#      one solved in the thesis; every level of every run must be optimal;
#   2. writes every result with write_outputs(), including the Excel workbook
#      results.xlsx (sheet final_<scenario>: xD1-xD3 and f'1-f'72 of the six
#      orderings side by side; sheet <scenario>_<ordering>: every stage of one
#      run; see the sheet about);
#   3. runs base/ + model.yml (the database as published, with every digit,
#      and the goals by their rules) and compares the numbers with step 1;
# and then compares the 12 indicators with the published values.
#
# Outputs (a new folder; nothing is overwritten): replication/outputs, then
# replication/outputs_2, ... or the folder given with --out:
#   fuels/, electricity/       every result of step 2 (README.md, results.xlsx, CSV tables, runs/)
#   published_numbers.csv      published x reconstructed indicators
#   flows_check.csv            step 3, per run
#
# Usage, from the root of the repository:
#   RStudio: open lexio.Rproj, open this file and click Source;
#   terminal: Rscript replication/02_reproduce.R [--out folder]

library(lexio)
replication_dir <- file.path(here::here(), "replication")
source(file.path(replication_dir, "R", "thesis_helpers.R"))
if (!interactive()) options(width = 200)

args <- commandArgs(trailingOnly = TRUE)
i <- match("--out", args)
out_dir <- if (is.na(i)) new_output_dir(file.path(replication_dir, "outputs")) else args[i + 1]
if (!is.na(i) && dir.exists(out_dir)) stop(out_dir, " already exists; use --out with another folder")
data_dir <- thesis_data_dir(replication_dir)

rel <- function(a, b) max(abs(a - b) / pmax(abs(a), abs(b), 1))
markets <- list(fuels = c(entrant = "CR", incumbent = "CNR"),
                electricity = c(entrant = "GD", incumbent = "GC"))
indicators <- list()
check <- list()
for (m in names(markets)) {
  e <- markets[[m]][["entrant"]]
  inc <- markets[[m]][["incumbent"]]

  cat("\n== ", m, ": the runs of the thesis (coefficients/ + model_exact.yml)\n", sep = "")
  res <- run_model(file.path(data_dir, m, "model_exact.yml"), verbose = FALSE)
  print(res)
  write_outputs(res, file.path(out_dir, m))
  indicators[[m]] <- thesis_indicators(res, entrant = e, incumbent = inc, labor = "LAB",
                                       entrant_scenario = e, incumbent_scenario = inc)

  cat("== ", m, ": the database as published (base/ + model.yml)\n", sep = "")
  # GLPK may report the last level of a few runs as not optimal (a numerical
  # false infeasibility of the exact lock; see vignette("model-specification"),
  # section 7); their numbers are still compared.
  flows <- suppressWarnings(run_model(file.path(data_dir, m, "model.yml"), verbose = FALSE))
  for (k in seq_along(res$runs)) {
    a <- res$runs[[k]]
    b <- flows$runs[[k]]
    check[[length(check) + 1]] <- data.frame(
      market = m, scenario = a$scenario, ordering = a$label,
      status_thesis = paste(a$status, collapse = ""), status_published_data = paste(b$status, collapse = ""),
      rel_diff_Z = rel(a$Z, b$Z), rel_diff_x_star = rel(a$x_star, b$x_star), rel_diff_Gx = rel(a$gx, b$gx),
      stringsAsFactors = FALSE
    )
  }
}
check <- do.call(rbind, check)
utils::write.csv(check, file.path(out_dir, "flows_check.csv"), row.names = FALSE)
cmp <- compare_thesis(indicators)
utils::write.csv(cmp, file.path(out_dir, "published_numbers.csv"), row.names = FALSE)

cat("\n================ Published x reconstructed ================\n")
print(cmp[, c("item", "published", "rounded", "match")], row.names = FALSE)
cat(sprintf("\n%d of %d published numbers match.\n", sum(cmp$match), nrow(cmp)))
cat(sprintf("Runs of the thesis with every level optimal: %d of %d.\n", sum(check$status_thesis == "0000"),
            nrow(check)))
cat(sprintf(paste("Database as published: largest relative difference to the runs of the thesis:",
                  "Z %.1g, x* %.1g, Gx %.1g.\n"),
            max(check$rel_diff_Z), max(check$rel_diff_x_star), max(check$rel_diff_Gx)))
cat("", paste("Every result is in", out_dir),
    "  fuels/results.xlsx and electricity/results.xlsx: the Excel workbooks (start with the sheet about)",
    "    final_<scenario>        xD1-xD3 and f'1-f'72 at the last level, the six orderings side by side",
    "    <scenario>_<ordering>   every stage (level 1 to 4) of one run, side by side",
    "    Gx_<scenario>, x_<scenario>, runs, levels, goals, states",
    "  published_numbers.csv: the comparison above", "", sep = "\n")
if (!all(cmp$match) || any(check$status_thesis != "0000")) {
  stop("some published number does not match, or a run of the thesis is not optimal")
}
