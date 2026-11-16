# O exemplo de Miller e Blair

*Tradução de
[`vignette("miller-blair")`](https://filipevascrocha.github.io/lexio/articles/miller-blair.md).*

Miller e Blair (2022, seção 13.8) ilustram o Goal Programming num modelo
de insumo-produto com uma economia de dois setores e cinco contas
satélite, a economia do seu Exemplo 13.7. A segunda edição traz o mesmo
exemplo, com os mesmos dados e as mesmas soluções impressas (2009, seção
10.4, Exemplo 10.1). Este texto o roda com o `lexio`. É um modelo solto
(sem corredor), com várias metas por nível e as metas econômicas no
segundo nível.

**A primeira estrutura de prioridades do livro não reproduz a solução
impressa.** Para a sua primeira estrutura (eq. 13.17, p. 645; eq. 10.15,
p. 465, em 2009) o livro imprime `x = (21,25; 49,375)`. O ótimo
lexicográfico, que o `lexio` encontra, é `x* = (32, 44)`. A seção 4
mostra por quê. A segunda estrutura (p. 648; p. 469 em 2009; sem número
nas duas edições) confere com o livro: `x* = (10, 10)`.

## 1. Os dados

Os fluxos `Z`, a produção `x` e a demanda final `f` dão
`A = [0,3 0,2; 0,1 0,7]`. O livro dá as contas satélite por unidade de
produção, então elas são declaradas como coeficientes, com `D =`. Nenhum
corredor é declarado, então o modelo é solto.

``` r

library(lexio)

Z <- matrix(c(3, 2,
              1, 7), nrow = 2, byrow = TRUE)
x <- c(10, 10)
f <- c(5, 2)
io <- declare_io(Z = Z, x = x, f = f,
                 D = list(OIL = c(0.2, 0.3), COAL = c(0.1, 0.4), SO2 = c(0.5, 1.1),
                          HC = c(0.7, 0.7), EMP = c(0.1, 0.2)),
                 sectors = data.frame(code = c("I1", "I2"), name = c("Industry 1", "Industry 2")))
io
#> <lexio_io> 2 sectors, 5 satellite account(s): OIL, COAL, SO2, HC, EMP | declared as Z + D | corridor: free 
#>   base OIL = D x =  5.00
#>   base COAL = D x =  5.00
#>   base SO2 = D x = 16.00
#>   base HC = D x = 14.00
#>   base EMP = D x =  3.00
```

## 2. Metas e prioridades

As metas são níveis. O uso de petróleo e de carvão não deve passar de
20, as emissões de SO2 de 16 e as de HC de 20 (tetos, que penalizam
`d⁺_1` a `d⁺_4`); o emprego deve chegar a 12 (um piso, que penaliza
`d⁻_5`). As metas econômicas são `(I − A) x ≥ f' = (5, 10)` (penalizando
`d⁻_6` e `d⁻_7`), declaradas como a meta do bloco econômico.

O livro põe as metas econômicas no segundo nível. No `lexio`, o bloco
econômico fica preso no último nível, a menos que o modelo declare outra
coisa; `position = "free"` é essa declaração.

``` r

level <- function(v) list(type = "level", value = v)
accounts <- list(
  OIL  = list(direction = "<=", target = level(20)),
  COAL = list(direction = "<=", target = level(20)),
  SO2  = list(direction = "<=", target = level(16)),
  HC   = list(direction = "<=", target = level(20)),
  EMP  = list(direction = ">=", target = level(12))
)
model <- define_model(
  accounts = accounts,
  economy = list(direction = ">=", target = c(5, 10), position = "free"),
  priorities = list(
    # eq. 13.17 (2022, p. 645): P1 d5-, P2 d6- + d7-, P3 d1+ + d2+, P4 d3+ + d4+
    book_1 = list("EMP", "ECO", c("OIL", "COAL"), c("SO2", "HC")),
    # 2022, p. 648 (sem número): P1 d3+, P2 d6- + d7-, P3 d1+ + d2+, P4 d4+, P5 d5-
    book_2 = list("SO2", "ECO", c("OIL", "COAL"), "HC", "EMP"),
    # a primeira estrutura, uma meta por vez, como nas figuras do livro
    one_at_a_time = list("EMP", "ECO", "OIL", "COAL", "SO2", "HC")
  ),
  name = "miller_blair"
)
model
#> <lexio_model> miller_blair | 5 satellite account(s), 1 scenario(s), 3 priority ordering(s) | lock: auto (exact; relaxed only where GLPK fails) 
#>   OIL      <= level 20
#>   COAL     <= level 20
#>   SO2      <= level 16
#>   HC       <= level 20
#>   EMP      >= level 12
#>   ECO      >= declared goals | absolute deviations | position free (declared by the operator)
#>   corridor: as declared in the data (multiplier 1) 
#>   book_1: EMP > ECO > OIL + COAL > SO2 + HC
#>   book_2: SO2 > ECO > OIL + COAL > HC > EMP
#>   one_at_a_time: EMP > ECO > OIL > COAL > SO2 > HC
#>   scenario main
```

O mesmo modelo está em
`system.file("examples", "miller_blair", "model.yml", package = "lexio")`,
sem a terceira ordem.

## 3. Cada etapa de cada rodada

``` r

res <- run_model(io, model, verbose = FALSE)
res
#> <lexio_results> miller_blair | 2 sectors | 5 account(s): OIL, COAL, SO2, HC, EMP | corridor: free 
#>   scenario main           3 ordering(s) | all optimal | 2 distinct state(s)
#>   distinct states in total: 2 
#>   write everything with write_outputs(res, "folder")
```

A tabela abaixo mostra, para cada nível de cada rodada, as suas metas, o
seu ótimo `Z`, o status do GLPK, a produção `x` depois do nível e o
valor `G x` de cada meta.

``` r

stages <- function(r) {
  do.call(rbind, lapply(seq_along(r$levels), function(l) {
    lev <- r$levels[[l]]
    gx <- stats::setNames(round(lev$gx, 4), c(names(accounts), "ECO_1", "ECO_2"))
    data.frame(level = l, goals = r$order[l], Z = round(lev$objval, 4), status = lev$status_symbol,
               x1 = round(lev$x[1], 4), x2 = round(lev$x[2], 4), as.list(gx), check.names = FALSE)
  }))
}
for (r in res$runs) {
  cat("\n", r$label, ": ", paste(r$order, collapse = " > "), "\n", sep = "")
  print(stages(r), row.names = FALSE)
}
#> 
#> book_1: EMP > ECO > OIL+COAL > SO2+HC
#>  level    goals    Z  status    x1     x2     OIL   COAL     SO2      HC EMP ECO_1   ECO_2
#>      1      EMP  0.0 GLP_OPT  0.00 60.000 18.0000 24.000 66.0000 42.0000  12 -12.0 18.0000
#>      2      ECO  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      3 OIL+COAL  0.8 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      4   SO2+HC 81.6 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#> 
#> book_2: SO2 > ECO > OIL+COAL > HC > EMP
#>  level    goals Z  status x1      x2    OIL   COAL SO2      HC    EMP   ECO_1  ECO_2
#>      1      SO2 0 GLP_OPT  0 14.5455 4.3636 5.8182  16 10.1818 2.9091 -2.9091 4.3636
#>      2      ECO 8 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      3 OIL+COAL 0 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      4       HC 0 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#>      5      EMP 9 GLP_OPT 10 10.0000 5.0000 5.0000  16 14.0000 3.0000  5.0000 2.0000
#> 
#> one_at_a_time: EMP > ECO > OIL > COAL > SO2 > HC
#>  level goals    Z  status    x1     x2     OIL   COAL     SO2      HC EMP ECO_1   ECO_2
#>      1   EMP  0.0 GLP_OPT  0.00 60.000 18.0000 24.000 66.0000 42.0000  12 -12.0 18.0000
#>      2   ECO  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      3   OIL  0.0 GLP_OPT 21.25 49.375 19.0625 21.875 64.9375 49.4375  12   5.0 12.6875
#>      4  COAL  0.8 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      5   SO2 48.4 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
#>      6    HC 33.2 GLP_OPT 32.00 44.000 19.6000 20.800 64.4000 53.2000  12  13.6 10.0000
```

## 4. O livro e o lexio, lado a lado

O valor de um nível de prioridade numa produção `x` é a soma dos desvios
penalizados das suas metas. A função abaixo o calcula em qualquer ponto,
para comparar, nível a nível, o ponto impresso no livro e a solução do
`lexio`.

``` r

level_values <- function(x, levels) {
  g <- build_goals(io, model)
  Gx <- as.numeric(rbind(io$D, io$B) %*% x)
  d_plus <- pmax(Gx - g, 0)
  d_minus <- pmax(g - Gx, 0)
  eco <- length(accounts) + seq_len(io$n)
  vapply(levels, function(goals) {
    sum(vapply(goals, function(a) {
      if (a == "ECO") return(sum(d_minus[eco]))
      i <- match(a, names(accounts))
      if (accounts[[a]]$direction == "<=") d_plus[i] else d_minus[i]
    }, numeric(1)))
  }, numeric(1))
}
book <- list(book_1 = c(21.25, 49.375), book_2 = c(10, 10))
for (o in names(book)) {
  r <- res$runs[[match(o, vapply(res$runs, `[[`, character(1), "label"))]]
  cat("\n", o, ": the book prints x = (", paste(book[[o]], collapse = ", "), "); lexio gives x* = (",
      paste(round(r$x_star, 6), collapse = ", "), ")\n", sep = "")
  print(data.frame(level = seq_along(r$order), goals = r$order,
                   at_book_point = zapsmall(level_values(book[[o]], r$levels_goals), 10),
                   at_lexio_point = zapsmall(level_values(r$x_star, r$levels_goals), 10),
                   lexio_Z = zapsmall(r$Z, 10)), row.names = FALSE)
}
#> 
#> book_1: the book prints x = (21.25, 49.375); lexio gives x* = (32, 44)
#>  level    goals at_book_point at_lexio_point lexio_Z
#>      1      EMP         0.000            0.0     0.0
#>      2      ECO         0.000            0.0     0.0
#>      3 OIL+COAL         1.875            0.8     0.8
#>      4   SO2+HC        78.375           81.6    81.6
#> 
#> book_2: the book prints x = (10, 10); lexio gives x* = (10, 10)
#>  level    goals at_book_point at_lexio_point lexio_Z
#>      1      SO2             0              0       0
#>      2      ECO             8              8       8
#>      3 OIL+COAL             0              0       0
#>      4       HC             0              0       0
#>      5      EMP             9              9       9
```

Na segunda estrutura os dois pontos coincidem. Na primeira, os dois
pontos atendem exatamente aos dois primeiros níveis: o emprego é 12 e as
metas econômicas são atendidas. Depois do segundo nível, as soluções
formam o segmento da reta do emprego `x_2 = 60 − 0,5 x_1` entre
`(21,25; 49,375)` e `(32, 44)`. Ao longo desse segmento, o uso de
petróleo fica abaixo de 20 e o de carvão é `24 − 0,1 x_1`, então o
excesso de carvão `d⁺_2 = 4 − 0,1 x_1`, que entra no terceiro nível, é
mínimo em `(32, 44)`, onde vale 0,8. O livro imprime a outra ponta do
segmento, onde ele vale 1,875.

As etapas de `book_1` mostram o mesmo: depois do nível 2, o GLPK está no
ponto impresso no livro; o nível 3 então move a solução ao longo do
segmento até `(32, 44)`, baixando o excesso de carvão de 1,875 para 0,8
sem mudar os níveis 1 e 2. Resolver as metas uma por vez
(`one_at_a_time`) também dá `(32, 44)`. Os testes do pacote conferem os
mesmos ótimos com uma implementação independente, resolvida com o
lpSolve.

## 5. Todas as ordens, com o bloco econômico por último

Sem uma declaração de `priorities`, o `lexio` roda todas as ordens das
contas, uma conta por nível, com o bloco econômico preso no último
nível: `5! = 120` ordens.

``` r

model_all <- define_model(accounts, economy = list(direction = ">=", target = c(5, 10)),
                          name = "miller_blair_all")
res_all <- run_model(io, model_all, verbose = FALSE)
res_all
#> <lexio_results> miller_blair_all | 2 sectors | 5 account(s): OIL, COAL, SO2, HC, EMP | corridor: free 
#>   scenario main         120 ordering(s) | all optimal | 6 distinct state(s)
#>   distinct states in total: 6 
#>   write everything with write_outputs(res, "folder")
res_all$summary$states[, c("state", "n_runs", "delta_x", paste0("delta_", names(accounts)))]
#>   state n_runs    delta_x delta_OIL delta_COAL delta_SO2 delta_HC delta_EMP
#> 1     1     40   8.571429  1.000000  -1.285714   0.00000      6.0 0.1428571
#> 2     2     20  12.000000  1.400000  -1.800000   0.00000      8.4 0.2000000
#> 3     3     20   8.571429  3.571429   6.428571  15.42857      6.0 2.7142857
#> 4     4     20  60.000000 15.000000  15.000000  48.00000     42.0 9.0000000
#> 5     5     10  40.000000 13.000000  19.000000  50.00000     28.0 9.0000000
#> 6     6     10 100.000000 19.000000   7.000000  44.00000     70.0 9.0000000
```

## 6. Notas sobre a edição de 2022

O exemplo, os dados e as soluções impressas são os mesmos de 2009.
Conferindo com o GLPK, também encontramos:

- erros de digitação: as metas 13.14 a 13.16 estão escritas como
  `≤ / minimizar d⁺`, enquanto a matriz e a equação 13.17 usam `≥ / d⁻`
  (p. 645); a equação 13.9 traz o sinal `+d⁺_4` (p. 639);
- a seção 13.8 chama o exemplo de “Example 13.1”, o seu número na edição
  de 2009 (10.1); em 2022 os dados são os do Exemplo 13.7 (seção
  13.7.2), e o Exemplo 13.1 é outro (seção 13.2.1);
- uma nova ilustração de programação linear (seção 13.8.1), com SO2 ≤
  15: com emprego ≥ 3 ela é inviável; sem a linha do emprego, o ótimo é
  `(9,770; 9,195)`, com `q = 6,782`, e não o impresso `(8,846; 9,615)`,
  com `q = 6,269` (um ponto com emprego 2,808).

## Referência

Miller, R. E. e Blair, P. D. (2022). *Input-Output Analysis: Foundations
and Extensions.* 3ª ed. Cambridge University Press, seção 13.8. Edição
anterior: 2ª ed., 2009, seção 10.4.
