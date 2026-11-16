# Run one ordering of one scenario

Builds the goals of the scenario, the problem `Gx + d- - d+ = g` with
the corridor declared with the data (if any, and if the scenario uses
it), and solves the lexicographic goal program in the requested priority
ordering. To run every ordering of every scenario at once, use
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md).

## Usage

``` r
run_experiment(
  io,
  model,
  scenario = 1,
  ordering = 1,
  strict = TRUE,
  keep_lp = FALSE,
  lock_tolerance = NULL
)
```

## Arguments

- io:

  Object of class `lexio_io`
  ([`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md),
  [`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md)).

- model:

  Object of class `lexio_model`
  ([`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md),
  [`read_model()`](https://filipevascrocha.github.io/lexio/reference/read_model.md)).

- scenario:

  Name or number of the scenario.

- ordering:

  Number or label of an ordering of the model, or an ad hoc ordering (a
  character vector with one goal per level, or a list of levels; see
  `priorities` in
  [`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)).

- strict:

  If `TRUE` (default), stops with an error when a level does not end
  optimal (`GLP_OPT`) or a check fails (relative tolerance 1e-8). With
  `FALSE`, returns the run and records the problem in `ok`, `status` and
  `checks`.

- keep_lp:

  If `TRUE`, keeps the ROI `OP` object of each level.

- lock_tolerance:

  Lock of the levels already solved (default: the one of the model; see
  [`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)).
  `0` or `"exact"` is the exact lock `d_l == Z_l`.

## Value

Object of class `gp_run`: scenario, ordering (`ordering` = its number,
`label`, `order` = the names of the levels); `g`; the corridor used
(`floor`, `ceiling`); the levels (`levels`: GLPK status, `objval`, `x`,
`d_plus`, `d_minus`, `gx`, `violation`); `Z`; the solution of the last
level (`x_star`, `d_minus`, `d_plus`, `gx`); the checks (`checks`);
`status`, `optimal`, `ok`; `violation` (one value per level) and
`infeasible_level` (the first level without solution, `NA` if none); the
lock tolerance used (`lock_tolerance`, 0 = exact) and the status with
the exact lock (`status_exact`); the base (`baseline`) and metadata
(`meta`).

## Details

When GLPK does not end a level as optimal, the solution it returns is
checked against the constraints of the level (`violation`: the largest
violation, each row relative to `max(1, |rhs|)`). If the constraints
hold (violation up to 1e-4), the flag of GLPK is a numerical false
infeasibility: the numbers are kept and the run is flagged as not
optimal. If they do not hold, the level has no solution: that level and
the following ones are left blank (`NA`), and `infeasible_level` says
where it starts.

## Examples

``` r
io <- example_io()
m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
run_experiment(io, m, scenario = "E_shock", ordering = 1)
#> <gp_run> toy | scenario E_shock | P01 : E > I > LAB > ECO 
#>   level 1 E            GLP_OPT    Z = 0.781324
#>   level 2 I            GLP_OPT    Z = 4.31383
#>   level 3 LAB          GLP_OPT    Z = 0
#>   level 4 ECO          GLP_OPT    Z = 0
#>   accounts at the last level:
#>     E        >= base 6.6            goal 8.38           achieved 7.598676       d- 0.781324     d+ 0
#>     I        <= base 29             goal 29             achieved 33.31383       d- 0            d+ 4.31383
#>     LAB      >= base 260            goal 273            achieved 296.2871       d- 0            d+ 23.2871
#>   ECO: shortfall sum(d-) = 0, excess sum(d+) = 21.25 | delta x = 34.05912 (14.1913%)
#>   corridor: two-sided corridor | ok: TRUE 
```
