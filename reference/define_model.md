# Define the model

Declares the goals of the preemptive goal program (Rocha, 2026, section
4.4): the satellite accounts (in declaration order), the direction and
the goal of each one, the economic block (ECO), the priority orderings,
the scenarios and the use of the corridor declared with the data.

## Usage

``` r
define_model(
  accounts,
  economy = list(direction = ">=", target = "final_demand"),
  priorities = "all",
  scenarios = NULL,
  corridor = list(use = TRUE, multiplier = 1),
  lock_tolerance = "auto",
  name = "model",
  data = NULL,
  max_orderings = 720
)
```

## Arguments

- accounts:

  Named list, one entry per satellite account, in declaration order.
  Each entry: `direction`, `target` and, optionally, `weight`, `unit`
  and `label`.

- economy:

  List with `direction` (default `">="`), `target` (`"final_demand"`,
  the default, the declared `f`; a numeric vector with one goal per
  sector; or a CSV file with `code` and `value`), `position` (`"last"`,
  the default, or `"free"`) and `deviation` (`"absolute"`, the default,
  or `"relative"`).

- priorities:

  `"all"`, a `permute` specification or a list of explicit orderings
  (see above).

- scenarios:

  Named list of scenarios (optional).

- corridor:

  List with `use` (default `TRUE`) and `multiplier` (default 1).

- lock_tolerance:

  Lock of the levels already solved. `"auto"` (default): the exact lock
  `d_l == Z_l` and, only if a level of the run ends non-optimal (a false
  infeasibility of GLPK), the run is solved again with relaxed locks
  `d_l <= Z_l + t * max(1, |Z_l|)`, with the smallest `t` among 1e-12,
  1e-11, 1e-10 and 1e-9 that makes every level optimal. Runs that are
  optimal with the exact lock do not change; each run records the
  tolerance used, and the outputs flag the relaxed runs. `"exact"` (or
  `0`): only the exact lock. A number `t` (up to 1e-6): the exact lock
  and, if it fails, the relaxed one with `t`.

- name:

  Name of the model (used in the outputs).

- data:

  Path of the database (optional; used by
  [`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
  when the model comes from a file).

- max_orderings:

  Safety limit for the number of orderings.

## Value

Object of class `lexio_model`.

## Details

**Directions.** `">="` (a floor: the goal should be reached or exceeded)
penalizes `d-`; `"<="` (a ceiling: the goal should not be exceeded)
penalizes `d+`; `"="` penalizes both. The direction is declared for each
account; in Rocha (2026), the entrant energy is `">="`, the incumbent
energy `"<="` and labour `">="`.

**Goals of the satellite accounts** (`b` = base of the account, `D x`):

- `list(type = "base")`: keep the base, `g = b`;

- `list(type = "growth", rate = r)`: `g = b + b * r`;

- `list(type = "pooled_share", share = s, pool = c("A", "B"))`:
  `g = b + (b_A + b_B) * s`, a shock equal to a share of the sum of the
  bases of a set of accounts;

- `list(type = "delta", value = v)`: `g = b + v`;

- `list(type = "level", value = v)`: `g = v`.

**Priorities.** Each priority level minimizes the weighted sum of the
penalized deviations of its goals; the levels are solved in order, each
one locked at its optimum (preemptive priorities). Without a
declaration, every ordering is run; to run only some orderings, declare
them.

- `"all"` (default): one level per account, all `k!` orders of the
  accounts in lexicographic order of declaration (with 3 accounts, P1 =
  1-2-3, P2 = 1-3-2, P3 = 2-1-3, P4 = 2-3-1, P5 = 3-1-2, P6 = 3-2-1).

- `list(permute = list(c("OIL", "COAL"), c("SO2", "HC"), "EMP"))`: all
  orders of the declared groups (a group is one level with several
  goals).

- A list of explicit orderings, each a list of levels, for instance
  `list(first = c("GC", "GD", "LAB"), second = list(c("GD", "GC"), "LAB"))`.
  Only these orderings are run. Each account appears exactly once; an
  ordering given as a character vector has one level per element.

**ECO is fixed at the last level** (the benchmark of the model: it
absorbs the final impact). To place it elsewhere, the operator must say
so explicitly with `economy = list(position = "free")`: then `"ECO"` can
be written at any level of an explicit ordering, and with `"all"` or
`permute` ECO enters the permutations (`(k + 1)!` orderings with
`"all"`). With `position = "last"` (default), `"ECO"` may be written
only as the last level, and it is added there when omitted.

**Economic deviations.** With `economy = list(deviation = "absolute")`
(default), the ECO level minimizes the sum of the deviations of the
sectors in currency units, so large sectors weigh more. With
`deviation = "relative"`, each sector's deviation is divided by its
goal, `d_h / |g_h|`: the level minimizes the sum of the proportional
deviations, and a shortfall of 1% weighs the same in every sector. It
needs `g_h != 0` in every sector.

**Weights.** `weight` (default 1) multiplies the deviation of an account
inside its level; it only matters when several goals share a level.

**Corridor.** The corridor itself is declared with the data
([`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)).
`corridor = list(use = FALSE)` ignores it (free model); `multiplier`
scales `alpha`.

**Scenarios.** Each scenario replaces the goals of some accounts and,
optionally, the directions (`directions`) and the corridor (`corridor`).
Without scenarios, the model has one scenario, `main`.

## See also

[`read_model()`](https://filipevascrocha.github.io/lexio/reference/read_model.md),
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md).

## Examples

``` r
shock <- list(type = "pooled_share", share = 0.05, pool = c("E", "I"))
m <- define_model(list(
  E = list(direction = ">=", target = shock),
  I = list(direction = "<=", target = "base"),
  LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))
))
m
#> <lexio_model> model | 3 satellite account(s), 1 scenario(s), 6 priority ordering(s) | lock: auto (exact; relaxed only where GLPK fails) 
#>   E        >= base + 0.05 x (E + I)
#>   I        <= base
#>   LAB      >= base x (1 + 0.05)
#>   ECO      >= final demand f | absolute deviations | fixed at the last level
#>   corridor: as declared in the data (multiplier 1) 
#>   P01: E > I > LAB > ECO
#>   P02: E > LAB > I > ECO
#>   P03: I > E > LAB > ECO
#>   P04: I > LAB > E > ECO
#>   P05: LAB > E > I > ECO
#>   P06: LAB > I > E > ECO
#>   scenario main  
```
