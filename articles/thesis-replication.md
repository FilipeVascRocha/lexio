# Replicating the thesis

The model of `lexio` was introduced in Rocha (2026), which applies it to
two energy markets of Brazil with the 2018 input-output matrix with
energy-sector detail published by EPE and FIPE (72 sectors). This
vignette shows how that application is declared and run. The code is not
run when the vignette is built, because the data are distributed apart
from the package; the folder `replication/` of the repository
(<https://github.com/FilipeVascRocha/lexio>) runs everything, as
described in its `README.md`.

## The application

| Market | Entrant (`>=`) | Incumbent (`<=`) | Labour (`>=`) | Shock |
|----|----|----|----|----|
| Electricity | GD, distributed generation | GC, centralized generation | LAB, +1% | 1% of `b_GD + b_GC`, to GD or to GC |
| Fuels | CR, biodiesel + ethanol | CNR, petroleum products + natural gas | LAB, +5% | 5% of `b_CR + b_CNR`, to CR or to CNR |

- The entrant energy is a floor and the incumbent a ceiling: the entrant
  should not fall below its goal and the incumbent should not exceed its
  goal.
- Each scenario gives the shock to one of the two energy sources; the
  other keeps its base, and labour grows by the share of the shock.
- The economic block is `(I − A) x ≥ f`, at the last level, with
  absolute deviations.
- The corridor `α_h` is the intersectoral purchase of the energy
  products of the market divided by the output of sector `h`, on both
  sides.
- The six orderings of the three accounts are run in each scenario, with
  the exact lock: 2 markets × 2 scenarios × 6 orderings = 24 runs of 4
  levels.

## The data

The database is the file `lexio-thesis-data-2018.zip`, attached to the
GitHub release of `lexio` and archived on Zenodo
(<https://doi.org/10.5281/zenodo.24293808>);
`replication/01_declare_data.R` builds the same files from the public
workbook of EPE. The file also holds a dictionary of every file and
column (`thesis_data/metadata.xlsx`) and the EPE workbook itself,
unchanged (`data/`), so that the database can be rebuilt even if the
workbook leaves the EPE site. For each market:

    thesis_data/fuels/
      base/            sectors, Z, x, f, E (levels of CR, CNR and LAB) and corridor, as published
      model.yml        the model, with the goals declared by their rules
      coefficients/    B = I - A, D, x, f and corridor, rounded to 15 significant digits
      model_exact.yml  the same model, with the goals rounded in the same way

The thesis stored the coefficients and the goals with 15 significant
digits between its steps. `coefficients/` and `model_exact.yml` keep
that rounding, so the problem is identical to the one solved in the
thesis; `base/` and `model.yml` give the same numbers up to about 1e-9.

## Declaring the fuels model in R

The coefficients, read into vectors:

``` r

library(lexio)
dir <- "replication/thesis_data/fuels/coefficients"
read_table <- function(name) {
  read.csv(file.path(dir, paste0(name, ".csv")), check.names = FALSE, colClasses = c(code = "character"))
}
sectors <- read_table("sectors")
B <- as.matrix(read_table("B")[, -1])
x <- read_table("x")$value
f <- read_table("f")$value
D <- read_table("D")
alpha <- read_table("corridor")$alpha

io <- declare_io(B = B, x = x, f = f,
                 D = list(CR = D$CR, CNR = D$CNR, LAB = D$LAB),
                 corridor = alpha, sectors = sectors)
io
```

The model: the directions, the goals of the two scenarios and the six
orderings.

``` r

shock <- list(type = "pooled_share", share = 0.05, pool = c("CR", "CNR"))
model <- define_model(
  accounts = list(
    CR  = list(direction = ">=", target = list(type = "base"), unit = "toe"),
    CNR = list(direction = "<=", target = list(type = "base"), unit = "toe"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05), unit = "jobs")
  ),
  economy = list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute"),
  scenarios = list(CR = list(CR = shock), CNR = list(CNR = shock)),
  priorities = "all",
  corridor = list(use = TRUE, multiplier = 1),
  lock_tolerance = "exact",
  name = "thesis_fuels"
)
```

The goal of each account is its total level in the scenario, not the
shock alone. With the bases `b_CR = 19,882,543` toe,
`b_CNR = 110,028,128` toe and `b_LAB = 97,776,839` jobs, the shock is
`0.05 × (b_CR + b_CNR) = 6,495,534` toe, and

| Scenario | Goal of CR | Goal of CNR | Goal of LAB |
|----|----|----|----|
| `CR` | 26,378,077 (base + shock) | 110,028,128 (base) | 102,665,681 (base × 1.05) |
| `CNR` | 19,882,543 (base) | 116,523,662 (base + shock) | 102,665,681 |

`satellite_base(io)` and `build_goals(io, model, "CR")` return these
numbers.

## Running and reading the results

``` r

res <- run_model(io, model)
res
write_outputs(res, "outputs_fuels")
```

`results.xlsx`, in the output folder, holds every result. Its result
sheets have one row per row of `G`: `xD1`, `xD2` and `xD3` (CR, CNR and
LAB) and `f'1` to `f'72` (the sectors).

| Result | Sheet |
|----|----|
| the last level of the six orderings, side by side (`g`; `Gx`, `d_minus`, `d_plus` and `x` of each ordering) | `final_CR`, `final_CNR` |
| every level (stage) of one ordering, side by side | `CR_P01` … `CNR_P06` |
| `Gx − g` | `Gx_CR`, `Gx_CNR` |
| sectoral output `x*` and `Δx` | `x_CR`, `x_CNR` |
| the optimum of each level and the change in each account | `runs` |
| base, goal and achieved value of each account | `goals` |
| the distinct final states | `states` |

The orderings `P01` to `P06` are, for the fuels market, CR-CNR-LAB,
CR-LAB-CNR, CNR-CR-LAB, CNR-LAB-CR, LAB-CR-CNR and LAB-CNR-CR, each
followed by the economic block.

## The published numbers

`replication/02_reproduce.R` runs both markets with `coefficients/` and
`model_exact.yml` and compares 12 indicators with the values printed in
the thesis:

| Number                                       | Published                 |
|----------------------------------------------|---------------------------|
| Largest share of the shock realized by GD    | 31.0%                     |
| Largest share of the shock realized by CR    | 27.2%                     |
| Co-movement at the frontier, GC per GD       | 6.06 toe/toe              |
| Co-movement at the frontier, CNR per CR      | 4.42 toe/toe              |
| Fuels frontier: change in output             | R\$ 284.8 billion (2.39%) |
| Fuels frontier: change in jobs               | 1.72 million              |
| State with CNR at its goal: change in output | R\$ 254.4 billion (2.13%) |
| State with CNR at its goal: change in jobs   | 1.63 million              |
| Distinct states: electricity, fuels          | 5, 4                      |

The script ends with `12 of 12 published numbers match` and with every
level of the 24 runs optimal. The model declared above, with the goals
written as rules, gives the same 9 fuels numbers.

## Reference

Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
Programming preemptivo aplicado à transição energética brasileira:
eletricidade e combustíveis na estrutura produtiva de 2018.* Doctoral
thesis, Programa de Pós-graduação em Economia, Universidade Federal de
Juiz de Fora.
