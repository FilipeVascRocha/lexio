# Write the results

Writes the results of
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
to an organized folder:

## Usage

``` r
write_outputs(
  res,
  dir,
  format = c("intl", "br"),
  overwrite = FALSE,
  excel = TRUE
)
```

## Arguments

- res:

  Object of class `lexio_results`.

- dir:

  Destination folder. If it exists and is not empty, `overwrite = TRUE`
  is needed.

- format:

  `"intl"` (default: `,` and `.`) or `"br"` (`;` and `,`, for
  spreadsheets with a comma as decimal mark) for the tables.

- overwrite:

  Allows writing into a folder that already has files.

- excel:

  If `TRUE` (default), also writes `results.xlsx` with
  [`write_excel()`](https://filipevascrocha.github.io/lexio/reference/write_excel.md).

## Value

`dir`, invisibly.

## Details

    <dir>/
      README.md            readable report (model, corridor, tables per scenario, states, warnings)
      results.xlsx         the Excel workbook of write_excel(): every table below, the final
                           results of all orderings side by side and one sheet per run
      orderings.csv        one row per scenario x ordering: priorities, GLPK status, lock used,
                           Z of each level, delta_x and the change of each account, state
      levels.csv           one row per scenario x ordering x priority level (each stage of each
                           run): its goals, optimum Z, GLPK status
      level_results.csv    every run, every level, every row of G: g, Gx, d_minus, d_plus and,
                           in the ECO rows, the output x of the level (all level_<l>.csv in one table)
      account_goals.csv    scenario x ordering x account: base, goal g, achieved Gx, delta,
                           realized share of the intended change, deviation, state
      x_star_all_runs.csv  one row per sector: x0 and the final output x_star of every run
      states.csv           distinct states and the runs of each one
      runs/<scenario>/<label>_<priorities>/
                           all_levels.csv (every row of G, all levels side by side),
                           level_<l>.csv (g, Gx, d_minus, d_plus and x of one level)
                           and x_star.csv (x0, x_star and delta_x per sector)
      inputs/              the model.yml used and the SHA-256 of the database files
      results.rds          the full object
      session.txt          versions of R, of the packages and of GLPK
