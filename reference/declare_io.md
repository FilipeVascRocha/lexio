# Declare the database

Builds the database used by the model from objects the user already has:
the technical structure, gross output, final demand, the satellite
accounts and, optionally, a corridor. The package never parses free-form
spreadsheets and never searches a database for accounts or corridors:
the user states what each object is. The vectors may be objects already
in the R session; pass them by name.

## Usage

``` r
declare_io(
  Z = NULL,
  x,
  f,
  E = NULL,
  D = NULL,
  A = NULL,
  B = NULL,
  corridor = NULL,
  floor = NULL,
  ceiling = NULL,
  sectors = NULL
)
```

## Arguments

- Z, A, B:

  Technical structure (n x n): give exactly one.

- x:

  Gross output (n). Must be positive.

- f:

  Final demand (n): the default economic goals.

- E, D:

  Satellite accounts: give exactly one (see above).

- corridor, floor, ceiling:

  Corridor (n, proportions `alpha_h`): give `corridor`, or `floor`
  and/or `ceiling`, or none (free).

- sectors:

  Data frame with columns `code` and `name` (optional). Without it,
  codes come from the names of `x`, the column names of `Z`, or become
  `S01`, `S02`, ...

## Value

Object of class `lexio_io`.

## Details

Notation (Rocha, 2026, section 4.2): `Z` intermediate consumption, `x`
gross output (VBP), `f` final demand, `A = Z x^-1` technical
coefficients, `B = I - A`, `E_j` level of a satellite account in sector
j (toe, jobs, ...), `D = E x^-1` direct impact coefficients (one row per
account), `alpha_h` corridor of sector h.

- **Technical structure**: exactly one of `Z` (flows, then `A = Z / x`
  by column), `A` or `B`.

- **Satellite accounts**: exactly one of `E` (levels, then `D = E / x`)
  or `D` (coefficients). Each can be a named list of vectors (one per
  account), a data frame with one column per account, or a matrix
  (sectors x accounts for `E`; accounts x sectors for `D`, as in the
  notation above). The names are the account names.

- **Corridor** (optional), a vector of proportions `alpha_h` (one per
  sector) that bounds the deviations of the economic goals:
  `corridor = alpha` bounds both sides, `d_h^- <= alpha_h |g_h|` and
  `d_h^+ <= alpha_h |g_h|`; `floor = alpha` bounds only `d^-`
  (`G_h x >= g_h - alpha_h |g_h|`); `ceiling = alpha` bounds only `d^+`
  (`G_h x <= g_h + alpha_h |g_h|`). `floor` and `ceiling` can be given
  together, with different values. `NA` in a sector means no bound in
  that sector. With no corridor, the model is free (no bound on the
  economic deviations).

## See also

[`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md)
to read the same database from a folder of CSV files or an `.xlsx`
workbook,
[`validate_io()`](https://filipevascrocha.github.io/lexio/reference/validate_io.md),
[`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md).

## Examples

``` r
Z <- matrix(c(3, 1, 2, 7), 2)          # Miller and Blair (2022), Example 13.7
x <- c(10, 10)
io <- declare_io(Z = Z, x = x, f = x - rowSums(Z),
                 D = list(OIL = c(0.2, 0.3), EMP = c(0.1, 0.2)))
io
#> <lexio_io> 2 sectors, 2 satellite account(s): OIL, EMP | declared as Z + D | corridor: free 
#>   base OIL = D x = 5.00
#>   base EMP = D x = 3.00
```
