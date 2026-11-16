# Changelog

## lexio 1.0.1

- The package and the database of the thesis are archived on Zenodo,
  with DOIs: the package, all versions, 10.5281/zenodo.24293765; the
  database, 10.5281/zenodo.24293808. They are now in
  `citation("lexio")`, `CITATION.cff` and the README.
- Replication: when `replication/thesis_data` is missing, the scripts
  download the database from the GitHub release and, if that fails, from
  its Zenodo record; the SHA-256 of the file is checked in both cases.

## lexio 1.0.0

First public release.

- [`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
  declares an input-output database from objects already in R: the
  technical structure (`Z`, `A` or `B`), gross output, final demand, any
  number of satellite accounts (levels `E` or coefficients `D`) and,
  optionally, a corridor on the economic deviations (`corridor`, or
  `floor` and `ceiling`).
  [`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md)
  reads the same database from CSV files (including those saved by Excel
  as “CSV UTF-8”) or an `.xlsx` workbook;
  [`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md),
  [`validate_io()`](https://filipevascrocha.github.io/lexio/reference/validate_io.md),
  [`example_io()`](https://filipevascrocha.github.io/lexio/reference/example_io.md)
  and
  [`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md)
  complete the set.
- [`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)
  and
  [`read_model()`](https://filipevascrocha.github.io/lexio/reference/read_model.md)
  declare the direction and goal of each account (`base`, `growth`,
  `pooled_share`, `delta`, `level`), the economic block (fixed at the
  last level unless declared free; absolute or relative deviations), the
  scenarios, the corridor and the priorities: all `k!` orderings,
  permutations of groups, or explicit orderings with several weighted
  goals per level.
- [`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
  runs every ordering of every scenario;
  [`run_experiment()`](https://filipevascrocha.github.io/lexio/reference/run_experiment.md)
  runs one. Each priority level is a linear program solved with GLPK,
  with the optima of the earlier levels locked.
  `lock_tolerance = "auto"` solves again, with a slightly relaxed lock,
  only the runs where GLPK reports a level as not optimal, and flags
  them. A level that GLPK does not certify is checked against its
  constraints: if they hold, the numbers are kept and the run is
  flagged; if not, the level has no solution, and it and the following
  levels are left blank.
- [`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md)
  writes a report, CSV tables of every level of every run and an Excel
  workbook;
  [`write_excel()`](https://filipevascrocha.github.io/lexio/reference/write_excel.md)
  writes the workbook alone.
- Vignettes: getting started, declaring data and models, the goal
  programming example of Miller and Blair, and the replication of the
  thesis. Portuguese translations are on the package website.
