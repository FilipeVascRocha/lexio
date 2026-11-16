# Build the goal programming problem

Builds the constraints shared by every priority level,

## Usage

``` r
build_lp(inputs, g, floor = NULL, ceiling = NULL)
```

## Arguments

- inputs:

  List with `D` (k x n account coefficients) and `B` (`I - A`), for
  instance a `lexio_io` object.

- g:

  Goal vector (`k + n`), for instance from
  [`build_goals()`](https://filipevascrocha.github.io/lexio/reference/build_goals.md).

- floor, ceiling:

  Corridor proportions (n, `NA` = no bound) or `NULL`.

## Value

Object of class `lexio_lp`: a list with `G`, the constraint matrix `A`,
`dir`, `rhs`, `bounds` (ROI `V_bound`) and the indices `idx_x`,
`idx_d_plus`, `idx_d_min`.

## Details

\$\$G x + d^- - d^+ = g, \qquad G = \begin{bmatrix} D \\ I - A
\end{bmatrix},\$\$

with the decision variables in the order
`x_1..x_n, d_1^+..d_m^+, d_1^-..d_m^-` (all `>= 0`, `m = k + n`), and,
when declared, the corridor on the economic goals (the rows of `I - A`):
`d_h^- <= alpha_h^floor |g_h|` and `d_h^+ <= alpha_h^ceiling |g_h|`
(Rocha, 2026, eq. 4.38). A side that is `NULL` or `NA` in a sector has
no bound there; with both sides `NULL` the model is free. Satellite rows
never have a corridor.

The rows of the constraint matrix are, in this order: the `m` goals,
then, for each economic row, the bound on `d^-` and the bound on `d^+`.
The locks of the levels already solved are added by
[`solve_lexicographic()`](https://filipevascrocha.github.io/lexio/reference/solve_lexicographic.md).
