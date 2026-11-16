# Replication of the thesis with lexio

*Versão em português: [README.pt-BR.md](README.pt-BR.md).*

This folder reproduces the results of

> Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
> Programming preemptivo aplicado à transição energética brasileira:
> eletricidade e combustíveis na estrutura produtiva de 2018.* Doctoral
> thesis, Programa de Pós-graduação em Economia, Universidade Federal de Juiz
> de Fora.

with the R package `lexio`. It runs the model of the thesis in its two
markets, writes every result (every account and every sector, in every
ordering of the priorities and at every priority level) and checks the
numbers published in the thesis.

| Market | Entrant (`>=`) | Incumbent (`<=`) | Labour (`>=`) | Shock |
|---|---|---|---|---|
| Electricity | GD, distributed generation | GC, centralized generation | LAB, +1% | 1% of `b_GD + b_GC`, to GD (scenario `GD`) or to GC (scenario `GC`) |
| Fuels | CR, biodiesel + ethanol | CNR, petroleum products + natural gas | LAB, +5% | 5% of `b_CR + b_CNR`, to CR (scenario `CR`) or to CNR (scenario `CNR`) |

In both markets the economic block is `(I − A) x ≥ f`, at the last priority
level, with a two-sided corridor; the six orderings of the three accounts
(`P01` to `P06`, P1 to P6 in the thesis) are run in each scenario: 24 runs,
each with 4 priority levels.

## Requirements

- R 4.0 or later (the results were produced with R 4.4.3).
- The package `lexio`, installed from GitHub,
  `remotes::install_github("FilipeVascRocha/lexio")`, or from the root of
  this repository, `install.packages(".", repos = NULL, type = "source")`.
- The packages `here` and `digest`, and `readxl` for `01_declare_data.R`.
- For the exact versions of every package, run `renv::restore()` at the root
  of the repository (`renv.lock`).

## Data

The scripts read `replication/thesis_data/`. The first script you run
downloads it if it is missing: it is the file `lexio-thesis-data-2018.zip`,
attached to the release v1.0.0 of `lexio`
(<https://github.com/FilipeVascRocha/lexio/releases/tag/v1.0.0>) and archived
on Zenodo (<https://doi.org/10.5281/zenodo.24293808>), unzipped in this
folder. The script downloads it from GitHub and, if that fails, from Zenodo;
it checks the SHA-256 of the file and unzips nothing if it is not the one
below.

- SHA-256 of `lexio-thesis-data-2018.zip`:
  `36e109d140be7661554b857385d836fa8e3831317377e8cc1f134d9cb60f3ecc`.

The file holds two folders, which land in `replication/`:

- `thesis_data/`: the declared database (described below), with
  `README.md`, `README.pt-BR.md` and `metadata.xlsx`, a dictionary of every
  file and column, in English and Portuguese;
- `data/`: the EPE workbook `MIP_EPE_Divulgacao.xlsx`, unchanged (SHA-256
  `154e61f559dd60d30b140e00fbe6c0b81766ca347e9b7ad11160b2c6685e7c1e`), kept so
  that the database can be rebuilt even if the workbook leaves the EPE site.

The data come from the input-output matrix of Brazil with energy-sector
detail, base year 2018, published by EPE (Empresa de Pesquisa Energética) and
built with FIPE. `01_declare_data.R` builds the same files from the public
workbook `MIP_EPE_Divulgação.xlsx` (sheet "Usos SxS"), which it reads from
`replication/data/` when no path is given:

- EPE. *Nota Técnica — Matriz Insumo Produto com detalhamento do setor
  energético: notas e tabelas auxiliares.* Rio de Janeiro: EPE, 2026.
  <https://www.epe.gov.br/pt/publicacoes-dados-abertos/publicacoes/nota-tecnica-matriz-insumo-produto-com-detalhamento-do-setor-energetico-notas-e-tabelas-auxiliares>
- EPE; FIPE. *Metodologia para construção de uma Matriz Insumo-Produto com
  detalhamento dos setores energéticos.* Nota Técnica conjunta. Rio de
  Janeiro: EPE, Dec. 2023.

Each market folder holds the database as published (`base/`: `Z`, `x`, `f`,
the levels `E` and the corridor `alpha`, with every digit) and the
coefficients and goals rounded to 15 significant digits, as stored in the
computations of the thesis (`coefficients/` and `model_exact.yml`). The
`README.md` inside the `.zip` lists the rows and columns used.

## How to run

From the root of the repository, in RStudio (open `lexio.Rproj`, open the
script and click *Source*) or in a terminal:

```sh
Rscript replication/02_reproduce.R   # every run of the thesis, every result, the published numbers
Rscript replication/electricity.R    # the electricity model, declared step by step in R code
Rscript replication/fuels.R          # the fuels model, declared step by step in R code
```

| Script | What it does |
|---|---|
| `01_declare_data.R` | optional: builds `thesis_data/` from the EPE workbook (in `replication/data/`, where the release file puts it, or at the path you give) |
| `02_reproduce.R` | runs the 24 runs with `coefficients/` + `model_exact.yml` (the problem solved in the thesis), writes every result, checks the 12 published numbers and compares with the database as published (`base/` + `model.yml`) |
| `electricity.R`, `fuels.R` | declare the database and the model in R code (`declare_io()`, `define_model()`), with the goals written as rules (a share of the pooled base), run the six orderings of each scenario and print every run, level by level |

Each script runs in a few seconds.

`pt-BR/` holds copies of `electricity.R` and `fuels.R` with comments in
Portuguese. Each run writes to a new folder, so nothing is overwritten:
`replication/outputs`, `replication/outputs_2`, ... (and
`outputs_electricity`, `outputs_fuels`).

## What comes out

`02_reproduce.R` ends with

```
12 of 12 published numbers match.
Runs of the thesis with every level optimal: 24 of 24.
```

and writes

```
replication/outputs/
  fuels/                  every result of the fuels market (see below)
  electricity/            every result of the electricity market
  published_numbers.csv   the 12 published numbers, reconstructed
  flows_check.csv         the same runs with the database as published (base/ + model.yml)
```

In `flows_check.csv`, the runs with the database as published differ from
the runs of the thesis by less than 1e-9 (relative) in every number. GLPK
reports the last level of 4 electricity runs as not optimal there, a
numerical false infeasibility of the exact lock described in
`vignette("model-specification", package = "lexio")`, section 7; their
numbers agree all the same.

Each market folder is the output of `lexio::write_outputs()`: a report
(`README.md`), the Excel workbook `results.xlsx` and the same tables in CSV
files. In the workbook, the rows of the result sheets are the rows of `G` in
the notation of the thesis: `xD1`, `xD2`, `xD3` (the accounts: entrant,
incumbent, labour) and `f'1` to `f'72` (the 72 sectors).

| Result of the thesis | Sheet of `results.xlsx` | Columns |
|---|---|---|
| The final result of the six orderings, for the accounts and the sectors | `final_<scenario>` | `g`, then `P0k_Gx`, `P0k_d_minus`, `P0k_d_plus`, `P0k_x` for each ordering |
| Each stage (priority level) of each ordering | `<scenario>_P0k` | `g`, then `level<l>_Gx`, `level<l>_d_minus`, `level<l>_d_plus`, `level<l>_x` for levels 1 to 4 |
| Achieved value minus goal, `Gx − g` | `Gx_<scenario>` | `P0k_Gx` and `P0k_Gx_minus_g` |
| Sectoral output `x*` and its change `Δx` | `x_<scenario>` | `x0`, `P0k_x`, `P0k_delta_x` |
| Optimum of each level, GLPK status, change in total output and in each account | `runs` | `Z1` to `Z4`, `status`, `delta_x`, `delta_<account>` |
| Each level of each run | `levels` | `goals`, `Z`, `status_glpk` |
| Base, goal (base + shock) and achieved value of each account in each run | `goals` | `base`, `g`, `Gx`, `realized` |
| Distinct final states | `states` | the runs of each state |

The scenarios are named after the account that receives the shock (`CR` and
`CNR`; `GD` and `GC`). The orderings are, in each market (entrant, incumbent,
labour):

| | P01 | P02 | P03 | P04 | P05 | P06 |
|---|---|---|---|---|---|---|
| Electricity | GD-GC-LAB | GD-LAB-GC | GC-GD-LAB | GC-LAB-GD | LAB-GD-GC | LAB-GC-GD |
| Fuels | CR-CNR-LAB | CR-LAB-CNR | CNR-CR-LAB | CNR-LAB-CR | LAB-CR-CNR | LAB-CNR-CR |

ECO, the economic block, is the fourth level of every ordering. The sheet
`about` of each workbook describes every sheet and column.

## The published numbers

| Number | Published |
|---|---|
| Largest share of the shock realized by GD | 31.0% |
| Largest share of the shock realized by CR | 27.2% |
| Co-movement at the frontier, GC per GD | 6.06 toe/toe |
| Co-movement at the frontier, CNR per CR | 4.42 toe/toe |
| Fuels frontier: change in output | R$ 284.8 billion (2.39%) |
| Fuels frontier: change in jobs | 1.72 million |
| State with CNR at its goal: change in output | R$ 254.4 billion (2.13%) |
| State with CNR at its goal: change in jobs | 1.63 million |
| Distinct states: electricity, fuels | 5, 4 |

`published_numbers.csv` gives each one with its reconstructed value, rounded
as printed in the thesis. `R/thesis_helpers.R` computes them from the runs.

## Files

```
replication/
  README.md, README.pt-BR.md
  01_declare_data.R       the database, from the EPE workbook
  02_reproduce.R          every run of the thesis and the published numbers
  electricity.R, fuels.R  the two models, declared step by step
  pt-BR/                  the two scripts with comments in Portuguese
  R/thesis_helpers.R      data download, indicators and published numbers
```
