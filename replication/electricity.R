# The model of the thesis, step by step: the ELECTRICITY market.
#
# Distributed generation (GD, the entrant) against centralized generation
# (GC, the incumbent), with labour (LAB), on the input-output matrix of Brazil
# with energy-sector detail (EPE/FIPE, 72 sectors, base year 2018). Read the
# script from top to bottom: every object of the model is declared here, in R
# code. fuels.R does the same for the fuels market, and 02_reproduce.R runs
# both markets with every check.
#
# Notation of the thesis (section 4.2) and names in lexio:
#   x     gross output (n)                          declare_io(x = )
#   f     final demand (n)                          declare_io(f = )
#   B     I - A, A = technical coefficients         declare_io(B = )
#   D     account coefficients (account per unit of output)  declare_io(D = list(...))
#   alpha corridor, a proportion of |g_h|           declare_io(corridor = )
#   G, g  G = [D; B] and the goals g = (g_D, f)     build_goals()
#   P_l   priority level l                          define_model(priorities = )
#   ECO   the economic block (the rows of B)        always the last level
#
# Output: every result, in a new folder (nothing is overwritten):
# replication/outputs_electricity, then _2, _3, ... The console shows every
# run level by level, the summary tables and the published numbers.
#
# Usage, from the root of the repository:
#   RStudio: open lexio.Rproj, open this file and click Source (or run it line
#            by line with Ctrl+Enter);
#   terminal: Rscript replication/electricity.R

library(lexio)
replication_dir <- file.path(here::here(), "replication")
source(file.path(replication_dir, "R", "thesis_helpers.R"))
if (!interactive()) options(width = 200)
out_dir <- new_output_dir(file.path(replication_dir, "outputs_electricity"))

# ------------------------------------------------------------------------------
# Step 0. Where the data are
# ------------------------------------------------------------------------------
# replication/thesis_data/ holds the database of the thesis in the lexio
# format: the attachment lexio-thesis-data-2018.zip of the GitHub release
# (downloaded here if the folder is missing), or the output of
# 01_declare_data.R, which builds it from the public workbook of EPE.
data_dir <- file.path(thesis_data_dir(replication_dir), "electricity", "coefficients")

# ------------------------------------------------------------------------------
# Step 1. The data, as vectors in the R session
# ------------------------------------------------------------------------------
# coefficients/ has one CSV file per object, one row per sector (the code of
# the sector in the first column):
#   sectors.csv   code, name          the 72 sectors and their order
#   B.csv         code + 72 columns   B = I - A
#   x.csv         code, value         gross output x, R$ million
#   f.csv         code, value         final demand f, R$ million
#   D.csv         code, GD, GC, LAB   coefficients: toe (GD, GC) and jobs (LAB) per R$ million of output
#   corridor.csv  code, alpha         corridor: intersectoral purchases of electricity / x
# These are the coefficients of the published flows (thesis_data/electricity/
# base/: Z and the levels E), rounded to 15 significant digits as in the
# computations of the thesis. The flows can be declared directly instead, with
# declare_io(Z = Z, E = list(GD = E_GD, ...)); the package then computes A, B
# and D (see 01_declare_data.R).
read_table <- function(name) {
  utils::read.csv(file.path(data_dir, paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE,
                  colClasses = c(code = "character"), encoding = "UTF-8")
}
sectors <- read_table("sectors")          # code and name of the 72 sectors
B <- as.matrix(read_table("B")[, -1])     # I - A (the first column is the code)
x <- read_table("x")$value                # gross output
f <- read_table("f")$value                # final demand
D <- read_table("D")
D_GD <- D$GD                              # electricity from distributed generation, toe per R$ million
D_GC <- D$GC                              # electricity from centralized generation, toe per R$ million
D_LAB <- D$LAB                            # jobs per R$ million
alpha <- read_table("corridor")$alpha     # corridor

# ------------------------------------------------------------------------------
# Step 2. Declare the database
# ------------------------------------------------------------------------------
# Each argument says what the object is: B = I - A, x = gross output,
# f = final demand, D = the coefficients of the satellite accounts (a named
# list: the names are the names of the accounts). corridor = alpha bounds both
# deviations of each economic goal, d_h^- <= alpha_h |g_h| and
# d_h^+ <= alpha_h |g_h|; without it the model would be free.
io <- declare_io(B = B, x = x, f = f,
                 D = list(GD = D_GD, GC = D_GC, LAB = D_LAB),
                 corridor = alpha,
                 sectors = sectors)
print(io)            # the base of each account, b_j = D_j x

# ------------------------------------------------------------------------------
# Step 3. Declare the model
# ------------------------------------------------------------------------------
# Direction of each goal: ">=" is a floor (penalizes the shortfall d-), "<="
# a ceiling (penalizes the excess d+).
#   GD   entrant,    ">=": should not fall below its goal
#   GC   incumbent,  "<=": should not exceed its goal
#   LAB  labour,     ">=": grows by the share of the shock (1%)
# The goal of each account is its total level in the scenario (base + shock),
# not the shock alone. The shock is 1% of the pooled base of GD and GC:
#   scenario GD: g_GD = b_GD + 0.01 (b_GD + b_GC), g_GC = b_GC
#   scenario GC: g_GC = b_GC + 0.01 (b_GD + b_GC), g_GD = b_GD
#   both:        g_LAB = b_LAB x 1.01
#
# Priority orderings. With my_orderings <- NULL, every ordering of the three
# accounts is run: 3! = 6, P01..P06 (P1..P6 in the thesis). To run only some
# orderings, list them, for instance
#   my_orderings <- list(c("GC", "GD", "LAB"))
# ECO is always the last level.
share <- 0.01
shock <- list(type = "pooled_share", share = share, pool = c("GD", "GC"))
my_orderings <- NULL
model <- define_model(
  accounts = list(
    GD = list(direction = ">=", target = list(type = "base"), unit = "toe",
              label = "Electricity, distributed generation"),
    GC = list(direction = "<=", target = list(type = "base"), unit = "toe",
              label = "Electricity, centralized generation"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = share), unit = "jobs",
               label = "Labour (jobs)")
  ),
  # ECO: (I - A) x >= f, one goal per sector, at the last level, absolute deviations
  economy = list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute"),
  scenarios = list(GD = list(GD = shock),    # the shock goes to the entrant
                   GC = list(GC = shock)),   # the shock goes to the incumbent
  priorities = if (is.null(my_orderings)) "all" else my_orderings,
  # the corridor declared with the data, at its declared width (multiplier = 2 doubles it)
  corridor = list(use = TRUE, multiplier = 1),
  # exact lock of the levels already solved, d_l == Z_l
  lock_tolerance = "exact",
  name = "thesis_electricity"
)
print(model)

# The goals, from the bases: account, base, shock and total goal in each scenario
base <- satellite_base(io)
goals <- data.frame(account = names(base), base = base,
                    goal_GD = build_goals(io, model, "GD")[1:3],
                    goal_GC = build_goals(io, model, "GC")[1:3], row.names = NULL)
goals$change_GD <- goals$goal_GD - goals$base
goals$change_GC <- goals$goal_GC - goals$base
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
# The electricity numbers of chapter 5: the largest share of the shock
# realized by GD, the co-movement of GC at that frontier and the number of
# distinct states. They come from the six orderings.
if (is.null(my_orderings)) {
  ind <- thesis_indicators(res, entrant = "GD", incumbent = "GC", labor = "LAB",
                           entrant_scenario = "GD", incumbent_scenario = "GC")
  cmp <- compare_thesis(list(electricity = ind))
  cmp <- cmp[cmp$market == "electricity", ]
  cat("\n================ Published x reconstructed (electricity) ================\n")
  print(cmp[, c("item", "published", "reconstructed", "rounded", "match")], row.names = FALSE, digits = 10)
  cat(sprintf("%d of %d published numbers match.\n", sum(cmp$match), nrow(cmp)))
  if (!all(cmp$match)) stop("some published number does not match")
}
