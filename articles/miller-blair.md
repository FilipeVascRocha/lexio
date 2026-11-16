# The Miller and Blair example

Miller and Blair (2022, section 13.8) illustrate goal programming in an
input-output model with a two-sector economy and five satellite
accounts, the economy of their Example 13.7. The second edition has the
same example, with the same data and printed solutions (2009, section
10.4, Example 10.1). This vignette runs it with `lexio`. It is a free
model (no corridor) with several goals per level and the economic goals
at the second level.

**The first priority structure of the book does not reproduce the
printed solution.** For its first structure (eq. 13.17, p. 645; eq.
10.15, p. 465, in 2009) the book prints `x = (21.25, 49.375)`. The
lexicographic optimum, which `lexio` finds, is `x* = (32, 44)`. Section
4 shows why. The second structure (p. 648; p. 469 in 2009; unnumbered in
both editions) agrees with the book: `x* = (10, 10)`.

## 1. The data

The flows `Z`, the gross output `x` and the final demand `f` give
`A = [0.3 0.2; 0.1 0.7]`. The book gives the satellite accounts per unit
of output, so they are declared as coefficients, with `D =`. No corridor
is declared, so the model is free.

``` r

library(lexio)

Z <- matrix(c(3, 2,
              1, 7), nrow = 2, byrow = TRUE)
x <- c(10, 10)
f <- c(5, 2)
io <- declare_io(Z = Z, x = x, f = f,
                 D = list(OIL = c(0.2, 0.3), COAL = c(0.1, 0.4), SO2 = c(0.5, 1.1),
                          HC = c(0.7, 0.7), EMP = c(0.1, 0.2)),
                 sectors = data.frame(code = c("I1", "I2"), name = c("Industry 1", "Industry 2")))
io
#> <lexio_io> 2 sectors, 5 satellite account(s): OIL, COAL, SO2, HC, EMP | declared as Z + D | corridor: free 
#>   base OIL = D x =  5.00
#>   base COAL = D x =  5.00
#>   base SO2 = D x = 16.00
#>   base HC = D x = 14.00
#>   base EMP = D x =  3.00
```

## 2. Goals and priorities

The goals are levels. Oil and coal use should not exceed 20, SO2
emissions 16 and HC emissions 20 (ceilings, penalizing `d⁺_1` to
`d⁺_4`); employment should reach 12 (a floor, penalizing `d⁻_5`). The
economic goals are `(I − A) x ≥ f' = (5, 10)` (penalizing `d⁻_6` and
`d⁻_7`), declared as the target of the economic block.

The book puts the economic goals at the second level. In `lexio` the
economic block is fixed at the last level unless the model declares
otherwise; `position = "free"` is that declaration.

``` r

level <- function(v) list(type = "level", value = v)
accounts <- list(
  OIL  = list(direction = "<=", target = level(20)),
  COAL = list(direction = "<=", target = level(20)),
  SO2  = list(direction = "<=", target = level(16)),
  HC   = list(direction = "<=", target = level(20)),
  EMP  = list(direction = ">=", target = level(12))
)
model <- define_model(
  accounts = accounts,
  economy = list(direction = ">=", target = c(5, 10), position = "free"),
  priorities = list(
    # eq. 13.17 (2022, p. 645): P1 d5-, P2 d6- + d7-, P3 d1+ + d2+, P4 d3+ + d4+
    book_1 = list("EMP", "ECO", c("OIL", "COAL"), c("SO2", "HC")),
    # 2022, p. 648 (no number): P1 d3+, P2 d6- + d7-, P3 d1+ + d2+, P4 d4+, P5 d5-
    book_2 = list("SO2", "ECO", c("OIL", "COAL"), "HC", "EMP"),
    # the first structure, one goal at a time, as in the figures of the book
    one_at_a_time = list("EMP", "ECO", "OIL", "COAL", "SO2", "HC")
  ),
  name = "miller_blair"
)
model
#> <lexio_model> miller_blair | 5 satellite account(s), 1 scenario(s), 3 priority ordering(s) | lock: auto (exact; relaxed only where GLPK fails) 
#>   OIL      <= level 20
#>   COAL     <= level 20
#>   SO2      <= level 16
#>   HC       <= level 20
#>   EMP      >= level 12
#>   ECO      >= declared goals | absolute deviations | position free (declared by the operator)
#>   corridor: as declared in the data (multiplier 1) 
#>   book_1: EMP > ECO > OIL + COAL > SO2 + HC
#>   book_2: SO2 > ECO > OIL + COAL > HC > EMP
#>   one_at_a_time: EMP > ECO > OIL > COAL > SO2 > HC
#>   scenario main
```

The same model is in
`system.file("examples", "miller_blair", "model.yml", package = "lexio")`,
without the third ordering.

## 3. Every stage of every run

``` r

res <- run_model(io, model, verbose = FALSE)
res
#> <lexio_results> miller_blair | 2 sectors | 5 account(s): OIL, COAL, SO2, HC, EMP | corridor: free 
#>   scenario main           3 ordering(s) | all optimal | 2 distinct state(s)
#>   distinct states in total: 2 
#>   write everything with write_outputs(res, "folder")
```

The table below shows, for each level of each run, its goals, its
optimum `Z`, the GLPK status, the output `x` after the level and the
value `G x` of every goal.

``` r

stages <- function(r) {
  do.call(rbind, lapply(seq_along(r$levels), function(l) {
    lev <- r$levels[[l]]
    gx <- stats::setNames(round(lev$gx, 4), c(names(accounts), "ECO_1", "ECO_2"))
    data.frame(level = l, goals = r$order[l], Z = round(lev$objval, 4), status = lev$status_symbol,
               x1 = round(lev$x[1], 4), x2 = round(lev$x[2], 4), as.list(gx), check.names = FALSE)
  }))
}
for (r in res$runs) {
  cat("\n", r$label, ": ", paste(r$order, collapse = " > "), "\n", sep = "")
  print(stages(r), row.names = FALSE)
}
#> 
#> book_1: EMP > ECO > OIL+COAL > SO2+HC
#>  level    goals    Z  status    x1     x2     OIL   COAL     SO2      HC EMP ECO_1   ECO_2
#>      1      EMP  0.0 GLP_OPT  0.00 60.000 18.0000 24.000 66.0000 42.0000  12 -12.0 18.0000
#>      2      ECO  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      3 OIL+COAL  0.8 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      4   SO2+HC 81.6 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#> 
#> book_2: SO2 > ECO > OIL+COAL > HC > EMP
#>  level    goals Z  status x1      x2    OIL   COAL SO2      HC    EMP   ECO_1  ECO_2
#>      1      SO2 0 GLP_OPT  0 14.5455 4.3636 5.8182  16 10.1818 2.9091 -2.9091 4.3636
#>      2      ECO 8 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      3 OIL+COAL 0 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      4       HC 0 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      5      EMP 9 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#> 
#> one_at_a_time: EMP > ECO > OIL > COAL > SO2 > HC
#>  level goals    Z  status    x1     x2     OIL   COAL     SO2      HC EMP ECO_1   ECO_2
#>      1   EMP  0.0 GLP_OPT  0.00 60.000 18.0000 24.000 66.0000 42.0000  12 -12.0 18.0000
#>      2   ECO  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      3   OIL  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      4  COAL  0.8 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      5   SO2 48.4 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      6    HC 33.2 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
```

## 4. The book and lexio, side by side

The value of a priority level at a given output `x` is the sum of the
penalized deviations of its goals. The function below computes it at any
point, so the point printed in the book and the solution of `lexio` can
be compared level by level.

``` r

level_values <- function(x, levels) {
  g <- build_goals(io, model)
  Gx <- as.numeric(rbind(io$D, io$B) %*% x)
  d_plus <- pmax(Gx - g, 0)
  d_minus <- pmax(g - Gx, 0)
  eco <- length(accounts) + seq_len(io$n)
  vapply(levels, function(goals) {
    sum(vapply(goals, function(a) {
      if (a == "ECO") return(sum(d_minus[eco]))
      i <- match(a, names(accounts))
      if (accounts[[a]]$direction == "<=") d_plus[i] else d_minus[i]
    }, numeric(1)))
  }, numeric(1))
}
book <- list(book_1 = c(21.25, 49.375), book_2 = c(10, 10))
for (o in names(book)) {
  r <- res$runs[[match(o, vapply(res$runs, `[[`, character(1), "label"))]]
  cat("\n", o, ": the book prints x = (", paste(book[[o]], collapse = ", "), "); lexio gives x* = (",
      paste(round(r$x_star, 6), collapse = ", "), ")\n", sep = "")
  print(data.frame(level = seq_along(r$order), goals = r$order,
                   at_book_point = zapsmall(level_values(book[[o]], r$levels_goals), 10),
                   at_lexio_point = zapsmall(level_values(r$x_star, r$levels_goals), 10),
                   lexio_Z = zapsmall(r$Z, 10)), row.names = FALSE)
}
#> 
#> book_1: the book prints x = (21.25, 49.375); lexio gives x* = (32, 44)
#>  level    goals at_book_point at_lexio_point lexio_Z
#>      1      EMP         0.000            0.0     0.0
#>      2      ECO         0.000            0.0     0.0
#>      3 OIL+COAL         1.875            0.8     0.8
#>      4   SO2+HC        78.375           81.6    81.6
#> 
#> book_2: the book prints x = (10, 10); lexio gives x* = (10, 10)
#>  level    goals at_book_point at_lexio_point lexio_Z
#>      1      SO2             0              0       0
#>      2      ECO             8              8       8
#>      3 OIL+COAL             0              0       0
#>      4       HC             0              0       0
#>      5      EMP             9              9       9
```

In the second structure the two points coincide. In the first, both
points meet the first two levels exactly: employment is 12 and the
economic goals are met. After the second level, the solutions form the
segment of the employment line `x_2 = 60 − 0.5 x_1` between
`(21.25, 49.375)` and `(32, 44)`. Along that segment oil use stays below
20 and coal use is `24 − 0.1 x_1`, so the excess coal use
`d⁺_2 = 4 − 0.1 x_1`, which enters the third level, is smallest at
`(32, 44)`, where it is 0.8. The book prints the other end of the
segment, where it is 1.875.

The stages of `book_1` show the same thing: after level 2, GLPK stands
on the point printed in the book; level 3 then moves the solution along
the segment to `(32, 44)`, lowering the excess coal use from 1.875 to
0.8 without changing levels 1 and 2. Solving the goals one at a time
(`one_at_a_time`) also gives `(32, 44)`. The package tests check the
same optima with an independent implementation solved with lpSolve.

## 5. All the orderings, with the economic block last

Without a `priorities` declaration, `lexio` runs every ordering of the
accounts, one account per level, with the economic block fixed at the
last level: `5! = 120` orderings.

``` r

model_all <- define_model(accounts, economy = list(direction = ">=", target = c(5, 10)),
                          name = "miller_blair_all")
res_all <- run_model(io, model_all, verbose = FALSE)
res_all
#> <lexio_results> miller_blair_all | 2 sectors | 5 account(s): OIL, COAL, SO2, HC, EMP | corridor: free 
#>   scenario main         120 ordering(s) | all optimal | 6 distinct state(s)
#>   distinct states in total: 6 
#>   write everything with write_outputs(res, "folder")
res_all$summary$states[, c("state", "n_runs", "delta_x", paste0("delta_", names(accounts)))]
#>   state n_runs    delta_x delta_OIL delta_COAL delta_SO2 delta_HC delta_EMP
#> 1     1     40   8.571429  1.000000  -1.285714   0.00000      6.0 0.1428571
#> 2     2     20  12.000000  1.400000  -1.800000   0.00000      8.4 0.2000000
#> 3     3     20   8.571429  3.571429   6.428571  15.42857      6.0 2.7142857
#> 4     4     20  60.000000 15.000000  15.000000  48.00000     42.0 9.0000000
#> 5     5     10  40.000000 13.000000  19.000000  50.00000     28.0 9.0000000
#> 6     6     10 100.000000 19.000000   7.000000  44.00000     70.0 9.0000000
```

## 6. Notes on the 2022 edition

The example, the data and the printed solutions are the same as in 2009.
Checking with GLPK, we also found:

- typos: goals 13.14 to 13.16 are written as `≤ / minimize d⁺`, while
  the matrix and equation 13.17 use `≥ / d⁻` (p. 645); equation 13.9 has
  the sign `+d⁺_4` (p. 639);
- section 13.8 calls the example “Example 13.1”, its number in the 2009
  edition (10.1); in 2022 the data are those of Example 13.7 (section
  13.7.2), and Example 13.1 is another one (section 13.2.1);
- a new linear programming illustration (section 13.8.1), with SO2 ≤ 15:
  with employment ≥ 3 it is infeasible; without the employment row, the
  optimum is `(9.770, 9.195)`, with `q = 6.782`, not the printed
  `(8.846, 9.615)`, with `q = 6.269` (a point with employment 2.808).

## Reference

Miller, R. E. and Blair, P. D. (2022). *Input-Output Analysis:
Foundations and Extensions.* 3rd ed. Cambridge University Press, section
13.8. Previous edition: 2nd ed., 2009, section 10.4.
