# lexio 1.0.0

First public release.

* `declare_io()` declares an input-output database from objects already in R:
  the technical structure (`Z`, `A` or `B`), gross output, final demand, any
  number of satellite accounts (levels `E` or coefficients `D`) and,
  optionally, a corridor on the economic deviations (`corridor`, or `floor`
  and `ceiling`). `read_io()` reads the same database from CSV files
  (including those saved by Excel as "CSV UTF-8") or an `.xlsx` workbook;
  `write_io()`, `validate_io()`, `example_io()` and `lexio_template()`
  complete the set.
* `define_model()` and `read_model()` declare the direction and goal of each
  account (`base`, `growth`, `pooled_share`, `delta`, `level`), the economic
  block (fixed at the last level unless declared free; absolute or relative
  deviations), the scenarios, the corridor and the priorities: all `k!`
  orderings, permutations of groups, or explicit orderings with several
  weighted goals per level.
* `run_model()` runs every ordering of every scenario; `run_experiment()` runs
  one. Each priority level is a linear program solved with GLPK, with the
  optima of the earlier levels locked. `lock_tolerance = "auto"` solves again,
  with a slightly relaxed lock, only the runs where GLPK reports a level as
  not optimal, and flags them. A level that GLPK does not certify is checked
  against its constraints: if they hold, the numbers are kept and the run is
  flagged; if not, the level has no solution, and it and the following
  levels are left blank.
* `write_outputs()` writes a report, CSV tables of every level of every run
  and an Excel workbook; `write_excel()` writes the workbook alone.
* Vignettes: getting started, declaring data and models, the goal programming
  example of Miller and Blair, and the replication of the thesis. Portuguese
  translations are on the package website.
