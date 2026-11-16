# Declaring data and models

This vignette describes every part of a `lexio` study: the notation, the
declaration of the database, the goals and scenarios, the priorities,
the outputs and the numerical behaviour of the method.
[`vignette("lexio")`](https://filipevascrocha.github.io/lexio/articles/lexio.md)
runs a complete example first.

## 1. Notation

The notation follows Rocha (2026, section 4.2). With `n` sectors and `k`
satellite accounts:

| Symbol | Meaning | In lexio |
|----|----|----|
| `Z` (n × n) | intermediate transactions: row = selling sector, column = buying sector | `declare_io(Z = )`, file `Z` |
| `x` (n) | gross output | `declare_io(x = )`, file `x` |
| `f` (n) | final demand | `declare_io(f = )`, file `f` |
| `A = Z x̂⁻¹` | technical coefficients (by column) | computed from `Z`, or `declare_io(A = )` |
| `B = I − A` |  | computed, or `declare_io(B = )`; `io$B` |
| `E_j` (n) | level of satellite account `j` in each sector (toe, jobs, tonnes, …) | `declare_io(E = list(j = ...))`, file `E` |
| `D = E x̂⁻¹` (k × n) | satellite coefficients: account `j` per unit of output | computed from `E`, or `declare_io(D = )`; `io$D` |
| `b_j = D_j x` | base of account `j` | `satellite_base(io)` |
| `G = [D; B]` ((k + n) × n) | the goal matrix | `build_lp()$G` |
| `g` (k + n) | the goals: `k` account goals, then `n` economic goals | `build_goals(io, model, scenario)` |
| `d⁺`, `d⁻` | deviations above and below each goal | `run$d_plus`, `run$d_minus` |
| `α_h` | corridor of sector `h`, a proportion of `|g_h|` | `declare_io(corridor = )`, or `floor =` / `ceiling =` |
| `P_l` | priority level `l` | `define_model(priorities = )` |
| `Z_l` | optimum of level `l` (not the matrix `Z`) | `run$Z`, columns `Z1` … `ZL` of the outputs |
| ECO | the economic block: the `n` rows of `B`, with goal `f` by default | the goal `"ECO"` in the priorities |

The goals form the system `G x + d⁻ − d⁺ = g`, with `x, d⁺, d⁻ ≥ 0`. The
decision variables are ordered
`x_1 ... x_n, d⁺_1 ... d⁺_{k+n}, d⁻_1 ... d⁻_{k+n}`.

## 2. The database

### 2.1. In R

``` r

io <- declare_io(
  Z = Z, x = x, f = f,                          # or A = A, or B = B, instead of Z
  E = list(GD = E_GD, GC = E_GC, LAB = E_LAB),  # or D = list(...): coefficients instead of levels
  corridor = alpha,                             # optional: corridor, or floor and/or ceiling
  sectors = data.frame(code = codes, name = names)
)
```

**The technical structure.** Give exactly one of `Z` (flows; the package
computes `A = Z x̂⁻¹` and `B = I − A`), `A` or `B`. The name of the
argument tells the package which object it receives.

**The satellite accounts.** Give exactly one of `E` (the level of each
account in each sector; the package computes `D = E x̂⁻¹`) or `D` (the
coefficients per unit of output). The names are the names of the
accounts. Accepted forms:

- a named list of vectors (recommended):
  `E = list(GD = E_GD, LAB = E_LAB)`, one value per sector;
- a data frame, one column per account and one row per sector (an
  optional `code` column matches the rows to the sectors);
- a matrix: for `E`, sectors × accounts; for `D`, accounts × sectors.
  The other orientation is detected. A square matrix (`k = n`) is
  ambiguous and is refused: use a list.

A single vector without a name is refused: write
`E = list(LAB = my_vector)`.

**The sectors.** A data frame with `code` and `name`. Without it, the
codes come from the names of `x` or the column names of `Z`, or are
`S01`, `S02`, ….

**Accounts of the database and accounts of the model.** The model uses
only the accounts listed in its `accounts`. A database with six accounts
serves models with one, two or six of them.

### 2.2. The corridor

`α_h` is a proportion of `|g_h|`, the goal of the economic row of sector
`h` (by default, the final demand `f_h`):

| Declaration | Bound | Meaning |
|----|----|----|
| `corridor = alpha` | `d⁻_h ≤ α_h |g_h|` and `d⁺_h ≤ α_h |g_h|` | two-sided corridor |
| `floor = alpha` | `d⁻_h ≤ α_h |g_h|`, that is `G_h x ≥ g_h − α_h |g_h|` | only a floor |
| `ceiling = alpha` | `d⁺_h ≤ α_h |g_h|`, that is `G_h x ≤ g_h + α_h |g_h|` | only a ceiling |
| `floor = a1, ceiling = a2` | both, with different widths | floor and ceiling |
| nothing | no bound | free model |

- `alpha = 0.05` in a sector lets its economic goal deviate by up to 5%
  of `|g_h|`.
- `NA` in a sector leaves that sector without a bound on that side.
- `corridor` together with `floor` or `ceiling` is an error.
- The model multiplies `α` by `corridor: multiplier` (default 1) and can
  switch the corridor off with `corridor: use: false`, also in a single
  scenario (section 3.3).
- If the corridor comes from a quantity per sector (for instance, the
  purchases of energy by each sector), compute the proportion first:
  `alpha <- purchases / x`.
- The satellite goals never have a corridor.

### 2.3. Files

`read_io(path)` reads a folder of CSV files, or an `.xlsx` workbook with
sheets of the same names. `write_io(io, dir)` writes a declared database
in this format, and `lexio_template(dir)` writes an example database
with a commented `model.yml`.

| File / sheet | Columns | Content |
|----|----|----|
| `sectors` | `code`, `name` | the sectors; sets `n` and the order of the sectors in the outputs |
| `Z`, `A` or `B` (one) | `code` + one column per sector (header = codes) | the technical structure |
| `x` | `code`, `value` | gross output |
| `f` | `code`, `value` | final demand |
| `E` or `D` (one) | `code` + one column per account | levels or coefficients of the satellite accounts; the headers are the account names |
| `corridor`, or `floor` and/or `ceiling` (optional) | `code`, `alpha` | proportions `α_h` (empty or `NA` = no bound) |

- Codes are text (`0191` stays `0191`). The rows of each file are
  matched to the sectors by code, in any order.
- CSV files may use `,` as separator and `.` as decimal mark, or `;` and
  `,`. The format is detected from the first line of each file.
- `Z`, `x` and `f` are in the same currency unit; each satellite account
  is in its own unit.
- Write the numbers with all their digits (up to 17 significant digits).
  [`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
  does this. Section 7.2 explains why it matters.

### 2.4. Checks

[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
and
[`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md)
stop with an error when the dimensions are inconsistent, when not
exactly one of `Z`/`A`/`B` or of `E`/`D` is given, when codes are
duplicated or do not match across files, when a value is missing or not
finite, when `x ≤ 0` in some sector, or when some `α` is negative. They
warn when a column of `A` sums to 1 or more, when `I − A` is nearly
singular, or when a coefficient is negative.
[`validate_io()`](https://filipevascrocha.github.io/lexio/reference/validate_io.md)
gives the full report, including the corridor mode and, whatever the
declaration (`Z`, `A` or `B`), the largest discrepancy between
`(I − A) x` and `f`.

``` r

validate_io(example_io())
#>                   check level                                             detail
#> 1            dimensions  info      3 sectors, 3 satellite account(s) (E, I, LAB)
#> 2          columns of A    ok                                 largest sum 0.4375
#> 3                 I - A    ok                         invertible (rcond = 0.497)
#> 4              corridor    ok      two-sided corridor; alpha between 0.1 and 0.2
#> 5 balance (I - A) x = f  info largest |(I - A) x - f| 0 (relative to x 0); sum 0
```

The economic block uses `f` as its goal. If `f` differs from
`(I − A) x`, a run without any shock does not return exactly `x`: the
model closes the gap within the corridor.

## 3. The model

### 3.1. A complete `model.yml`

``` yaml
name: my_study
data: base                 # the database: a folder (or base.xlsx), relative to this file

accounts:                  # satellite accounts, in declaration order
  GD:
    label: Distributed generation
    unit: toe
    direction: ">="
    target: {type: pooled_share, share: 0.01, pool: [GD, GC]}
  GC:
    label: Centralized generation
    unit: toe
    direction: "<="
    target: {type: base}
  LAB:
    label: Employment
    unit: jobs
    direction: ">="
    target: {type: growth, rate: 0.01}
    weight: 1              # optional; matters only when goals share a level

economy:                   # the economic block ECO (section 3.4)
  direction: ">="
  target: final_demand     # or a list [5, 10, ...] or a CSV file (code, value)
  position: last           # the default: ECO fixed at the last level
  deviation: absolute      # the default; or relative

corridor:                  # the corridor declared with the data
  use: true                # false: free model
  multiplier: 1            # multiplies alpha

scenarios:                 # optional: several sets of goals in the same model
  GD_shock: {}             # the goals in accounts, unchanged
  GC_shock:
    GD: {type: base}
    GC: {type: pooled_share, share: 0.01, pool: [GD, GC]}
  GC_shock_free:
    GD: {type: base}
    GC: {type: pooled_share, share: 0.01, pool: [GD, GC]}
    corridor: {use: false}

priorities: all            # all k! orders, ECO last (section 4)
lock_tolerance: auto       # the default (section 7)
```

The accepted keys are `name`, `data`, `accounts`, `economy`, `corridor`,
`scenarios`, `priorities`, `lock_tolerance` and `max_orderings`. Any
other key is an error.
[`read_model()`](https://filipevascrocha.github.io/lexio/reference/read_model.md)
reads the file; `run_model("model.yml")` reads the model and the
database it names.

The same model in R:

``` r

pooled <- list(type = "pooled_share", share = 0.01, pool = c("GD", "GC"))
m <- define_model(
  accounts = list(
    GD  = list(direction = ">=", target = pooled, label = "Distributed generation", unit = "toe"),
    GC  = list(direction = "<=", target = list(type = "base"), label = "Centralized generation", unit = "toe"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.01), label = "Employment", unit = "jobs")
  ),
  economy = list(direction = ">=", target = "final_demand"),
  scenarios = list(GD_shock = list(),
                   GC_shock = list(GD = list(type = "base"), GC = pooled)),
  priorities = "all",
  lock_tolerance = "auto"
)
```

### 3.2. Directions and goals

Each account has a direction:

| Direction | Meaning                           | Penalized deviation |
|-----------|-----------------------------------|---------------------|
| `">="`    | floor: do not fall below the goal | `d⁻`                |
| `"<="`    | ceiling: do not exceed the goal   | `d⁺`                |
| `"="`     | target: stay on the goal          | `d⁻` and `d⁺`       |

and a goal, computed from its base `b = D_j x`:

| `target` | Goal `g` | Typical use |
|----|----|----|
| `{type: base}` | `b` | keep the current level |
| `{type: growth, rate: r}` | `b + b·r` | grow (or shrink, with a negative rate) by a fraction |
| `{type: pooled_share, share: s, pool: [A, B]}` | `b + s·(b_A + b_B)` | a shock equal to a share of the joint base of a group of accounts |
| `{type: delta, value: v}` | `b + v` | add an absolute amount |
| `{type: level, value: v}` | `v` | set an absolute level |

The goal `g` is always the total level of the account, not only the
change. For instance, with `b_GD = 4.08` and `b_GC = 26.18`, the goal
`{type: pooled_share, share: 0.01, pool: [GD, GC]}` of `GD` is
`4.08 + 0.01 × (4.08 + 26.18) = 4.38`.

``` r

io <- example_io()
m <- define_model(list(
  E = list(direction = ">=", target = list(type = "pooled_share", share = 0.05, pool = c("E", "I"))),
  I = list(direction = "<=", target = list(type = "base")),
  LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))
))
satellite_base(io)
#>     E     I   LAB 
#>   6.6  29.0 260.0
build_goals(io, m)[1:3]
#> [1]   8.38  29.00 273.00
```

### 3.3. Scenarios

Each scenario replaces the goals of some accounts, and every scenario
runs in every ordering. A scenario may also change:

- the directions, for example `directions: {GC: "=", economy: "="}`;
- the corridor, for example `corridor: {multiplier: 2}` or
  `corridor: {use: false}`.

Without `scenarios`, the model has a single scenario named `main`.

### 3.4. The economic block

**Goal.** By default, the goal of ECO is the declared final demand. In
`economy: target`, a list of values (one per sector) or a CSV file with
columns `code` and `value` gives another goal; `economy: direction`
changes its direction.

**Position.** `economy: position: last` (the default) fixes ECO at the
last level: the economic block absorbs the final impact of the goals
above it. An ordering may write `ECO` only as its last level, or omit
it; it is added there. To place ECO elsewhere, the model must say so
with `economy: position: free`. Then `ECO` can be written at any level
of an explicit ordering, and with `priorities: all` (or `permute`) ECO
enters the permutations, giving `(k + 1)!` orderings. The Miller and
Blair example uses this declaration
([`vignette("miller-blair")`](https://filipevascrocha.github.io/lexio/articles/miller-blair.md)).

**Deviations.** The ECO level minimizes the deviations of the `n`
sectors from their goals.

- `deviation: absolute` (the default) adds them in currency units,
  `Σ_h d⁻_h`. A shortfall of one currency unit costs the same in every
  sector, whatever its size.
- `deviation: relative` adds them as proportions of each goal,
  `Σ_h d⁻_h / |g_h|`. A shortfall of 1% of a sector’s final demand costs
  the same in every sector.

When the goals above ECO force the economy to give up some final demand,
the ECO level chooses which sectors give it up. In the example below,
the incumbent energy is cut by 20% at the first level, without a
corridor:

``` r

io <- example_io()
cut <- list(I = list(direction = "<=", target = list(type = "growth", rate = -0.2)))
for (deviation in c("absolute", "relative")) {
  m <- define_model(cut, economy = list(direction = ">=", target = "final_demand", deviation = deviation),
                    corridor = list(use = FALSE))
  r <- run_experiment(io, m, ordering = 1)
  loss <- r$d_minus[1 + seq_len(io$n)]
  print(data.frame(deviation = deviation, sector = io$sectors$name, loss = round(loss, 2),
                   share_of_demand = round(loss / io$f, 3)))
}
#>   deviation      sector  loss share_of_demand
#> 1  absolute Agriculture  0.00           0.000
#> 2  absolute    Industry 20.45           0.487
#> 3  absolute    Services  0.00           0.000
#>   deviation      sector  loss share_of_demand
#> 1  relative Agriculture 32.14           0.459
#> 2  relative    Industry  0.00           0.000
#> 3  relative    Services  0.00           0.000
```

With absolute deviations the level chooses the smallest loss in
currency, and the loss falls on Industry, where it takes almost half of
the demand. With relative deviations it chooses the smallest loss in
proportion of each sector’s demand. Each level is a linear program, so
the loss is not spread evenly: the solution is a vertex, and it
concentrates the loss where it is cheapest in the chosen measure. A
corridor already caps the loss of each sector; with a tight corridor the
two choices tend to give the same solution. The relative deviations need
a nonzero goal `g_h` in every sector, and the optimum `Z` of the ECO
level is then a sum of proportions.

## 4. Priorities

Without a declaration, every ordering is run; to run only some
orderings, declare them. In every case ECO is the last level, unless the
model declares `economy: position: free`.

### 4.1. All orders

`priorities: all` (the default) puts one account per level and runs all
`k!` orders, in the lexicographic order of declaration. With accounts
`[A, B, C]`:

``` r

lex_permutations(3)
#>      [,1] [,2] [,3]
#> [1,]    1    2    3
#> [2,]    1    3    2
#> [3,]    2    1    3
#> [4,]    2    3    1
#> [5,]    3    1    2
#> [6,]    3    2    1
```

The rows are the orderings `P01` to `P06`: `A-B-C`, `A-C-B`, `B-A-C`,
`B-C-A`, `C-A-B` and `C-B-A`.

|   k | Levels          | Orderings per scenario |
|----:|-----------------|-----------------------:|
|   2 | P1, P2, ECO     |                      2 |
|   3 | P1, P2, P3, ECO |                      6 |
|   4 | P1, …, P4, ECO  |                     24 |
|   6 | P1, …, P6, ECO  |                    720 |

When the number of orderings exceeds `max_orderings` (default 720), the
package asks for explicit orderings or a higher limit.

### 4.2. Permuting groups

``` yaml
priorities:
  permute: [[GD, GC], LAB]   # GD and GC share a level; 2! = 2 orderings, ECO last
```

Each group is one level with several goals, and every account must be in
exactly one group. With `economy: position: free`, ECO is permuted with
the groups.

### 4.3. Explicit orderings

``` yaml
priorities:
  first: [LAB, GD, GC]          # one account per level; ECO is added as the last level
  second: [[GD, GC], LAB]       # GD and GC share the first level
```

In R:
`priorities = list(first = c("LAB", "GD", "GC"), second = list(c("GD", "GC"), "LAB"))`.
To run a single ordering, list only that one;
`run_model(..., orderings = )` also runs only some of the orderings of a
model.

- Each account appears exactly once.
- `ECO` may be written at the end; elsewhere only with
  `economy: position: free` (then `[LAB, ECO, [GD, GC]]` puts ECO
  second).
- ECO is alone in its level.
- Each goal keeps its own direction, so a level may mix floors and
  ceilings.

**Labels.** Unnamed orderings with one account per level and ECO last
get the label of their position in the lexicographic order (`P05` for
`C-A-B` with `k = 3`); other unnamed orderings get `O01`, `O02`, …;
named orderings keep their names.

### 4.4. Weights

`weight` (default 1, positive) multiplies the deviation of an account in
its level. It matters only when goals share a level: the level minimizes
`Σ weight × penalized deviation`. A level that holds goals in different
units adds their deviations, so give them comparable units or weights.

## 5. Running

``` r

res <- run_model("my_study/model.yml")   # reads the database named in data:
res <- run_model(io, m)                  # or the database and the model already in memory
```

| Argument of [`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md) | Effect |
|----|----|
| `scenarios` | only some scenarios (names) |
| `orderings` | only some orderings (numbers or labels) |
| `strict` | with `TRUE`, stops at the first non-optimal level; the default `FALSE` runs everything and flags it |
| `verbose` | shows progress |
| `lock_tolerance` | replaces the setting of the model (section 7) |

A single run:

``` r

io <- example_io()
m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
r <- run_experiment(io, m, scenario = "I_shock", ordering = c("LAB", "E", "I"))
r$Z        # optimum of each level
#> [1] 0 0 0 0
r$x_star   # output of the last level
#> [1] 100.76394  81.06627  65.85146
```

`ordering` can be a number, a label (`"P05"`, `"second"`) or an ordering
written as in section 4.3. Each run takes hundredths to tenths of a
second: a database with 72 sectors and 6 accounts (720 orderings) runs
in about a minute.

## 6. Outputs

`write_outputs(res, dir)` writes:

    dir/
      README.md            report: model, corridor, ECO, tables per scenario, distinct states, warnings
      results.xlsx         every table in one Excel workbook (see write_excel())
      orderings.csv        one row per scenario × ordering
      levels.csv           one row per scenario × ordering × level: each stage of each run
      level_results.csv    every run, every level, every row of G
      account_goals.csv    one row per scenario × ordering × account
      x_star_all_runs.csv  one row per sector: x0 and the output x* of every run
      states.csv           distinct states (equal x* solutions)
      runs/<scenario>/<label>_<levels>/
                           all_levels.csv, level_1.csv ... level_L.csv, x_star.csv
      inputs/              the model.yml used and the SHA-256 of the database files
      results.rds          the full object (readRDS)
      session.txt          versions of R, of the packages and of GLPK

- The folder of a run is its label and its levels, for example
  `P04_GC-LAB-GD` or `book_1_EMP-ECO-OIL+COAL-SO2+HC`; ECO is written
  only when it is not last.
- `format = "intl"` (default) writes the CSV files with `,` and `.`;
  `format = "br"` with `;` and `,`, for spreadsheets with a comma as
  decimal mark.
- An existing folder with files is not overwritten unless
  `overwrite = TRUE`.
- `excel = FALSE` skips `results.xlsx`.

**`orderings.csv`** (`res$summary$runs`)

| Column | Content |
|----|----|
| `scenario`, `ordering`, `label`, `priorities` | the run and its levels (`GD > GC > LAB > ECO`) |
| `status` | GLPK code of each level, concatenated (`0000` = all optimal) |
| `status_glpk` | the same, spelled out (`GLP_OPT GLP_OPT GLP_OPT GLP_NOFEAS`) |
| `optimal`, `ok` | all levels optimal; and, in addition, all checks passed |
| `lock_tolerance` | lock used in the run (0 = exact; section 7) |
| `corridor` | corridor mode of the run |
| `Z1` … `ZL` | optimum of each level |
| `delta_x`, `delta_x_pct` | change in total gross output, `Σ x* − Σ x`, and as a fraction |
| `delta_<account>` | change of each account, `D_j x* − b_j` |
| `state` | distinct state of the run |

**`levels.csv`** (`res$summary$levels`): one row per level of each run,
with its goals, its optimum `Z`, the GLPK status and the lock used.

**`level_results.csv`**: for every run and every level, one row per row
of `G` (`row`, `block` = account or ECO), with `g`, `Gx`, `d_minus`,
`d_plus` and, in the ECO rows, the output `x` of that level.

**`all_levels.csv`** (one per run): the same numbers, with the levels
side by side: `row`, `notation` (`xD_j` = `D_j x`; `f'_h` = row `h` of
`(I − A) x`), `name`, `block`, `g`, and `level<l>_Gx`,
`level<l>_d_minus`, `level<l>_d_plus` and `level<l>_x` of each level.

**`account_goals.csv`** (`res$summary$goals`)

| Column | Content |
|----|----|
| `account`, `unit`, `direction` | the account |
| `base`, `g`, `Gx` | base `b`, goal `g` and achieved value `D_j x*` |
| `delta`, `intended` | `Gx − base` and `g − base` |
| `realized` | realized share of the intended change, `delta / intended` |
| `deviation` | penalized deviation of the account |
| `at_goal` | the account met its goal |

**`states.csv`** (`res$summary$states`). Different orderings may lead to
the same solution. Runs whose outputs `x*` differ by at most 1e-6 in
every sector form one state.

**`results.xlsx`**: the sheets are described in
[`vignette("lexio")`](https://filipevascrocha.github.io/lexio/articles/lexio.md)
and in
[`?write_excel`](https://filipevascrocha.github.io/lexio/reference/write_excel.md).

## 7. Numerical behaviour

### 7.1. The lock of the solved levels

Each level locks the previous ones by equality, `d_l = Z_l`, which holds
with zero slack. When the scales of the goals differ widely (toe, jobs
and currency units in the same problem), GLPK sometimes declares
infeasible (`GLP_NOFEAS`) a level that has a solution. This is a
numerical false infeasibility: another solver (lpSolve) solves the same
problem. It depends on the numbers, not on the number of accounts:

| Database | Runs not optimal with the exact lock |
|----|----|
| Brazil 2018 (EPE), 72 sectors, k = 3, coefficients with 15 significant digits | 0 of 24 |
| the same database at full precision | 4 of 24 |
| Brazil 2018 (EPE), k = 4 / 5 / 6 | 4 of 24 / 20 of 120 / 186 of 720 |
| Brazil 2015 (IBGE), 67 sectors, k = 4 | 9 of 24 |

`lock_tolerance: auto` (the default):

- every run first uses the exact lock;
- only if some level is not optimal is the run solved again with the
  locks relaxed to `d_l ≤ Z_l + t·max(1, |Z_l|)`, with the smallest `t`
  among 1e-12, 1e-11, 1e-10 and 1e-9 that makes every level optimal;
- if no `t` works, the run keeps the exact lock and is flagged as not
  optimal.

Runs that are optimal with the exact lock do not change. In the tests
with the two real databases, `auto` made all 906 runs optimal; of the
219 runs solved again, 211 needed only `t = 1e-12`.

**The precision cost.** The slack lets each solved level stay above its
optimum by up to `t·max(1, |Z_l|)`, and the following levels may use it.
In ill-conditioned problems the effect on the following levels is much
larger than `t`: in the tests, `t = 1e-9` moved the `Z` of the following
levels by up to about 2e-4 (relative) from an exact solution. Every
relaxed run is therefore flagged:
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
issues a warning, [`print()`](https://rdrr.io/r/base/print.html) shows
it, the column `lock_tolerance` gives the `t` used and the report lists
the runs in its *Warnings* section. When publishing results, report how
many runs needed the relaxed lock.

The other options are `lock_tolerance: exact` (or `0`), which keeps only
the exact lock and leaves failing runs flagged as not optimal, and a
number `t` (up to 1e-6), which tries the exact lock and then only `t`.

### 7.2. Sensitivity to the last digits

With equality locks, the GLPK status can change under perturbations of
the data of the order of 1e-16. The same database written with 15 or
with 17 significant digits gives the same numbers up to about 1e-10, but
may change the status of borderline runs. For bit-identical results, use
bit-identical inputs;
[`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
writes the shortest exact decimal representation of each number. On Macs
with Apple silicon, R itself may read a number written with 16 or 17
significant digits with a difference in the last bit; numbers with up to
15 significant digits, such as the coefficients of the thesis, are read
exactly everywhere.

### 7.3. Alternative optima

A level may have several optima, with the same `Z` and a different `x`.
GLPK returns one of them. This is one reason why results are also
summarized by distinct states.

### 7.4. What the model does not impose

- There is no non-negativity constraint on the satellite accounts
  (`D x`) or on the resulting final demand.
- The corridor applies only to the economic block. The deviations of the
  satellite accounts are free; their cost lies in the priority order.

### 7.5. Levels without solution

A level can have no solution: for instance, a zero corridor (`α = 0`)
with an economic goal that no non-negative output meets. GLPK then also
reports the level as not optimal. To tell this case from a false
infeasibility, `lexio` checks the solution returned by GLPK against the
constraints of the level (goals, corridor, locks and `x, d ≥ 0`), each
row relative to `max(1, |right-hand side|)`:

- violation up to 1e-4: the constraints hold, so the flag is a false
  infeasibility; the numbers are kept and the run is flagged as not
  optimal. In the false infeasibilities we examined (several hundred
  runs), the violation stayed below 1e-6;
- violation above 1e-4: the level has no solution. That level and the
  following ones are left blank (`NA`) in the run and in every table,
  the column `infeasible_level` of `summary$runs` gives the first one
  (the report says “no solution from level l”), and the run has no
  state. In levels without solution the violation is of order 1e-2 or
  more.

The column `violation` of `summary$levels` (and of `levels.csv`) gives
the value for every level. A negative `α` or corridor multiplier is
refused when declared.

## 8. Scope and limits

- **Size.** The matrices are dense. On one laptop, one run with three
  accounts (four levels) took about 0.1 s with 100 sectors, 0.4 s with
  200, 2 s with 400 and 7 s with 600; the times depend on the machine
  and on the matrix (on another machine, with fully dense random
  matrices, they were about twice as long), but the time always grows
  faster than the square of the number of sectors, and a model runs `k!`
  orderings per scenario. National tables, with tens to a few hundred
  sectors, are within reach; multiregional tables with thousands of
  sectors are not.
- **Priorities.** Every account of the model enters every ordering;
  there are no accounts that are only monitored.
- **Economic block.** It is one goal: every sector has the same
  direction, and the goal vector (`f` by default) is the same in every
  scenario.
- **Corridor.** It bounds only the deviations of the economic goals, as
  proportions of `|g_h|`. There is no corridor on the output `x` and no
  corridor in absolute values.

## 9. Questions

**Can I use one or two satellite accounts?** Yes. With `k = 1` there is
one run per scenario; with `k = 2`, two.

**My satellite accounts are already coefficients. Do I need the
levels?** No: declare `D =` instead of `E =` (and `A =` or `B =` instead
of `Z =`).

**My vectors are already in R. Do I need to write files?** No: pass them
to
[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
by name.
[`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
is only for saving the declared database.

**Can I run a single priority ordering?** Yes: list it in `priorities`,
for instance `priorities: {mine: [GC, GD, LAB]}`.

**Can I run without a corridor?** Yes: declare no corridor, or set
`corridor: use: false` in the model or in a scenario.

**What does a “not optimal” run mean?** That GLPK did not certify some
level. Usually it is a numerical false infeasibility, and the numbers
are kept; if the level has no solution, it is left blank. See sections
7.1 and 7.5.

**How was the package tested?** The tests in `tests/testthat` cover
synthetic databases with 2 to 100 sectors and 1 to 5 accounts
(dimensions, non-degradation of the higher priorities, invariance to the
order of the sectors, to the order of declaration and to the form of the
declaration), the corridor modes, the forms of the priorities, the
relative deviations, the lock, the outputs, the Miller and Blair example
and a comparison of every level with an independent implementation
solved with lpSolve.

## References

- Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
  Programming preemptivo aplicado à transição energética brasileira:
  eletricidade e combustíveis na estrutura produtiva de 2018.* Doctoral
  thesis, Programa de Pós-graduação em Economia, Universidade Federal de
  Juiz de Fora.
- Miller, R. E. and Blair, P. D. (2022). *Input-Output Analysis:
  Foundations and Extensions.* 3rd ed. Cambridge University Press,
  section 13.8. Previous edition: 2nd ed., 2009, section 10.4.
