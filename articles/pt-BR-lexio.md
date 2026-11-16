# Primeiros passos com o lexio

*Tradução de
[`vignette("lexio")`](https://filipevascrocha.github.io/lexio/articles/lexio.md).
Os nomes de funções, argumentos, arquivos e colunas são os do pacote, em
inglês.*

O `lexio` roda um modelo de insumo-produto resolvido por Goal
Programming preemptivo (lexicográfico). Você declara uma base de
insumo-produto que já tem e, para cada conta satélite (energia, emprego,
emissões, …), uma direção, uma meta e uma prioridade. O pacote escolhe a
produção setorial que melhor atende às metas, na ordem de prioridade, em
todas as ordens de prioridade, e grava todos os resultados.

Este texto roda um exemplo completo numa base de três setores. Os outros
textos tratam da especificação completa ([Declarar dados e
modelos](https://filipevascrocha.github.io/lexio/articles/pt-BR-model-specification.md)),
do exemplo de Goal Programming de Miller e Blair ([O exemplo de Miller e
Blair](https://filipevascrocha.github.io/lexio/articles/pt-BR-miller-blair.md))
e da replicação da tese que apresentou o modelo ([Replicar a
tese](https://filipevascrocha.github.io/lexio/articles/pt-BR-thesis-replication.md)).

## O modelo

Com `n` setores e `k` contas satélite, as metas formam o sistema

``` math
G x + d^- - d^+ = g, \qquad
G = \begin{bmatrix} D \\ I - A \end{bmatrix}, \qquad
x,\ d^+,\ d^- \ge 0 .
```

- `x` é a produção (valor bruto da produção) de cada setor, a variável
  de decisão.
- As `k` primeiras linhas são as contas satélite. `D` traz os
  coeficientes de cada conta por unidade de produção, então `D_j x` é o
  nível da conta `j` e `b_j = D_j x_0` é a sua base.
- As `n` últimas linhas formam o bloco econômico, ECO: `(I - A) x`
  contra a demanda final `f`.
- `d^-` e `d^+` são os desvios abaixo e acima de cada meta `g`.

Cada conta tem uma **direção**. Um piso (`">="`) penaliza a falta `d^-`,
um teto (`"<="`) penaliza o excesso `d^+` e um alvo (`"="`) penaliza os
dois. Por padrão, o ECO é um piso sobre a demanda final.

As metas são atendidas em **ordem de prioridade**. Cada nível de
prioridade é um programa linear, resolvido com o GLPK, que minimiza os
desvios penalizados das suas metas; o seu ótimo fica então travado nos
níveis seguintes. Como a ordem importa, o pacote roda, por padrão, todas
as `k!` ordens das contas, com o ECO preso no último nível.

Opcionalmente, um **corredor** limita os desvios econômicos:
`d_h^-, d_h^+ <= alpha_h |g_h|`, em que `alpha_h` é uma proporção
declarada para cada setor.

## Uma primeira rodada

### 1. Declarar a base

A base tem três setores. `Z` traz os fluxos intermediários (linha =
setor que vende, coluna = setor que compra), `x` o valor bruto da
produção e `f` a demanda final. Cada conta satélite é dada pelo seu
nível em cada setor: uma fonte de energia entrante `E` e uma incumbente
`I` (em tep) e o trabalho `LAB` (em ocupações). `alpha` é o corredor de
cada setor.

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

O
[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
recebe cada objeto com o nome do que ele é: `Z =` para os fluxos (`A =`
ou `B =` para coeficientes técnicos), `E =` para os níveis das contas
(`D =` para coeficientes) e `corridor =` para o corredor. O pacote
calcula `A = Z x^-1`, `B = I - A` e `D = E x^-1`.

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

A impressão mostra como a base foi declarada, o modo do corredor e a
base `b_j = D_j x` de cada conta. `validate_io(io)` dá o relatório
completo das conferências de consistência.

### 2. Declarar o modelo

A energia entrante é um piso, a incumbente um teto e o trabalho um piso
que deve crescer 5%. Dois cenários dão um choque igual a 5% da base
conjunta das duas fontes de energia, à entrante ou à incumbente.

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

A meta de cada conta é calculada a partir da sua base. No cenário
`E_shock`, a meta de `E` é `b_E + 0,05 (b_E + b_I)`, a meta de `I` é a
sua base e a meta de `LAB` é `1,05 b_LAB`. As metas do bloco econômico
são a demanda final. O
[`build_goals()`](https://filipevascrocha.github.io/lexio/reference/build_goals.md)
devolve o vetor `g` inteiro:

``` r

build_goals(io, model, "E_shock")
#> [1]   8.38  29.00 273.00  70.00  42.00  39.00
```

Com três contas há `3! = 6` ordens, de `P01` a `P06`, cada uma com
quatro níveis: as três contas, na sequência da ordem, e o ECO.

### 3. Rodar

``` r

res <- run_model(io, model, verbose = FALSE)
res
#> <lexio_results> toy | 3 sectors | 3 account(s): E, I, LAB | corridor: two-sided corridor 
#>   scenario E_shock        6 ordering(s) | all optimal | 3 distinct state(s)
#>   scenario I_shock        6 ordering(s) | all optimal | 1 distinct state(s)
#>   distinct states in total: 4 
#>   write everything with write_outputs(res, "folder")
```

O modelo rodou 12 vezes: 2 cenários e 6 ordens. Um *estado* é uma
solução final `x*`; ordens diferentes podem levar ao mesmo estado.

## Ler os resultados

### No R

`res$summary` traz quatro tabelas. `runs` tem uma linha por rodada: o
status do GLPK em cada nível (`0` = ótimo), o ótimo `Z` de cada nível, a
variação da produção total e a variação de cada conta.

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

`levels` tem uma linha por nível de prioridade de cada rodada, `goals`
uma linha por conta de cada rodada (base, meta, valor alcançado) e
`states` uma linha por solução distinta.

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

A impressão de uma rodada mostra cada nível e cada conta:

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

### Em arquivos

O
[`write_outputs()`](https://filipevascrocha.github.io/lexio/reference/write_outputs.md)
grava todos os resultados numa pasta: um relatório (`README.md`), uma
planilha Excel (`results.xlsx`), as tabelas em CSV e, para cada rodada,
uma pasta com os resultados de cada nível.

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

O `all_levels.csv` tem uma linha por linha de `G` (as contas, depois os
setores) e, lado a lado, a meta e o resultado de cada nível da rodada:

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

A notação segue o sistema acima: `xD_j` é o nível da conta `j` (`D_j x`)
e `f'_h` é a linha `h` de `(I - A) x`, a produção líquida do setor `h`,
cuja meta é a sua demanda final.

### No Excel

O `results.xlsx` (ou `write_excel(res, "arquivo.xlsx")`) traz os mesmos
resultados numa só planilha:

| Aba | Conteúdo |
|----|----|
| `about` | o modelo, os cenários, as ordens, a notação e o que cada aba traz |
| `runs`, `levels`, `goals`, `states` | as quatro tabelas de resumo |
| `final_<cenário>` | o último nível de todas as ordens, lado a lado: `g` e, de cada ordem, `Gx`, `d_minus`, `d_plus` e `x` |
| `Gx_<cenário>` | `g`, o `Gx` de cada ordem e `Gx - g` |
| `x_<cenário>` | a produção base `x0`, a produção `x*` de cada ordem e `delta_x` |
| `<cenário>_<ordem>` | uma aba por rodada: cada linha de `G` em cada nível, lado a lado |

``` r

readxl::excel_sheets(file.path(out, "results.xlsx"))
#>  [1] "about"         "runs"          "levels"        "goals"         "states"        "final_E_shock"
#>  [7] "Gx_E_shock"    "x_E_shock"     "final_I_shock" "Gx_I_shock"    "x_I_shock"     "E_shock_P01"  
#> [13] "E_shock_P02"   "E_shock_P03"   "E_shock_P04"   "E_shock_P05"   "E_shock_P06"   "I_shock_P01"  
#> [19] "I_shock_P02"   "I_shock_P03"   "I_shock_P04"   "I_shock_P05"   "I_shock_P06"
```

## O mesmo modelo a partir de arquivos

Um estudo costuma ficar em arquivos: uma pasta com a base (ou uma
planilha `.xlsx`) e um `model.yml` com o modelo. O
[`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md)
grava este exemplo nesse formato, com um `model.yml` comentado, para ser
copiado e preenchido com os seus dados.

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

## Próximos passos

- [Declarar dados e
  modelos](https://filipevascrocha.github.io/lexio/articles/pt-BR-model-specification.md):
  todas as formas de declarar os dados, as metas, os cenários e as
  prioridades; o corredor; as saídas; e as cautelas numéricas do método.
- [O exemplo de Miller e
  Blair](https://filipevascrocha.github.io/lexio/articles/pt-BR-miller-blair.md):
  níveis com várias metas e o bloco econômico no segundo nível.
- [Replicar a
  tese](https://filipevascrocha.github.io/lexio/articles/pt-BR-thesis-replication.md):
  o modelo aplicado aos mercados brasileiros de eletricidade e de
  combustíveis, com a matriz de insumo-produto de 2018.
