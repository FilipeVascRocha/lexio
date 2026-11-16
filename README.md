# lexio

<!-- badges: start -->
[![R-CMD-check](https://github.com/FilipeVascRocha/lexio/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/FilipeVascRocha/lexio/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

`lexio` is an R package for input-output models solved by preemptive
(lexicographic) goal programming. You declare an input-output database (the
technical structure, gross output, final demand, any number of satellite
accounts and, optionally, a corridor on the economic deviations) and, for each
account, a direction, a goal and a priority. The package chooses the sectoral
output that best meets the goals in priority order,

```
G x + d⁻ − d⁺ = g,     G = [ D ; I − A ],     x, d⁺, d⁻ ≥ 0,
```

solving each priority level as a linear program with GLPK and locking the
optima of the levels already solved. By default it runs every ordering of
the priorities and reports every level of every run, in tables and in an
Excel workbook.

## Installation

```r
# install.packages("remotes")
remotes::install_github("FilipeVascRocha/lexio")
```

On Linux, install GLPK first (for example, `sudo apt install libglpk-dev`).
The file `renv.lock` records the versions of R and of every package used to
develop and test the package; `renv::restore()` installs them.

## Example

```r
library(lexio)

# a three-sector database with three satellite accounts and a corridor
io <- example_io()

# the entrant energy is a floor, the incumbent a ceiling, labour should grow 5%;
# the entrant gets a shock of 5% of the joint base of the two energy sources
model <- define_model(
  accounts = list(
    E   = list(direction = ">=", target = list(type = "pooled_share", share = 0.05, pool = c("E", "I"))),
    I   = list(direction = "<=", target = list(type = "base")),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))
  )
)

res <- run_model(io, model)   # all 3! = 6 orderings, each with 4 priority levels
res
write_outputs(res, "results") # report, CSV tables and results.xlsx
```

## Documentation

- `vignette("lexio")`: get started, with a complete example.
- `vignette("model-specification")`: declaring the data, the goals, the
  scenarios and the priorities; the outputs; the numerical behaviour.
- `vignette("miller-blair")`: the goal programming example of Miller and
  Blair (2022), stage by stage.
- `vignette("thesis-replication")`: the application to the Brazilian
  electricity and fuel markets.

The documentation is also available at
<https://filipevascrocha.github.io/lexio/>, with Portuguese translations of
the vignettes.

## Replication of the thesis

The folder
[`replication/`](https://github.com/FilipeVascRocha/lexio/tree/main/replication)
of the repository reproduces the results of the thesis that introduced the
model (Rocha, 2026), from the 2018 Brazilian input-output matrix with
energy-sector detail published by EPE. See its
[README](https://github.com/FilipeVascRocha/lexio/blob/main/replication/README.md).

## Citation

```r
citation("lexio")
```

Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
Programming preemptivo aplicado à transição energética brasileira:
eletricidade e combustíveis na estrutura produtiva de 2018.* Doctoral thesis,
Programa de Pós-graduação em Economia, Universidade Federal de Juiz de Fora.

## Contributing

Questions and bug reports are welcome as
[issues](https://github.com/FilipeVascRocha/lexio/issues); see
[CONTRIBUTING.md](CONTRIBUTING.md). Please note that this project is released
with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By contributing to
this project, you agree to abide by its terms.

## License

MIT. See [LICENSE.md](LICENSE.md).
