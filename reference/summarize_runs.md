# Summarize the runs

Summarizes the solutions of the last level of each run (scenario x
ordering), for any number of satellite accounts and priority levels. No
plots are produced.

## Usage

``` r
summarize_runs(runs, tol = 1e-06, goal_tol = 1e-09)
```

## Arguments

- runs:

  A `lexio_results` object
  ([`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md))
  or a list of `gp_run` objects
  ([`run_experiment()`](https://filipevascrocha.github.io/lexio/reference/run_experiment.md))
  of the same model.

- tol:

  Tolerance (absolute, max norm on `x_star`) to group states.

- goal_tol:

  Relative tolerance to call an account "at goal".

## Value

List with `runs` (one row per run; `infeasible_level` is the first level
without solution, `NA` if none), `levels` (one row per run x priority
level: its goals, optimum `Z`, GLPK status and the violation of its
constraints by the solution, see
[`run_experiment()`](https://filipevascrocha.github.io/lexio/reference/run_experiment.md)),
`goals` (run x account) and `states` (one row per distinct state).

## Details

For each run, with `x0` the base output and `b = D x0` the base of each
account:

- `delta_x = sum(x_star) - sum(x0)` and
  `delta_x_pct = delta_x / sum(x0)`;

- for each account: achieved `Gx`, `delta = Gx - b`, intended change
  `g - b` and realized share `(Gx - b) / (g - b)`; the share is `NA`
  when the intended change is negligible (`|g - b| <= 1e-9 max(1, |b|)`,
  a goal equal to the base up to rounding);

- distinct states: single-linkage grouping of the solutions `x_star` of
  all runs; two solutions are in the same state when
  `max |x_star_a - x_star_b| <= tol` (1e-6 by default). A run with a
  level that has no solution has no state (`NA`).
