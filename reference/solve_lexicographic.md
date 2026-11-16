# Solve the lexicographic program

Solves the preemptive goal program level by level (Rocha, 2026, section
4.4.1): level `l` minimizes the weighted sum of the penalized deviations
of its goals, with the levels already solved locked at their optima
(`d_j == Z_j`, `j < l`). Works for any number of levels and any number
of goals per level.

## Usage

``` r
solve_lexicographic(lp, priorities, keep_lp = FALSE, lock_tolerance = 0)
```

## Arguments

- lp:

  Object of class `lexio_lp` from
  [`build_lp()`](https://filipevascrocha.github.io/lexio/reference/build_lp.md).

- priorities:

  List of levels, in priority order. Each level is a list with `name`
  and either `terms` (a list of goals, each with `rows` of `G`, `type`
  (`"minus"`, `"plus"` or `"both"`, see
  [`direction_type()`](https://filipevascrocha.github.io/lexio/reference/direction_type.md))
  and `weight`) or, for a level with a single goal of weight 1, `rows`
  and `type`.

- keep_lp:

  If `TRUE`, keeps the ROI `OP` object of each level.

- lock_tolerance:

  `0` (default): exact lock `d_l == Z_l`. `t > 0`: relaxed lock
  `d_l <= Z_l + t * max(1, |Z_l|)` (see `lock_tolerance` in
  [`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)).

## Value

List with `levels` (one element per level: GLPK status, `objval`, `x`,
`d_plus`, `d_minus`, `gx = G x` and `violation`, the largest violation
of the constraints of the level by that solution, see
[`run_experiment()`](https://filipevascrocha.github.io/lexio/reference/run_experiment.md)),
`Z` (the optima of the levels), `checks` (data frame) and
`lock_tolerance`.

## Details

Each LP is solved with `ROI::ROI_solve(op, solver = "glpk")` and the
default solver options. After each run two checks are applied: the
optimum of each level equals the sum of its penalized deviations, and
every earlier level stays at its optimum.
