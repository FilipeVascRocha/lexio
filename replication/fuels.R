# The model of the thesis, step by step: the FUELS market.
#
# Renewable fuels (CR = biodiesel + ethanol, the entrant) against
# non-renewable fuels (CNR = petroleum products + natural gas, the
# incumbent), with labour (LAB), on the input-output matrix of Brazil with
# energy-sector detail (EPE/FIPE, 72 sectors, base year 2018). It mirrors
# electricity.R; read that one first for the notation. 02_reproduce.R runs
# both markets with every check.
#
# Output: every result, in a new folder (nothing is overwritten):
# replication/outputs_fuels, then _2, _3, ... The console shows every run
# level by level, the summary tables and the published numbers.
#
# Usage, from the root of the repository:
#   RStudio: open lexio.Rproj, open this file and click Source (or run it line
#            by line with Ctrl+Enter);
#   terminal: Rscript replication/fuels.R

library(lexio)
replication_dir <- file.path(here::here(), "replication")
source(file.path(replication_dir, "R", "thesis_helpers.R"))
if (!interactive()) options(width = 200)
out_dir <- new_output_dir(file.path(replication_dir, "outputs_fuels"))

# ------------------------------------------------------------------------------
# Step 0. Where the data are
# ------------------------------------------------------------------------------
# replication/thesis_data/ (downloaded here if missing; see electricity.R).
data_dir <- file.path(thesis_data_dir(replication_dir), "fuels", "coefficients")

# ------------------------------------------------------------------------------
# Step 1. The data, as vectors in the R session
# ------------------------------------------------------------------------------
#   sectors.csv   code, name           the 72 sectors and their order
#   B.csv         code + 72 columns    B = I - A
#   x.csv         code, value          gross output x, R$ million
#   f.csv         code, value          final demand f, R$ million
#   D.csv         code, CR, CNR, LAB   coefficients: toe (CR, CNR) and jobs (LAB) per R$ million of output
#   corridor.csv  code, alpha          corridor: intersectoral purchases of fuels / x
# The coefficients of the published flows (thesis_data/fuels/base/), rounded
# to 15 significant digits as in the computations of the thesis.
read_table <- function(name) {
  utils::read.csv(file.path(data_dir, paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE,
                  colClasses = c(code = "character"), encoding = "UTF-8")
}
sectors <- read_table("sectors")          # code and name of the 72 sectors
B <- as.matrix(read_table("B")[, -1])     # I - A (the first column is the code)
x <- read_table("x")$value                # gross output
f <- read_table("f")$value                # final demand
D <- read_table("D")
D_CR <- D$CR                              # renewable fuels (biodiesel + ethanol), toe per R$ million
D_CNR <- D$CNR                            # non-renewable fuels (petroleum products + natural gas), toe per R$ million
D_LAB <- D$LAB                            # jobs per R$ million
alpha <- read_table("corridor")$alpha     # corridor

# ------------------------------------------------------------------------------
# Step 2. Declare the database
# ------------------------------------------------------------------------------
io <- declare_io(B = B, x = x, f = f,
                 D = list(CR = D_CR, CNR = D_CNR, LAB = D_LAB),
                 corridor = alpha,
                 sectors = sectors)
print(io)            # the base of each account, b_j = D_j x

# ------------------------------------------------------------------------------
# Step 3. Declare the model
# ------------------------------------------------------------------------------
#   CR   entrant,    ">=": should not fall below its goal
#   CNR  incumbent,  "<=": should not exceed its goal
#   LAB  labour,     ">=": grows by the share of the shock (5%)
# The goal of each account is its total level in the scenario (base + shock).
# The shock is 5% of the pooled base of CR and CNR:
#   scenario CR:  g_CR  = b_CR  + 0.05 (b_CR + b_CNR), g_CNR = b_CNR
#   scenario CNR: g_CNR = b_CNR + 0.05 (b_CR + b_CNR), g_CR  = b_CR
#   both:         g_LAB = b_LAB x 1.05
#
# Priority orderings. With my_orderings <- NULL, every ordering of the three
# accounts is run: 3! = 6, P01..P06 (P1..P6 in the thesis). To run only some
# orderings, list them, for instance
#   my_orderings <- list(c("CNR", "CR", "LAB"))
# ECO is always the last level.
share <- 0.05
shock <- list(type = "pooled_share", share = share, pool = c("CR", "CNR"))
my_orderings <- NULL
model <- define_model(
  accounts = list(
    CR = list(direction = ">=", target = list(type = "base"), unit = "toe",
              label = "Renewable fuels (biodiesel + ethanol)"),
    CNR = list(direction = "<=", target = list(type = "base"), unit = "toe",
               label = "Non-renewable fuels (petroleum products + natural gas)"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = share), unit = "jobs",
               label = "Labour (jobs)")
  ),
  # ECO: (I - A) x >= f, one goal per sector, at the last level, absolute deviations
  economy = list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute"),
  scenarios = list(CR = list(CR = shock),      # the shock goes to the entrant
                   CNR = list(CNR = shock)),   # the shock goes to the incumbent
  priorities = if (is.null(my_orderings)) "all" else my_orderings,
  corridor = list(use = TRUE, multiplier = 1),
  lock_tolerance = "exact",
  name = "thesis_fuels"
)
print(model)

# The goals, from the bases: account, base, shock and total goal in each scenario
base <- satellite_base(io)
goals <- data.frame(account = names(base), base = base,
                    goal_CR = build_goals(io, model, "CR")[1:3],
                    goal_CNR = build_goals(io, model, "CNR")[1:3], row.names = NULL)
goals$change_CR <- goals$goal_CR - goals$base
goals$change_CNR <- goals$goal_CNR - goals$base
print(goals)

# ------------------------------------------------------------------------------
# Step 4. Run every ordering of every scenario and write the outputs
# ------------------------------------------------------------------------------
res <- run_model(io, model, verbose = TRUE)
write_outputs(res, out_dir)

# ------------------------------------------------------------------------------
# Step 5. Every result
# ------------------------------------------------------------------------------
acc <- names(model$accounts)
s <- res$summary
cat("\n================ Every run (scenario x ordering), level by level ================\n")
for (r in res$runs) {
  cat("\n")
  print(r)
}
cat("\n================ One row per run ================\n")
print(s$runs[, c("scenario", "label", "priorities", "status", grep("^Z[0-9]+$", names(s$runs), value = TRUE),
                 "delta_x", "delta_x_pct", paste0("delta_", acc), "state")], row.names = FALSE)
cat("\n================ Every account in every run: goal and achieved ================\n")
print(s$goals[, c("scenario", "label", "account", "direction", "base", "g", "Gx", "delta", "realized", "at_goal")],
      row.names = FALSE)
cat("\n================ Distinct states (runs whose x* differ by at most 1e-6) ================\n")
print(s$states, row.names = FALSE)
cat("", paste("Every result is in", out_dir),
    "  results.xlsx  the Excel workbook (start with the sheet about):",
    "    final_<scenario>        xD1-xD3 and f'1-f'72 at the last level, every ordering side by side",
    "    <scenario>_<ordering>   every stage (level 1 to 4) of one run, side by side",
    "    Gx_<scenario>, x_<scenario>, runs, levels, goals, states",
    "  README.md     the report; the CSV tables hold the same numbers", "", sep = "\n")

# ------------------------------------------------------------------------------
# Step 6. The numbers published in the thesis
# ------------------------------------------------------------------------------
# The fuels numbers of chapter 5: the largest share of the shock realized by
# CR and, at that frontier, the co-movement of CNR, the change in output
# (delta x) and in jobs; the state where CNR is exactly at its goal in the
# CNR scenario; the number of distinct states. They come from the six
# orderings.
if (is.null(my_orderings)) {
  ind <- thesis_indicators(res, entrant = "CR", incumbent = "CNR", labor = "LAB",
                           entrant_scenario = "CR", incumbent_scenario = "CNR")
  cmp <- compare_thesis(list(fuels = ind))
  cmp <- cmp[cmp$market == "fuels", ]
  cat("\n================ Published x reconstructed (fuels) ================\n")
  print(cmp[, c("item", "published", "reconstructed", "rounded", "match")], row.names = FALSE, digits = 10)
  cat(sprintf("%d of %d published numbers match.\n", sum(cmp$match), nrow(cmp)))
  if (!all(cmp$match)) stop("some published number does not match")
}
