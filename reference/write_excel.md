# Write the results to an Excel workbook

Writes the results of
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
to one `.xlsx` workbook. In the result sheets, each row is a row of `G`:
first the satellite accounts, then the sectors (the economic block ECO).
The sheets are:

## Usage

``` r
write_excel(res, file, run_sheets = TRUE, overwrite = FALSE)
```

## Arguments

- res:

  Object of class `lexio_results`.

- file:

  Path of the `.xlsx` file.

- run_sheets:

  If `TRUE` (default), writes one sheet per run. With many runs (6
  accounts give 720 orderings per scenario), `FALSE` keeps the workbook
  small; the same tables are in the `all_levels.csv` files of
  [`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md).

- overwrite:

  Allows replacing an existing file.

## Value

`file`, invisibly.

## Details

- `about`: the model, the scenarios, the orderings, the accounts, the
  notation and what each sheet holds;

- `runs`, `levels`, `goals` and `states`: the tables of
  [`summarize_runs()`](https://filipevascrocha.github.io/lexio/reference/summarize_runs.md)
  (one row per run, per level of each run, per account of each run and
  per distinct state);

- for each scenario `<s>`:

  - `final_<s>`: the last level of every ordering, side by side: the
    goal `g` and, for each ordering, `Gx`, `d_minus`, `d_plus` and `x`;

  - `Gx_<s>`: `g`, the `Gx` of each ordering and `Gx - g`;

  - `x_<s>`: the base output `x0`, the output `x_star` of each ordering
    and `delta_x = x_star - x0`;

- for each run, `<s>_<ordering>`: every row of `G` at every priority
  level, side by side: `g`, then `Gx`, `d_minus`, `d_plus` and `x` of
  level 1 to the last (the table `all_levels.csv` of
  [`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md)).

The rows are identified by `row` (the account name or the sector code),
`notation` and `name`. In the notation, `xD_j` is `D_j x`, the level of
account `j`, and `f'_h` is row `h` of `(I - A) x`, the net output of
sector `h`, whose goal is the final demand `f_h`. The column `x` is
empty in the account rows.

Sheet names are limited to 31 characters by Excel; longer names are
shortened.

## Examples

``` r
res <- run_model(system.file("examples", "toy", "model.yml", package = "lexio"), verbose = FALSE)
file <- write_excel(res, tempfile(fileext = ".xlsx"))
```
