# Declarar dados e modelos

*Tradução de
[`vignette("model-specification")`](https://filipevascrocha.github.io/lexio/articles/model-specification.md).
Os nomes de funções, argumentos, chaves do `model.yml`, arquivos e
colunas são os do pacote, em inglês.*

Este texto descreve cada parte de um estudo com o `lexio`: a notação, a
declaração da base, as metas e os cenários, as prioridades, as saídas e
o comportamento numérico do método. [Primeiros
passos](https://filipevascrocha.github.io/lexio/articles/pt-BR-lexio.md)
roda antes um exemplo completo.

## 1. Notação

A notação segue Rocha (2026, seção 4.2). Com `n` setores e `k` contas
satélite:

| Símbolo | Significado | No lexio |
|----|----|----|
| `Z` (n × n) | consumo intermediário: linha = setor que vende, coluna = setor que compra | `declare_io(Z = )`, arquivo `Z` |
| `x` (n) | valor bruto da produção | `declare_io(x = )`, arquivo `x` |
| `f` (n) | demanda final | `declare_io(f = )`, arquivo `f` |
| `A = Z x̂⁻¹` | coeficientes técnicos (por coluna) | calculada a partir de `Z`, ou `declare_io(A = )` |
| `B = I − A` |  | calculada, ou `declare_io(B = )`; `io$B` |
| `E_j` (n) | nível da conta satélite `j` em cada setor (tep, ocupações, toneladas, …) | `declare_io(E = list(j = ...))`, arquivo `E` |
| `D = E x̂⁻¹` (k × n) | coeficientes satélite: conta `j` por unidade de produção | calculada a partir de `E`, ou `declare_io(D = )`; `io$D` |
| `b_j = D_j x` | base da conta `j` | `satellite_base(io)` |
| `G = [D; B]` ((k + n) × n) | a matriz das metas | `build_lp()$G` |
| `g` (k + n) | as metas: `k` metas das contas, depois `n` metas econômicas | `build_goals(io, model, scenario)` |
| `d⁺`, `d⁻` | desvios acima e abaixo de cada meta | `run$d_plus`, `run$d_minus` |
| `α_h` | corredor do setor `h`, uma proporção de `|g_h|` | `declare_io(corridor = )`, ou `floor =` / `ceiling =` |
| `P_l` | nível de prioridade `l` | `define_model(priorities = )` |
| `Z_l` | ótimo do nível `l` (não é a matriz `Z`) | `run$Z`, colunas `Z1` … `ZL` das saídas |
| ECO | o bloco econômico: as `n` linhas de `B`, com meta `f` por padrão | a meta `"ECO"` nas prioridades |

As metas formam o sistema `G x + d⁻ − d⁺ = g`, com `x, d⁺, d⁻ ≥ 0`. As
variáveis de decisão ficam na ordem
`x_1 ... x_n, d⁺_1 ... d⁺_{k+n}, d⁻_1 ... d⁻_{k+n}`.

## 2. A base

### 2.1. No R

``` r

io <- declare_io(
  Z = Z, x = x, f = f,                          # ou A = A, ou B = B, no lugar de Z
  E = list(GD = E_GD, GC = E_GC, LAB = E_LAB),  # ou D = list(...): coeficientes no lugar de níveis
  corridor = alpha,                             # opcional: corridor, ou floor e/ou ceiling
  sectors = data.frame(code = codigos, name = nomes)
)
```

**A estrutura técnica.** Informe exatamente um de `Z` (fluxos; o pacote
calcula `A = Z x̂⁻¹` e `B = I − A`), `A` ou `B`. O nome do argumento diz
ao pacote qual objeto ele recebe.

**As contas satélite.** Informe exatamente um de `E` (o nível de cada
conta em cada setor; o pacote calcula `D = E x̂⁻¹`) ou `D` (os
coeficientes por unidade de produção). Os nomes são os nomes das contas.
Formas aceitas:

- uma lista nomeada de vetores (recomendada):
  `E = list(GD = E_GD, LAB = E_LAB)`, um valor por setor;
- um data frame, uma coluna por conta e uma linha por setor (uma coluna
  `code` opcional casa as linhas com os setores);
- uma matriz: para `E`, setores × contas; para `D`, contas × setores. A
  outra orientação é detectada. Uma matriz quadrada (`k = n`) é ambígua
  e é recusada: use uma lista.

Um vetor solto, sem nome, é recusado: escreva
`E = list(LAB = meu_vetor)`.

**Os setores.** Um data frame com `code` e `name`. Sem ele, os códigos
vêm dos nomes de `x` ou dos nomes das colunas de `Z`, ou são `S01`,
`S02`, ….

**Contas da base e contas do modelo.** O modelo usa só as contas
listadas em `accounts`. Uma base com seis contas serve a modelos com
uma, duas ou seis delas.

### 2.2. O corredor

`α_h` é uma proporção de `|g_h|`, a meta da linha econômica do setor `h`
(por padrão, a demanda final `f_h`):

| Declaração | Limite | Significado |
|----|----|----|
| `corridor = alpha` | `d⁻_h ≤ α_h |g_h|` e `d⁺_h ≤ α_h |g_h|` | corredor dos dois lados |
| `floor = alpha` | `d⁻_h ≤ α_h |g_h|`, isto é, `G_h x ≥ g_h − α_h |g_h|` | só piso |
| `ceiling = alpha` | `d⁺_h ≤ α_h |g_h|`, isto é, `G_h x ≤ g_h + α_h |g_h|` | só teto |
| `floor = a1, ceiling = a2` | os dois, com larguras diferentes | piso e teto |
| nada | sem limite | modelo solto |

- `alpha = 0.05` num setor deixa a sua meta econômica desviar até 5% de
  `|g_h|`.
- `NA` num setor deixa esse setor sem limite naquele lado.
- `corridor` junto com `floor` ou `ceiling` é erro.
- O modelo multiplica `α` por `corridor: multiplier` (padrão 1) e pode
  desligar o corredor com `corridor: use: false`, também num só cenário
  (seção 3.3).
- Se o corredor vem de uma quantidade por setor (por exemplo, as compras
  de energia de cada setor), calcule antes a proporção:
  `alpha <- compras / x`.
- As metas satélite nunca têm corredor.

### 2.3. Arquivos

`read_io(caminho)` lê uma pasta de arquivos CSV, ou uma planilha `.xlsx`
com abas dos mesmos nomes. `write_io(io, pasta)` grava uma base
declarada nesse formato, e `lexio_template(pasta)` grava uma base de
exemplo com um `model.yml` comentado.

| Arquivo / aba | Colunas | Conteúdo |
|----|----|----|
| `sectors` | `code`, `name` | os setores; define `n` e a ordem dos setores nas saídas |
| `Z`, `A` ou `B` (um) | `code` + uma coluna por setor (cabeçalho = códigos) | a estrutura técnica |
| `x` | `code`, `value` | valor bruto da produção |
| `f` | `code`, `value` | demanda final |
| `E` ou `D` (um) | `code` + uma coluna por conta | níveis ou coeficientes das contas satélite; os cabeçalhos são os nomes das contas |
| `corridor`, ou `floor` e/ou `ceiling` (opcional) | `code`, `alpha` | proporções `α_h` (vazio ou `NA` = sem limite) |

- Os códigos são texto (`0191` continua `0191`). As linhas de cada
  arquivo são casadas com os setores pelo código, em qualquer ordem.
- Os CSV podem usar `,` como separador e `.` como decimal, ou `;` e `,`.
  O formato é detectado pela primeira linha de cada arquivo.
- `Z`, `x` e `f` ficam na mesma unidade monetária; cada conta satélite,
  na sua unidade.
- Grave os números com todos os dígitos (até 17 algarismos
  significativos). O
  [`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
  faz isso. A seção 7.2 explica por que isso importa.

### 2.4. Conferências

O
[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
e o
[`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md)
param com erro quando as dimensões são inconsistentes, quando não vem
exatamente um de `Z`/`A`/`B` ou de `E`/`D`, quando há códigos repetidos
ou que não casam entre arquivos, quando falta um valor ou ele não é
finito, quando `x ≤ 0` em algum setor, ou quando algum `α` é negativo.
Eles avisam quando uma coluna de `A` soma 1 ou mais, quando `I − A` é
quase singular ou quando um coeficiente é negativo. O
[`validate_io()`](https://filipevascrocha.github.io/lexio/reference/validate_io.md)
dá o relatório completo, com o modo do corredor e, qualquer que seja a
declaração (`Z`, `A` ou `B`), a maior discrepância entre `(I − A) x` e
`f`.

``` r

validate_io(example_io())
#>                   check level                                             detail
#> 1            dimensions  info      3 sectors, 3 satellite account(s) (E, I, LAB)
#> 2          columns of A    ok                                 largest sum 0.4375
#> 3                 I - A    ok                         invertible (rcond = 0.497)
#> 4              corridor    ok      two-sided corridor; alpha between 0.1 and 0.2
#> 5 balance (I - A) x = f  info largest |(I - A) x - f| 0 (relative to x 0); sum 0
```

O bloco econômico usa `f` como meta. Se `f` difere de `(I − A) x`, uma
rodada sem choque nenhum não devolve exatamente `x`: o modelo fecha a
diferença dentro do corredor.

## 3. O modelo

### 3.1. Um `model.yml` completo

``` yaml
name: meu_estudo
data: base                 # a base: uma pasta (ou base.xlsx), relativa a este arquivo

accounts:                  # contas satélite, na ordem de declaração
  GD:
    label: Geração distribuída
    unit: tep
    direction: ">="
    target: {type: pooled_share, share: 0.01, pool: [GD, GC]}
  GC:
    label: Geração centralizada
    unit: tep
    direction: "<="
    target: {type: base}
  LAB:
    label: Emprego
    unit: ocupações
    direction: ">="
    target: {type: growth, rate: 0.01}
    weight: 1              # opcional; só importa quando metas dividem um nível

economy:                   # o bloco econômico ECO (seção 3.4)
  direction: ">="
  target: final_demand     # ou uma lista [5, 10, ...] ou um arquivo CSV (code, value)
  position: last           # o padrão: ECO preso no último nível
  deviation: absolute      # o padrão; ou relative

corridor:                  # o corredor declarado com os dados
  use: true                # false: modelo solto
  multiplier: 1            # multiplica alpha

scenarios:                 # opcional: vários conjuntos de metas no mesmo modelo
  GD_shock: {}             # as metas de accounts, sem mudança
  GC_shock:
    GD: {type: base}
    GC: {type: pooled_share, share: 0.01, pool: [GD, GC]}
  GC_shock_free:
    GD: {type: base}
    GC: {type: pooled_share, share: 0.01, pool: [GD, GC]}
    corridor: {use: false}

priorities: all            # todas as k! ordens, ECO por último (seção 4)
lock_tolerance: auto       # o padrão (seção 7)
```

As chaves aceitas são `name`, `data`, `accounts`, `economy`, `corridor`,
`scenarios`, `priorities`, `lock_tolerance` e `max_orderings`. Qualquer
outra chave é erro. O
[`read_model()`](https://filipevascrocha.github.io/lexio/reference/read_model.md)
lê o arquivo; `run_model("model.yml")` lê o modelo e a base indicada
nele.

O mesmo modelo no R:

``` r

pooled <- list(type = "pooled_share", share = 0.01, pool = c("GD", "GC"))
m <- define_model(
  accounts = list(
    GD  = list(direction = ">=", target = pooled, label = "Geração distribuída", unit = "tep"),
    GC  = list(direction = "<=", target = list(type = "base"), label = "Geração centralizada", unit = "tep"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.01), label = "Emprego", unit = "ocupações")
  ),
  economy = list(direction = ">=", target = "final_demand"),
  scenarios = list(GD_shock = list(),
                   GC_shock = list(GD = list(type = "base"), GC = pooled)),
  priorities = "all",
  lock_tolerance = "auto"
)
```

### 3.2. Direções e metas

Cada conta tem uma direção:

| Direção | Significado                    | Desvio penalizado |
|---------|--------------------------------|-------------------|
| `">="`  | piso: não ficar abaixo da meta | `d⁻`              |
| `"<="`  | teto: não passar da meta       | `d⁺`              |
| `"="`   | alvo: ficar na meta            | `d⁻` e `d⁺`       |

e uma meta, calculada a partir da sua base `b = D_j x`:

| `target` | Meta `g` | Uso típico |
|----|----|----|
| `{type: base}` | `b` | manter o nível atual |
| `{type: growth, rate: r}` | `b + b·r` | crescer (ou encolher, com taxa negativa) uma fração |
| `{type: pooled_share, share: s, pool: [A, B]}` | `b + s·(b_A + b_B)` | um choque igual a uma fração da base conjunta de um grupo de contas |
| `{type: delta, value: v}` | `b + v` | somar uma quantidade absoluta |
| `{type: level, value: v}` | `v` | fixar um nível absoluto |

A meta `g` é sempre o nível total da conta, não só a variação. Por
exemplo, com `b_GD = 4,08` e `b_GC = 26,18`, a meta
`{type: pooled_share, share: 0.01, pool: [GD, GC]}` de `GD` é
`4,08 + 0,01 × (4,08 + 26,18) = 4,38`.

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

### 3.3. Cenários

Cada cenário substitui as metas de algumas contas, e todo cenário roda
em todas as ordens. Um cenário também pode mudar:

- as direções, por exemplo `directions: {GC: "=", economy: "="}`;
- o corredor, por exemplo `corridor: {multiplier: 2}` ou
  `corridor: {use: false}`.

Sem `scenarios`, o modelo tem um único cenário, chamado `main`.

### 3.4. O bloco econômico

**Meta.** Por padrão, a meta do ECO é a demanda final declarada. Em
`economy: target`, uma lista de valores (um por setor) ou um arquivo CSV
com as colunas `code` e `value` dá outra meta; `economy: direction` muda
a sua direção.

**Posição.** `economy: position: last` (o padrão) prende o ECO no último
nível: o bloco econômico absorve o impacto final das metas acima dele.
Uma ordem só pode escrever `ECO` como o seu último nível, ou omiti-lo;
ele é acrescentado lá. Para pôr o ECO em outro lugar, o modelo tem de
dizer isso com `economy: position: free`. Então `ECO` pode ser escrito
em qualquer nível de uma ordem explícita e, com `priorities: all` (ou
`permute`), o ECO entra nas permutações, o que dá `(k + 1)!` ordens. O
exemplo de Miller e Blair usa essa declaração ([O exemplo de Miller e
Blair](https://filipevascrocha.github.io/lexio/articles/pt-BR-miller-blair.md)).

**Desvios.** O nível do ECO minimiza os desvios dos `n` setores em
relação às suas metas.

- `deviation: absolute` (o padrão) soma-os em unidades monetárias,
  `Σ_h d⁻_h`. Uma falta de uma unidade monetária custa o mesmo em todo
  setor, qualquer que seja o seu tamanho.
- `deviation: relative` soma-os como proporções de cada meta,
  `Σ_h d⁻_h / |g_h|`. Uma falta de 1% da demanda final de um setor custa
  o mesmo em todo setor.

Quando as metas acima do ECO obrigam a economia a abrir mão de parte da
demanda final, o nível do ECO escolhe quais setores abrem mão dela. No
exemplo abaixo, a energia incumbente é cortada em 20% no primeiro nível,
sem corredor:

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

Com desvios absolutos, o nível escolhe a menor perda em dinheiro, e a
perda cai sobre a Indústria, onde leva quase metade da demanda. Com
desvios relativos, ele escolhe a menor perda em proporção da demanda de
cada setor. Cada nível é um programa linear, então a perda não se
espalha por igual: a solução é um vértice e concentra a perda onde ela é
mais barata na medida escolhida. Um corredor já limita a perda de cada
setor; com um corredor estreito, as duas escolhas tendem a dar a mesma
solução. Os desvios relativos exigem uma meta `g_h` diferente de zero em
todo setor, e o ótimo `Z` do nível do ECO passa a ser uma soma de
proporções.

## 4. Prioridades

Sem declaração, todas as ordens são rodadas; para rodar só algumas,
declare-as. Em todos os casos o ECO é o último nível, a menos que o
modelo declare `economy: position: free`.

### 4.1. Todas as ordens

`priorities: all` (o padrão) põe uma conta por nível e roda todas as
`k!` ordens, na ordem lexicográfica de declaração. Com as contas
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

As linhas são as ordens `P01` a `P06`: `A-B-C`, `A-C-B`, `B-A-C`,
`B-C-A`, `C-A-B` e `C-B-A`.

|   k | Níveis          | Ordens por cenário |
|----:|-----------------|-------------------:|
|   2 | P1, P2, ECO     |                  2 |
|   3 | P1, P2, P3, ECO |                  6 |
|   4 | P1, …, P4, ECO  |                 24 |
|   6 | P1, …, P6, ECO  |                720 |

Quando o número de ordens passa de `max_orderings` (padrão 720), o
pacote pede ordens explícitas ou um limite maior.

### 4.2. Permutar grupos

``` yaml
priorities:
  permute: [[GD, GC], LAB]   # GD e GC dividem um nível; 2! = 2 ordens, ECO por último
```

Cada grupo é um nível com várias metas, e toda conta deve estar em
exatamente um grupo. Com `economy: position: free`, o ECO é permutado
junto com os grupos.

### 4.3. Ordens explícitas

``` yaml
priorities:
  primeira: [LAB, GD, GC]       # uma conta por nível; o ECO entra como último nível
  segunda: [[GD, GC], LAB]      # GD e GC dividem o primeiro nível
```

No R:
`priorities = list(primeira = c("LAB", "GD", "GC"), segunda = list(c("GD", "GC"), "LAB"))`.
Para rodar uma só ordem, liste só ela; `run_model(..., orderings = )`
também roda só algumas das ordens de um modelo.

- Cada conta aparece exatamente uma vez.
- `ECO` pode ser escrito no fim; em outro lugar, só com
  `economy: position: free` (então `[LAB, ECO, [GD, GC]]` põe o ECO em
  segundo).
- O ECO fica sozinho no seu nível.
- Cada meta conserva a sua direção, então um nível pode misturar pisos e
  tetos.

**Rótulos.** Ordens sem nome, com uma conta por nível e o ECO por
último, recebem o rótulo da sua posição na ordem lexicográfica (`P05`
para `C-A-B` com `k = 3`); outras ordens sem nome recebem `O01`, `O02`,
…; ordens com nome mantêm o nome.

### 4.4. Pesos

`weight` (padrão 1, positivo) multiplica o desvio de uma conta no seu
nível. Só importa quando metas dividem um nível: o nível minimiza
`Σ peso × desvio penalizado`. Um nível com metas em unidades diferentes
soma os seus desvios, então dê a elas unidades comparáveis ou pesos.

## 5. Rodar

``` r

res <- run_model("meu_estudo/model.yml")   # lê a base indicada em data:
res <- run_model(io, m)                    # ou a base e o modelo já na memória
```

| Argumento de [`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md) | Efeito |
|----|----|
| `scenarios` | só alguns cenários (nomes) |
| `orderings` | só algumas ordens (números ou rótulos) |
| `strict` | com `TRUE`, para no primeiro nível não ótimo; o padrão `FALSE` roda tudo e sinaliza |
| `verbose` | mostra o andamento |
| `lock_tolerance` | substitui a do modelo (seção 7) |

Uma rodada só:

``` r

io <- example_io()
m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
r <- run_experiment(io, m, scenario = "I_shock", ordering = c("LAB", "E", "I"))
r$Z        # ótimo de cada nível
#> [1] 0 0 0 0
r$x_star   # produção do último nível
#> [1] 100.76394  81.06627  65.85146
```

`ordering` pode ser um número, um rótulo (`"P05"`, `"segunda"`) ou uma
ordem escrita como na seção 4.3. Cada rodada leva de centésimos a
décimos de segundo: uma base com 72 setores e 6 contas (720 ordens) roda
em cerca de um minuto.

## 6. Saídas

`write_outputs(res, pasta)` grava:

    pasta/
      README.md            relatório: modelo, corredor, ECO, tabelas por cenário, estados distintos, avisos
      results.xlsx         todas as tabelas numa planilha Excel (veja write_excel())
      orderings.csv        uma linha por cenário × ordem
      levels.csv           uma linha por cenário × ordem × nível: cada etapa de cada rodada
      level_results.csv    cada rodada, cada nível, cada linha de G
      account_goals.csv    uma linha por cenário × ordem × conta
      x_star_all_runs.csv  uma linha por setor: x0 e a produção x* de cada rodada
      states.csv           estados distintos (soluções x* iguais)
      runs/<cenário>/<rótulo>_<níveis>/
                           all_levels.csv, level_1.csv ... level_L.csv, x_star.csv
      inputs/              o model.yml usado e o SHA-256 dos arquivos da base
      results.rds          o objeto completo (readRDS)
      session.txt          versões do R, dos pacotes e do GLPK

- A pasta de uma rodada é o seu rótulo e os seus níveis, por exemplo
  `P04_GC-LAB-GD` ou `book_1_EMP-ECO-OIL+COAL-SO2+HC`; o ECO só aparece
  quando não é o último.
- `format = "intl"` (padrão) grava os CSV com `,` e `.`;
  `format = "br"`, com `;` e `,`, para planilhas com vírgula decimal.
- Uma pasta que já tem arquivos não é sobrescrita, a menos que
  `overwrite = TRUE`.
- `excel = FALSE` não grava o `results.xlsx`.

**`orderings.csv`** (`res$summary$runs`)

| Coluna | Conteúdo |
|----|----|
| `scenario`, `ordering`, `label`, `priorities` | a rodada e os seus níveis (`GD > GC > LAB > ECO`) |
| `status` | código do GLPK de cada nível, concatenado (`0000` = todos ótimos) |
| `status_glpk` | o mesmo, por extenso (`GLP_OPT GLP_OPT GLP_OPT GLP_NOFEAS`) |
| `optimal`, `ok` | todos os níveis ótimos; e, além disso, todas as conferências passaram |
| `lock_tolerance` | trava usada na rodada (0 = exata; seção 7) |
| `corridor` | modo do corredor na rodada |
| `Z1` … `ZL` | ótimo de cada nível |
| `delta_x`, `delta_x_pct` | variação da produção total, `Σ x* − Σ x`, e em fração |
| `delta_<conta>` | variação de cada conta, `D_j x* − b_j` |
| `state` | estado distinto da rodada |

**`levels.csv`** (`res$summary$levels`): uma linha por nível de cada
rodada, com as suas metas, o seu ótimo `Z`, o status do GLPK e a trava
usada.

**`level_results.csv`**: para cada rodada e cada nível, uma linha por
linha de `G` (`row`, `block` = conta ou ECO), com `g`, `Gx`, `d_minus`,
`d_plus` e, nas linhas do ECO, a produção `x` daquele nível.

**`all_levels.csv`** (um por rodada): os mesmos números, com os níveis
lado a lado: `row`, `notation` (`xD_j` = `D_j x`; `f'_h` = linha `h` de
`(I − A) x`), `name`, `block`, `g`, e `level<l>_Gx`, `level<l>_d_minus`,
`level<l>_d_plus` e `level<l>_x` de cada nível.

**`account_goals.csv`** (`res$summary$goals`)

| Coluna | Conteúdo |
|----|----|
| `account`, `unit`, `direction` | a conta |
| `base`, `g`, `Gx` | base `b`, meta `g` e valor alcançado `D_j x*` |
| `delta`, `intended` | `Gx − base` e `g − base` |
| `realized` | fração realizada da mudança pretendida, `delta / intended` |
| `deviation` | desvio penalizado da conta |
| `at_goal` | a conta atingiu a meta |

**`states.csv`** (`res$summary$states`). Ordens diferentes podem levar à
mesma solução. As rodadas cujas produções `x*` diferem no máximo 1e-6 em
todos os setores formam um estado.

**`results.xlsx`**: as abas estão descritas em [Primeiros
passos](https://filipevascrocha.github.io/lexio/articles/pt-BR-lexio.md)
e em
[`?write_excel`](https://filipevascrocha.github.io/lexio/reference/write_excel.md).

## 7. Comportamento numérico

### 7.1. A trava dos níveis resolvidos

Cada nível trava os anteriores por igualdade, `d_l = Z_l`, que vale com
folga zero. Quando as escalas das metas diferem muito (tep, ocupações e
unidades monetárias no mesmo problema), o GLPK às vezes declara inviável
(`GLP_NOFEAS`) um nível que tem solução. É uma falsa inviabilidade
numérica: outro solver (lpSolve) resolve o mesmo problema. Ela depende
dos números, não do número de contas:

| Base | Rodadas não ótimas com a trava exata |
|----|----|
| Brasil 2018 (EPE), 72 setores, k = 3, coeficientes com 15 algarismos significativos | 0 de 24 |
| a mesma base, com precisão completa | 4 de 24 |
| Brasil 2018 (EPE), k = 4 / 5 / 6 | 4 de 24 / 20 de 120 / 186 de 720 |
| Brasil 2015 (IBGE), 67 setores, k = 4 | 9 de 24 |

`lock_tolerance: auto` (o padrão):

- toda rodada usa primeiro a trava exata;
- só se algum nível não for ótimo a rodada é resolvida de novo com as
  travas relaxadas para `d_l ≤ Z_l + t·max(1, |Z_l|)`, com o menor `t`
  entre 1e-12, 1e-11, 1e-10 e 1e-9 que torna todos os níveis ótimos;
- se nenhum `t` funciona, a rodada fica com a trava exata e é sinalizada
  como não ótima.

As rodadas ótimas com a trava exata não mudam. Nos testes com as duas
bases reais, o `auto` tornou ótimas todas as 906 rodadas; das 219
rodadas resolvidas de novo, 211 precisaram só de `t = 1e-12`.

**O custo em precisão.** A folga deixa cada nível resolvido ficar acima
do seu ótimo em até `t·max(1, |Z_l|)`, e os níveis seguintes podem
usá-la. Em problemas mal condicionados, o efeito sobre os níveis
seguintes é muito maior que `t`: nos testes, `t = 1e-9` moveu o `Z` dos
níveis seguintes em até cerca de 2e-4 (relativo) em relação a uma
solução exata. Por isso toda rodada relaxada é sinalizada: o
[`run_model()`](https://filipevascrocha.github.io/lexio/reference/run_model.md)
emite um aviso, o [`print()`](https://rdrr.io/r/base/print.html) a
mostra, a coluna `lock_tolerance` dá o `t` usado e o relatório lista as
rodadas na seção *Warnings*. Ao publicar resultados, informe quantas
rodadas precisaram da trava relaxada.

As outras opções são `lock_tolerance: exact` (ou `0`), que mantém só a
trava exata e deixa as rodadas que falham sinalizadas como não ótimas, e
um número `t` (até 1e-6), que tenta a trava exata e depois só `t`.

### 7.2. Sensibilidade aos últimos dígitos

Com travas de igualdade, o status do GLPK pode mudar com perturbações
dos dados da ordem de 1e-16. A mesma base gravada com 15 ou com 17
algarismos significativos dá os mesmos números até cerca de 1e-10, mas
pode mudar o status de rodadas no limite. Para resultados idênticos bit
a bit, use entradas idênticas bit a bit; o
[`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
grava a menor representação decimal exata de cada número. Nos Macs com
processador da Apple, o próprio R pode ler um número gravado com 16 ou
17 algarismos significativos com uma diferença no último bit; números
com até 15 algarismos significativos, como os coeficientes da tese, são
lidos exatamente em qualquer sistema.

### 7.3. Ótimos alternativos

Um nível pode ter vários ótimos, com o mesmo `Z` e um `x` diferente. O
GLPK devolve um deles. Esse é um dos motivos pelos quais os resultados
também são resumidos por estados distintos.

### 7.4. O que o modelo não impõe

- Não há restrição de não negatividade sobre as contas satélite (`D x`)
  nem sobre a demanda final resultante.
- O corredor vale só para o bloco econômico. Os desvios das contas
  satélite são livres; o seu custo está na ordem de prioridade.

### 7.5. Níveis sem solução

Um nível pode não ter solução: por exemplo, um corredor nulo (`α = 0`)
com uma meta econômica que nenhuma produção não negativa atende. O GLPK
então também declara o nível não ótimo. Para separar esse caso de uma
falsa inviabilidade, o `lexio` confere a solução devolvida pelo GLPK
contra as restrições do nível (metas, corredor, travas e `x, d ≥ 0`),
cada linha relativa a `max(1, |lado direito|)`:

- violação até 1e-4: as restrições valem, então o aviso é uma falsa
  inviabilidade; os números são mantidos e a rodada é sinalizada como
  não ótima. Nas falsas inviabilidades que examinamos (várias centenas
  de rodadas), a violação ficou abaixo de 1e-6;
- violação acima de 1e-4: o nível não tem solução. Esse nível e os
  seguintes ficam em branco (`NA`) na rodada e em todas as tabelas, a
  coluna `infeasible_level` de `summary$runs` indica o primeiro deles (o
  relatório diz “no solution from level l”), e a rodada não tem estado.
  Em níveis sem solução, a violação é da ordem de 1e-2 ou mais.

A coluna `violation` de `summary$levels` (e do `levels.csv`) dá o valor
de cada nível. Um `α` ou um multiplicador do corredor negativo é
recusado na declaração.

## 8. Alcance e limites

- **Tamanho.** As matrizes são densas. Num notebook, uma rodada com três
  contas (quatro níveis) levou cerca de 0,1 s com 100 setores, 0,4 s com
  200, 2 s com 400 e 7 s com 600; os tempos dependem da máquina e da
  matriz (em outra máquina, com matrizes aleatórias totalmente densas,
  foram cerca de duas vezes maiores), mas o tempo sempre cresce mais
  rápido que o quadrado do número de setores, e um modelo roda `k!`
  ordens por cenário. Tabelas nacionais, com dezenas a algumas centenas
  de setores, estão ao alcance; tabelas multirregionais com milhares de
  setores, não.
- **Prioridades.** Toda conta do modelo entra em todas as ordens; não há
  contas apenas monitoradas.
- **Bloco econômico.** É uma meta só: todos os setores têm a mesma
  direção, e o vetor de metas (`f`, por padrão) é o mesmo em todos os
  cenários.
- **Corredor.** Limita só os desvios das metas econômicas, em proporções
  de `|g_h|`. Não há corredor sobre a produção `x` nem corredor em
  valores absolutos.

## 9. Perguntas

**Posso usar uma ou duas contas satélite?** Sim. Com `k = 1` há uma
rodada por cenário; com `k = 2`, duas.

**Minhas contas satélite já são coeficientes. Preciso dos níveis?** Não:
declare `D =` no lugar de `E =` (e `A =` ou `B =` no lugar de `Z =`).

**Meus vetores já estão no R. Preciso gravar arquivos?** Não: passe-os
ao
[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md)
pelo nome. O
[`write_io()`](https://filipevascrocha.github.io/lexio/reference/write_io.md)
serve só para guardar a base declarada.

**Posso rodar uma só ordem de prioridade?** Sim: liste-a em
`priorities`, por exemplo `priorities: {minha: [GC, GD, LAB]}`.

**Posso rodar sem corredor?** Sim: não declare corredor, ou use
`corridor: use: false` no modelo ou num cenário.

**O que significa uma rodada “não ótima”?** Que o GLPK não certificou
algum nível. Em geral é uma falsa inviabilidade numérica, e os números
são mantidos; se o nível não tem solução, ele fica em branco. Veja as
seções 7.1 e 7.5.

**Como o pacote foi testado?** Os testes em `tests/testthat` cobrem
bases sintéticas com 2 a 100 setores e 1 a 5 contas (dimensões, não
degradação das prioridades mais altas, invariância à ordem dos setores,
à ordem de declaração e à forma da declaração), os modos do corredor, as
formas das prioridades, os desvios relativos, a trava, as saídas, o
exemplo de Miller e Blair e uma comparação de cada nível com uma
implementação independente resolvida com o lpSolve.

## Referências

- Rocha, F. V. (2026). *Modelo generalizado de insumo-produto com Goal
  Programming preemptivo aplicado à transição energética brasileira:
  eletricidade e combustíveis na estrutura produtiva de 2018.* Tese de
  doutorado, Programa de Pós-graduação em Economia, Universidade Federal
  de Juiz de Fora.
- Miller, R. E. e Blair, P. D. (2022). *Input-Output Analysis:
  Foundations and Extensions.* 3ª ed. Cambridge University Press, seção
  13.8. Edição anterior: 2ª ed., 2009, seção 10.4.
