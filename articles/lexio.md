# Get started with lexio

`lexio` runs an input-output model solved by preemptive (lexicographic)
goal programming. You declare an input-output database that you already
have and, for each satellite account (energy, jobs, emissions, …), a
direction, a goal and a priority. The package chooses the sectoral
output that best meets the goals, in priority order, for every ordering
of the priorities, and writes every result.

This vignette runs a complete example on a three-sector database. The
other vignettes cover the full specification
([`vignette("model-specification")`](https://filipevascrocha.github.io/lexio/articles/model-specification.md)),
the goal programming example of Miller and Blair
([`vignette("miller-blair")`](https://filipevascrocha.github.io/lexio/articles/miller-blair.md))
and the replication of the thesis that introduced the model
([`vignette("thesis-replication")`](https://filipevascrocha.github.io/lexio/articles/thesis-replication.md)).

## The model

With `n` sectors and `k` satellite accounts, the goals form the system

``` math
G x + d^- - d^+ = g, \qquad
G = \begin{bmatrix} D \\ I - A \end{bmatrix}, \qquad
x,\ d^+,\ d^- \ge 0 .
```

- `x` is the gross output of each sector, the decision variable.
- The first `k` rows are the satellite accounts. `D` holds the
  coefficients of each account per unit of output, so `D_j x` is the
  level of account `j` and `b_j = D_j x_0` is its base.
- The last `n` rows are the economic block, ECO: `(I - A) x` against the
  final demand `f`.
- `d^-` and `d^+` are the deviations below and above each goal `g`.

Each account has a **direction**. A floor (`">="`) penalizes the
shortfall `d^-`, a ceiling (`"<="`) penalizes the excess `d^+`, and a
target (`"="`) penalizes both. ECO is a floor on the final demand by
default.

The goals are met in **priority order**. Each priority level is a linear
program, solved with GLPK, that minimizes the penalized deviations of
its goals; its optimum is then locked for the following levels. Since
the order matters, the package runs, by default, all `k!` orderings of
the accounts, with ECO fixed at the last level.

Optionally, a **corridor** bounds the economic deviations:
`d_h^-, d_h^+ <= alpha_h |g_h|`, where `alpha_h` is a proportion
declared for each sector.

## A first run

### 1. Declare the database

The database has three sectors. `Z` holds the intermediate flows (row =
selling sector, column = buying sector), `x` the gross output and `f`
the final demand. Each satellite account is given as its level in each
sector: an entrant energy source `E` and an incumbent `I` (in toe) and
labour `LAB` (in jobs). `alpha` is the corridor of each sector.

``` r

library(lexio)

Z <- matrix(c(10, 15, 5,
              20, 10, 8,
               5, 10, 6), nrow = 3, byrow = TRUE)
x <- c(100, 80, 60)
f <- c(70, 42, 39)
E_entrant <- c(2, 4, 0.6)
E_incumbent <- c(10, 16, 3)
E_labour <- c(100, 40, 120)
alpha <- c(0.10, 0.20, 0.15)
sectors <- data.frame(code = c("S1", "S2", "S3"), name = c("Agriculture", "Industry", "Services"))
```

[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
receives each object under the name of what it is: `Z =` for flows
(`A =` or `B =` for technical coefficients), `E =` for levels of the
accounts (`D =` for coefficients) and `corridor =` for the corridor. The
package computes `A = Z x^-1`, `B = I - A` and `D = E x^-1`.

``` r

io <- declare_io(Z = Z, x = x, f = f,
                 E = list(E = E_entrant, I = E_incumbent, LAB = E_labour),
                 corridor = alpha, sectors = sectors)
io
#> <lexio_io> 3 sectors, 3 satellite account(s): E, I, LAB | declared as Z + E | corridor: two-sided corridor 
#>   base E = D x =   6.60
#>   base I = D x =  29.00
#>   base LAB = D x = 260.00
```

The printout shows how the database was declared, the corridor mode and
the base `b_j = D_j x` of each account. `validate_io(io)` gives the full
report of the consistency checks.

### 2. Declare the model

The entrant energy is a floor, the incumbent energy a ceiling and labour
a floor that should grow by 5%. Two scenarios give a shock equal to 5%
of the joint base of the two energy sources, either to the entrant or to
the incumbent.

``` r

shock <- list(type = "pooled_share", share = 0.05, pool = c("E", "I"))
model <- define_model(
  accounts = list(
    E   = list(direction = ">=", target = list(type = "base"), label = "Entrant energy", unit = "toe"),
    I   = list(direction = "<=", target = list(type = "base"), label = "Incumbent energy", unit = "toe"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05), label = "Labour", unit = "jobs")
  ),
  scenarios = list(E_shock = list(E = shock),
                   I_shock = list(I = shock)),
  name = "toy"
)
model
#> <lexio_model> toy | 3 satellite account(s), 2 scenario(s), 6 priority ordering(s) | lock: auto (exact; relaxed only where GLPK fails) 
#>   E        >= base
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
#>   scenario E_shock (changes: E) 
#>   scenario I_shock (changes: I)
```

The goal of each account is computed from its base. In the scenario
`E_shock`, the goal of `E` is `b_E + 0.05 (b_E + b_I)`, the goal of `I`
is its base and the goal of `LAB` is `1.05 b_LAB`. The goals of the
economic block are the final demand.
[`build_goals()`](https://filipevascrocha.github.io/lexio/reference/build_goals.md)
returns the whole vector `g`:

``` r

build_goals(io, model, "E_shock")
#> [1]   8.38  29.00 273.00  70.00  42.00  39.00
```

With three accounts there are `3! = 6` orderings, `P01` to `P06`, each
with four levels: the three accounts in the order of the ordering, and
ECO.

### 3. Run

``` r

res <- run_model(io, model, verbose = FALSE)
res
#> <lexio_results> toy | 3 sectors | 3 account(s): E, I, LAB | corridor: two-sided corridor 
#>   scenario E_shock        6 ordering(s) | all optimal | 3 distinct state(s)
#>   scenario I_shock        6 ordering(s) | all optimal | 1 distinct state(s)
#>   distinct states in total: 4 
#>   write everything with write_outputs(res, "folder")
```

The model ran 12 times: 2 scenarios and 6 orderings. A *state* is a
final solution `x*`; different orderings may lead to the same state.

## Reading the results

### In R

`res$summary` holds four tables. `runs` has one row per run: the GLPK
status of each level (`0` = optimal), the optimum `Z` of each level, the
change in total output and the change in each account.

``` r

runs <- res$summary$runs[, c("scenario", "label", "priorities", "status", "Z1", "Z2", "Z3", "Z4",
                             "delta_x", "delta_E", "delta_I", "delta_LAB", "state")]
runs[5:12] <- round(runs[5:12], 4)
runs
#>    scenario label        priorities status     Z1     Z2      Z3      Z4 delta_x delta_E delta_I
#> 1   E_shock   P01 E > I > LAB > ECO   0000 0.7813 4.3138  0.0000  0.0000 34.0591  0.9987  4.3138
#> 2   E_shock   P02 E > LAB > I > ECO   0000 0.7813 0.0000  4.3138  0.0000 34.0591  0.9987  4.3138
#> 3   E_shock   P03 I > E > LAB > ECO   0000 0.0000 1.7282 30.0487 12.8500 -8.2737  0.0518  0.0000
#> 4   E_shock   P04 I > LAB > E > ECO   0000 0.0000 0.0000  1.8041  3.2781  5.5370 -0.0241  0.0000
#> 5   E_shock   P05 LAB > E > I > ECO   0000 0.0000 0.7813  4.3138  0.0000 34.0591  0.9987  4.3138
#> 6   E_shock   P06 LAB > I > E > ECO   0000 0.0000 0.0000  1.8041  3.2781  5.5370 -0.0241  0.0000
#> 7   I_shock   P01 E > I > LAB > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#> 8   I_shock   P02 E > LAB > I > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#> 9   I_shock   P03 I > E > LAB > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#> 10  I_shock   P04 I > LAB > E > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#> 11  I_shock   P05 LAB > E > I > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#> 12  I_shock   P06 LAB > I > E > ECO   0000 0.0000 0.0000  0.0000  0.0000  7.6817  0.1271  0.5822
#>    delta_LAB state
#> 1    36.2871     1
#> 2    36.2871     1
#> 3   -17.0487     2
#> 4    13.0000     3
#> 5    36.2871     1
#> 6    13.0000     3
#> 7    13.0000     4
#> 8    13.0000     4
#> 9    13.0000     4
#> 10   13.0000     4
#> 11   13.0000     4
#> 12   13.0000     4
```

`levels` has one row per priority level of each run, `goals` one row per
account of each run (base, goal, achieved value) and `states` one row
per distinct solution.

``` r

res$summary$goals[res$summary$goals$scenario == "E_shock",
                  c("label", "account", "direction", "base", "g", "Gx", "realized")]
#>    label account direction  base      g         Gx    realized
#> 1    P01       E        >=   6.6   8.38   7.598676  0.56105395
#> 2    P01       I        <=  29.0  29.00  33.313833          NA
#> 3    P01     LAB        >= 260.0 273.00 296.287095  2.79131502
#> 4    P02       E        >=   6.6   8.38   7.598676  0.56105395
#> 5    P02       I        <=  29.0  29.00  33.313833          NA
#> 6    P02     LAB        >= 260.0 273.00 296.287095  2.79131502
#> 7    P03       E        >=   6.6   8.38   6.651815  0.02910970
#> 8    P03       I        <=  29.0  29.00  29.000000          NA
#> 9    P03     LAB        >= 260.0 273.00 242.951285 -1.31143959
#> 10   P04       E        >=   6.6   8.38   6.575926 -0.01352476
#> 11   P04       I        <=  29.0  29.00  29.000000          NA
#> 12   P04     LAB        >= 260.0 273.00 273.000000  1.00000000
#> 13   P05       E        >=   6.6   8.38   7.598676  0.56105395
#> 14   P05       I        <=  29.0  29.00  33.313833          NA
#> 15   P05     LAB        >= 260.0 273.00 296.287095  2.79131502
#> 16   P06       E        >=   6.6   8.38   6.575926 -0.01352476
#> 17   P06       I        <=  29.0  29.00  29.000000          NA
#> 18   P06     LAB        >= 260.0 273.00 273.000000  1.00000000
```

Printing a single run shows every level and every account:

``` r

res$runs[[3]]
#> <gp_run> toy | scenario E_shock | P03 : I > E > LAB > ECO 
#>   level 1 I            GLP_OPT    Z = 0
#>   level 2 E            GLP_OPT    Z = 1.72818
#>   level 3 LAB          GLP_OPT    Z = 30.0487
#>   level 4 ECO          GLP_OPT    Z = 12.85
#>   accounts at the last level:
#>     E        >= base 6.6            goal 8.38           achieved 6.651815       d- 1.72818      d+ 0
#>     I        <= base 29             goal 29             achieved 29             d- 0            d+ 0
#>     LAB      >= base 260            goal 273            achieved 242.9513       d- 30.0487      d+ 0
#>   ECO: shortfall sum(d-) = 12.85, excess sum(d+) = 6.81259 | delta x = -8.273668 (-3.4474%)
#>   corridor: two-sided corridor | ok: TRUE
```

### In files

[`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md)
writes every result to a folder: a report (`README.md`), an Excel
workbook (`results.xlsx`), the tables as CSV files and, for each run, a
folder with the results of every level.

``` r

out <- file.path(tempdir(), "toy_results")
write_outputs(res, out)
list.files(out)
#>  [1] "account_goals.csv"   "inputs"              "level_results.csv"   "levels.csv"         
#>  [5] "orderings.csv"       "README.md"           "results.rds"         "results.xlsx"       
#>  [9] "runs"                "session.txt"         "states.csv"          "x_star_all_runs.csv"
list.files(file.path(out, "runs", "E_shock", "P03_I-E-LAB"))
#> [1] "all_levels.csv" "level_1.csv"    "level_2.csv"    "level_3.csv"    "level_4.csv"   
#> [6] "x_star.csv"
```

`all_levels.csv` has one row per row of `G` (the accounts, then the
sectors) and, side by side, the goal and the result of every level of
the run:

``` r

read.csv(file.path(out, "runs", "E_shock", "P03_I-E-LAB", "all_levels.csv"))[, 1:13]
#>   row notation             name   block      g  level1_Gx level1_d_minus level1_d_plus  level1_x
#> 1   E      xD1   Entrant energy account   8.38   6.583151       1.796849          0.00        NA
#> 2   I      xD2 Incumbent energy account  29.00  29.000000       0.000000          0.00        NA
#> 3 LAB      xD3           Labour account 273.00 271.945491       1.054509          0.00        NA
#> 4  S1      f'1      Agriculture     ECO  70.00  70.000000       0.000000          0.00 100.23035
#> 5  S2      f'2         Industry     ECO  42.00  39.642493       2.357507          0.00  78.31513
#> 6  S3      f'3         Services     ECO  39.00  44.850000       0.000000          5.85  66.27879
#>    level2_Gx level2_d_minus level2_d_plus level2_x
#> 1   6.651815       1.728185      0.000000       NA
#> 2  29.000000       0.000000      0.000000       NA
#> 3 242.951285      30.048715      0.000000       NA
#> 4  63.000000       7.000000      0.000000 92.72909
#> 5  48.812589       0.000000      6.812589 85.18153
#> 6  33.150000       5.850000      0.000000 53.81572
```

The notation follows the system above: `xD_j` is the level of account
`j` (`D_j x`) and `f'_h` is row `h` of `(I - A) x`, the net output of
sector `h`, whose goal is its final demand.

### In Excel

`results.xlsx` (or `write_excel(res, "file.xlsx")`) holds the same
results in one workbook:

| Sheet | Content |
|----|----|
| `about` | the model, the scenarios, the orderings, the notation and what each sheet holds |
| `runs`, `levels`, `goals`, `states` | the four summary tables |
| `final_<scenario>` | the last level of every ordering, side by side: `g`, then `Gx`, `d_minus`, `d_plus` and `x` of each ordering |
| `Gx_<scenario>` | `g`, the `Gx` of each ordering and `Gx - g` |
| `x_<scenario>` | the base output `x0`, the output `x*` of each ordering and `delta_x` |
| `<scenario>_<ordering>` | one sheet per run: every row of `G` at every level, side by side |

``` r

readxl::excel_sheets(file.path(out, "results.xlsx"))
#>  [1] "about"         "runs"          "levels"        "goals"         "states"        "final_E_shock"
#>  [7] "Gx_E_shock"    "x_E_shock"     "final_I_shock" "Gx_I_shock"    "x_I_shock"     "E_shock_P01"  
#> [13] "E_shock_P02"   "E_shock_P03"   "E_shock_P04"   "E_shock_P05"   "E_shock_P06"   "I_shock_P01"  
#> [19] "I_shock_P02"   "I_shock_P03"   "I_shock_P04"   "I_shock_P05"   "I_shock_P06"
```

## The same model from files

A study is usually kept in files: a folder with the database (or an
`.xlsx` workbook) and a `model.yml` with the model.
[`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md)
writes this example in that format, with a commented `model.yml`, to be
copied and filled in with your own data.

``` r

study <- file.path(tempdir(), "my_study")
lexio_template(study)
list.files(study, recursive = TRUE)
#> [1] "base/corridor.csv" "base/E.csv"        "base/f.csv"        "base/sectors.csv" 
#> [5] "base/x.csv"        "base/Z.csv"        "model.yml"
res_files <- run_model(file.path(study, "model.yml"), verbose = FALSE)
identical(res_files$summary$runs$Z4, res$summary$runs$Z4)
#> [1] TRUE
```

## Next steps

- [`vignette("model-specification")`](https://filipevascrocha.github.io/lexio/articles/model-specification.md):
  every form of declaring the data, the goals, the scenarios and the
  priorities; the corridor; the outputs; and the numerical caveats of
  the method.
- [`vignette("miller-blair")`](https://filipevascrocha.github.io/lexio/articles/miller-blair.md):
  the goal programming example of Miller and Blair, with several goals
  per level and the economic block at the second level.
- [`vignette("thesis-replication")`](https://filipevascrocha.github.io/lexio/articles/thesis-replication.md):
  the model applied to the Brazilian electricity and fuel markets, with
  the 2018 input-output matrix.
