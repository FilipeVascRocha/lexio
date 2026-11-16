# Replicação da tese com o lexio

*English version: [README.md](README.md).*

Esta pasta reproduz os resultados de

> Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
> Programming preemptivo aplicado à transição energética brasileira:
> eletricidade e combustíveis na estrutura produtiva de 2018.* Tese de
> doutorado, Programa de Pós-graduação em Economia, Universidade Federal de
> Juiz de Fora.

com o pacote R `lexio`. Ela roda o modelo da tese nos seus dois mercados,
grava todos os resultados (cada conta e cada setor, em cada ordem de
prioridade e em cada nível de prioridade) e confere os números publicados na
tese.

| Mercado | Entrante (`>=`) | Incumbente (`<=`) | Trabalho (`>=`) | Choque |
|---|---|---|---|---|
| Eletricidade | GD, geração distribuída | GC, geração centralizada | LAB, +1% | 1% de `b_GD + b_GC`, para a GD (cenário `GD`) ou para a GC (cenário `GC`) |
| Combustíveis | CR, biodiesel + etanol | CNR, derivados de petróleo + gás natural | LAB, +5% | 5% de `b_CR + b_CNR`, para os CR (cenário `CR`) ou para os CNR (cenário `CNR`) |

Nos dois mercados, o bloco econômico é `(I − A) x ≥ f`, no último nível de
prioridade, com corredor dos dois lados; as seis ordens das três contas
(`P01` a `P06`, P1 a P6 na tese) rodam em cada cenário: 24 rodadas, cada uma
com 4 níveis de prioridade.

## Requisitos

- R 4.0 ou mais recente (os resultados foram produzidos com o R 4.4.3).
- O pacote `lexio`, instalado do GitHub,
  `remotes::install_github("FilipeVascRocha/lexio")`, ou da raiz deste
  repositório, `install.packages(".", repos = NULL, type = "source")`.
- Os pacotes `here` e `digest`, e o `readxl` para o `01_declare_data.R`.
- Para as versões exatas de todos os pacotes, rode `renv::restore()` na raiz
  do repositório (`renv.lock`).

## Dados

Os scripts leem `replication/thesis_data/`. O primeiro script que você rodar
baixa a pasta, se ela não existir: é o arquivo `lexio-thesis-data-2018.zip`,
anexado à *release* v1.0.0 do `lexio`
(<https://github.com/FilipeVascRocha/lexio/releases/tag/v1.0.0>) e arquivado
no Zenodo (<https://doi.org/10.5281/zenodo.24293808>), descompactado nesta
pasta. O script baixa o arquivo do GitHub e, se não conseguir, do Zenodo;
ele confere o SHA-256 do arquivo e não descompacta nada se não for o de
baixo.

- SHA-256 do `lexio-thesis-data-2018.zip`:
  `36e109d140be7661554b857385d836fa8e3831317377e8cc1f134d9cb60f3ecc`.

O arquivo tem duas pastas, que vão para `replication/`:

- `thesis_data/`: a base declarada (descrita abaixo), com `README.md`,
  `README.pt-BR.md` e `metadata.xlsx`, um dicionário de todos os arquivos e
  colunas, em inglês e em português;
- `data/`: a planilha da EPE `MIP_EPE_Divulgacao.xlsx`, sem nenhuma alteração
  (SHA-256
  `154e61f559dd60d30b140e00fbe6c0b81766ca347e9b7ad11160b2c6685e7c1e`), guardada
  para que a base possa ser refeita mesmo que a planilha saia do site da EPE.

Os dados vêm da matriz de insumo-produto do Brasil com detalhamento do setor
energético, ano-base 2018, publicada pela EPE (Empresa de Pesquisa
Energética) e construída com a FIPE. O `01_declare_data.R` monta os mesmos
arquivos a partir da planilha pública `MIP_EPE_Divulgação.xlsx` (aba
"Usos SxS"), que ele lê em `replication/data/` quando nenhum caminho é dado:

- EPE. *Nota Técnica — Matriz Insumo Produto com detalhamento do setor
  energético: notas e tabelas auxiliares.* Rio de Janeiro: EPE, 2026.
  <https://www.epe.gov.br/pt/publicacoes-dados-abertos/publicacoes/nota-tecnica-matriz-insumo-produto-com-detalhamento-do-setor-energetico-notas-e-tabelas-auxiliares>
- EPE; FIPE. *Metodologia para construção de uma Matriz Insumo-Produto com
  detalhamento dos setores energéticos.* Nota Técnica conjunta. Rio de
  Janeiro: EPE, dez. 2023.

A pasta de cada mercado traz a base como publicada (`base/`: `Z`, `x`, `f`,
os níveis `E` e o corredor `alpha`, com todos os dígitos) e os coeficientes e
as metas arredondados a 15 algarismos significativos, como guardados nas
contas da tese (`coefficients/` e `model_exact.yml`). O `README.md` dentro do
`.zip` lista as linhas e colunas usadas.

## Como rodar

Na raiz do repositório, no RStudio (abra o `lexio.Rproj`, abra o script e
clique em *Source*) ou num terminal:

```sh
Rscript replication/02_reproduce.R   # todas as rodadas da tese, todos os resultados, os números publicados
Rscript replication/electricity.R    # o modelo da eletricidade, declarado passo a passo em código R
Rscript replication/fuels.R          # o modelo dos combustíveis, declarado passo a passo em código R
```

| Script | O que faz |
|---|---|
| `01_declare_data.R` | opcional: monta `thesis_data/` a partir da planilha da EPE (em `replication/data/`, onde o arquivo da *release* a coloca, ou no caminho que você informar) |
| `02_reproduce.R` | roda as 24 rodadas com `coefficients/` + `model_exact.yml` (o problema resolvido na tese), grava todos os resultados, confere os 12 números publicados e compara com a base como publicada (`base/` + `model.yml`) |
| `electricity.R`, `fuels.R` | declaram a base e o modelo em código R (`declare_io()`, `define_model()`), com as metas escritas como regras (uma fração da base conjunta), rodam as seis ordens de cada cenário e mostram cada rodada, nível a nível |

Cada script roda em poucos segundos.

A pasta `pt-BR/` traz cópias do `electricity.R` e do `fuels.R` com os
comentários em português. Cada execução grava numa pasta nova, então nada é
sobrescrito: `replication/outputs`, `replication/outputs_2`, ... (e
`outputs_electricity`, `outputs_fuels`).

## O que sai

O `02_reproduce.R` termina com

```
12 of 12 published numbers match.
Runs of the thesis with every level optimal: 24 of 24.
```

e grava

```
replication/outputs/
  fuels/                  todos os resultados dos combustíveis (veja abaixo)
  electricity/            todos os resultados da eletricidade
  published_numbers.csv   os 12 números publicados, reconstruídos
  flows_check.csv         as mesmas rodadas com a base como publicada (base/ + model.yml)
```

No `flows_check.csv`, as rodadas com a base como publicada diferem das
rodadas da tese em menos de 1e-9 (relativo) em todos os números. O GLPK
acusa como não ótimo o último nível de 4 rodadas da eletricidade nesse caso,
uma falsa inviabilidade numérica da trava exata descrita em
`vignette("model-specification", package = "lexio")`, seção 7; os números
conferem do mesmo jeito.

A pasta de cada mercado é a saída do `lexio::write_outputs()`: um relatório
(`README.md`), a planilha Excel `results.xlsx` e as mesmas tabelas em CSV. Na
planilha, as linhas das abas de resultados são as linhas de `G` na notação da
tese: `xD1`, `xD2`, `xD3` (as contas: entrante, incumbente, trabalho) e `f'1`
a `f'72` (os 72 setores).

| Resultado da tese | Aba do `results.xlsx` | Colunas |
|---|---|---|
| O resultado final das seis ordens, para as contas e os setores | `final_<cenário>` | `g` e, de cada ordem, `P0k_Gx`, `P0k_d_minus`, `P0k_d_plus`, `P0k_x` |
| Cada etapa (nível de prioridade) de cada ordem | `<cenário>_P0k` | `g` e, dos níveis 1 a 4, `level<l>_Gx`, `level<l>_d_minus`, `level<l>_d_plus`, `level<l>_x` |
| Valor alcançado menos a meta, `Gx − g` | `Gx_<cenário>` | `P0k_Gx` e `P0k_Gx_minus_g` |
| Produção setorial `x*` e a sua variação `Δx` | `x_<cenário>` | `x0`, `P0k_x`, `P0k_delta_x` |
| Ótimo de cada nível, status do GLPK, variação da produção total e de cada conta | `runs` | `Z1` a `Z4`, `status`, `delta_x`, `delta_<conta>` |
| Cada nível de cada rodada | `levels` | `goals`, `Z`, `status_glpk` |
| Base, meta (base + choque) e valor alcançado de cada conta em cada rodada | `goals` | `base`, `g`, `Gx`, `realized` |
| Estados finais distintos | `states` | as rodadas de cada estado |

Os cenários têm o nome da conta que recebe o choque (`CR` e `CNR`; `GD` e
`GC`). As ordens são, em cada mercado (entrante, incumbente, trabalho):

| | P01 | P02 | P03 | P04 | P05 | P06 |
|---|---|---|---|---|---|---|
| Eletricidade | GD-GC-LAB | GD-LAB-GC | GC-GD-LAB | GC-LAB-GD | LAB-GD-GC | LAB-GC-GD |
| Combustíveis | CR-CNR-LAB | CR-LAB-CNR | CNR-CR-LAB | CNR-LAB-CR | LAB-CR-CNR | LAB-CNR-CR |

O ECO, o bloco econômico, é o quarto nível de todas as ordens. A aba `about`
de cada planilha descreve cada aba e cada coluna.

## Os números publicados

| Número | Publicado |
|---|---|
| Maior fração do choque realizada pela GD | 31,0% |
| Maior fração do choque realizada pelos CR | 27,2% |
| Comovimento na fronteira, GC por GD | 6,06 tep/tep |
| Comovimento na fronteira, CNR por CR | 4,42 tep/tep |
| Fronteira dos combustíveis: variação da produção | R$ 284,8 bilhões (2,39%) |
| Fronteira dos combustíveis: variação das ocupações | 1,72 milhão |
| Estado com os CNR na meta: variação da produção | R$ 254,4 bilhões (2,13%) |
| Estado com os CNR na meta: variação das ocupações | 1,63 milhão |
| Estados distintos: eletricidade, combustíveis | 5, 4 |

O `published_numbers.csv` traz cada um com o seu valor reconstruído,
arredondado como impresso na tese. O `R/thesis_helpers.R` os calcula a partir
das rodadas.

## Arquivos

```
replication/
  README.md, README.pt-BR.md
  01_declare_data.R       a base, a partir da planilha da EPE
  02_reproduce.R          todas as rodadas da tese e os números publicados
  electricity.R, fuels.R  os dois modelos, declarados passo a passo
  pt-BR/                  os dois scripts com comentários em português
  R/thesis_helpers.R      download dos dados, indicadores e números publicados
```
