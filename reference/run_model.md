# Run the model

Runs every priority ordering of every scenario of the model. With the
default `priorities = "all"` and k satellite accounts, there are `k!`
orderings per scenario, with ECO last. The number of sectors and of
accounts comes from the database.

## Usage

``` r
run_model(
  io,
  model = NULL,
  scenarios = NULL,
  orderings = NULL,
  strict = FALSE,
  verbose = interactive(),
  lock_tolerance = NULL
)
```

## Arguments

- io:

  Path of a `model.yml`, or a `lexio_io` object.

- model:

  A `lexio_model` object (when `io` is the database).

- scenarios:

  Scenarios to run (names; default: all).

- orderings:

  Orderings to run (numbers or labels; default: all of the model).

- strict:

  If `TRUE`, stops at the first non-optimal level. With `FALSE`
  (default), runs everything and records the status of each level, shown
  in the summary and in the report.

- verbose:

  Show progress.

- lock_tolerance:

  Replaces the `lock_tolerance` of the model (see
  [`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md));
  `NULL` (default) uses the one of the model.

## Value

Object of class `lexio_results`: the model, the database, the runs
(`runs`, one per scenario x ordering), the summary
([`summarize_runs()`](https://filipevascrocha.github.io/lexio/reference/summarize_runs.md))
and metadata. Use
[`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md)
to write everything to a folder.

## Details

The simplest call passes the path of a `model.yml`: the model says where
the database is (`data`). The database and the model can also be passed
as objects
([`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md),
[`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)).

## Examples

``` r
res <- run_model(system.file("examples", "toy", "model.yml", package = "lexio"), verbose = FALSE)
res
#> <lexio_results> toy | 3 sectors | 3 account(s): E, I, LAB | corridor: two-sided corridor 
#>   scenario E_shock        6 ordering(s) | all optimal | 3 distinct state(s)
#>   scenario I_shock        6 ordering(s) | all optimal | 1 distinct state(s)
#>   distinct states in total: 4 
#>   write everything with write_outputs(res, "folder")
head(res$summary$runs)
#>   scenario ordering label        priorities status
#> 1  E_shock        1   P01 E > I > LAB > ECO   0000
#> 2  E_shock        2   P02 E > LAB > I > ECO   0000
#> 3  E_shock        3   P03 I > E > LAB > ECO   0000
#> 4  E_shock        4   P04 I > LAB > E > ECO   0000
#> 5  E_shock        5   P05 LAB > E > I > ECO   0000
#> 6  E_shock        6   P06 LAB > I > E > ECO   0000
#>                       status_glpk optimal   ok infeasible_level lock_tolerance
#> 1 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#> 2 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#> 3 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#> 4 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#> 5 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#> 6 GLP_OPT GLP_OPT GLP_OPT GLP_OPT    TRUE TRUE               NA              0
#>             corridor       Z1       Z2        Z3        Z4   delta_x
#> 1 two-sided corridor 0.781324 4.313833  0.000000  0.000000 34.059116
#> 2 two-sided corridor 0.781324 0.000000  4.313833  0.000000 34.059116
#> 3 two-sided corridor 0.000000 1.728185 30.048715 12.850000 -8.273668
#> 4 two-sided corridor 0.000000 0.000000  1.804074  3.278086  5.537037
#> 5 two-sided corridor 0.000000 0.781324  4.313833  0.000000 34.059116
#> 6 two-sided corridor 0.000000 0.000000  1.804074  3.278086  5.537037
#>   delta_x_pct     delta_E       delta_I delta_LAB state
#> 1  0.14191298  0.99867602  4.313833e+00  36.28710     1
#> 2  0.14191298  0.99867602  4.313833e+00  36.28710     1
#> 3 -0.03447362  0.05181527 -3.552714e-15 -17.04871     2
#> 4  0.02307099 -0.02407407 -3.552714e-15  13.00000     3
#> 5  0.14191298  0.99867602  4.313833e+00  36.28710     1
#> 6  0.02307099 -0.02407407 -3.552714e-15  13.00000     3
```
