# O modelo da tese, passo a passo: o mercado de COMBUSTÍVEIS.
# (Cópia de replication/fuels.R com os comentários em português.)
#
# Combustíveis renováveis (CR = biodiesel + etanol, a entrante) contra
# combustíveis não renováveis (CNR = derivados de petróleo + gás natural, a
# incumbente), com o trabalho (LAB), na matriz de insumo-produto do Brasil com
# detalhamento do setor energético (EPE/FIPE, 72 setores, ano-base 2018). Ele
# espelha o electricity.R; leia aquele primeiro para a notação. O
# 02_reproduce.R roda os dois mercados com todas as conferências.
#
# Saída: todos os resultados, numa pasta nova (nada é sobrescrito):
# replication/outputs_fuels, depois _2, _3, ... O console mostra cada rodada,
# nível a nível, as tabelas de resumo e os números publicados.
#
# Uso, na raiz do repositório:
#   RStudio: abra o lexio.Rproj, abra este arquivo e clique em Source (ou rode
#            linha a linha com Ctrl+Enter);
#   terminal: Rscript replication/pt-BR/fuels.R

library(lexio)
replication_dir <- file.path(here::here(), "replication")
source(file.path(replication_dir, "R", "thesis_helpers.R"))
if (!interactive()) options(width = 200)
out_dir <- new_output_dir(file.path(replication_dir, "outputs_fuels"))

# ------------------------------------------------------------------------------
# Passo 0. Onde estão os dados
# ------------------------------------------------------------------------------
# replication/thesis_data/ (baixada aqui, se não existir; veja o electricity.R).
data_dir <- file.path(thesis_data_dir(replication_dir), "fuels", "coefficients")

# ------------------------------------------------------------------------------
# Passo 1. Os dados, como vetores na sessão do R
# ------------------------------------------------------------------------------
#   sectors.csv   code, name           os 72 setores e a sua ordem
#   B.csv         code + 72 colunas    B = I - A
#   x.csv         code, value          valor bruto da produção x, R$ milhões
#   f.csv         code, value          demanda final f, R$ milhões
#   D.csv         code, CR, CNR, LAB   coeficientes: tep (CR, CNR) e ocupações (LAB) por R$ milhão produzido
#   corridor.csv  code, alpha          corredor: compras intersetoriais de combustíveis / x
# Os coeficientes dos fluxos publicados (thesis_data/fuels/base/),
# arredondados a 15 algarismos significativos, como nas contas da tese.
read_table <- function(name) {
  utils::read.csv(file.path(data_dir, paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE,
                  colClasses = c(code = "character"), encoding = "UTF-8")
}
sectors <- read_table("sectors")          # código e nome dos 72 setores
B <- as.matrix(read_table("B")[, -1])     # I - A (a primeira coluna é o código)
x <- read_table("x")$value                # valor bruto da produção
f <- read_table("f")$value                # demanda final
D <- read_table("D")
D_CR <- D$CR                              # combustíveis renováveis (biodiesel + etanol), tep por R$ milhão
D_CNR <- D$CNR                            # não renováveis (derivados de petróleo + gás natural), tep por R$ milhão
D_LAB <- D$LAB                            # ocupações por R$ milhão
alpha <- read_table("corridor")$alpha     # corredor

# ------------------------------------------------------------------------------
# Passo 2. Declarar a base
# ------------------------------------------------------------------------------
io <- declare_io(B = B, x = x, f = f,
                 D = list(CR = D_CR, CNR = D_CNR, LAB = D_LAB),
                 corridor = alpha,
                 sectors = sectors)
print(io)            # a base de cada conta, b_j = D_j x

# ------------------------------------------------------------------------------
# Passo 3. Declarar o modelo
# ------------------------------------------------------------------------------
#   CR   entrante,    ">=": não deve ficar abaixo da meta
#   CNR  incumbente,  "<=": não deve passar da meta
#   LAB  trabalho,    ">=": cresce a fração do choque (5%)
# A meta de cada conta é o seu nível total no cenário (base + choque). O
# choque é 5% da base conjunta de CR e CNR:
#   cenário CR:  g_CR  = b_CR  + 0,05 (b_CR + b_CNR), g_CNR = b_CNR
#   cenário CNR: g_CNR = b_CNR + 0,05 (b_CR + b_CNR), g_CR  = b_CR
#   nos dois:    g_LAB = b_LAB x 1,05
#
# Ordens de prioridade. Com my_orderings <- NULL, todas as ordens das três
# contas são rodadas: 3! = 6, P01..P06 (P1..P6 na tese). Para rodar só
# algumas, liste-as, por exemplo
#   my_orderings <- list(c("CNR", "CR", "LAB"))
# O ECO é sempre o último nível.
share <- 0.05
shock <- list(type = "pooled_share", share = share, pool = c("CR", "CNR"))
my_orderings <- NULL
model <- define_model(
  accounts = list(
    CR = list(direction = ">=", target = list(type = "base"), unit = "toe",
              label = "Renewable fuels (biodiesel + ethanol)"),
    CNR = list(direction = "<=", target = list(type = "base"), unit = "toe",
               label = "Non-renewable fuels (petroleum products + natural gas)"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = share), unit = "jobs",
               label = "Labour (jobs)")
  ),
  # ECO: (I - A) x >= f, uma meta por setor, no último nível, desvios absolutos
  economy = list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute"),
  scenarios = list(CR = list(CR = shock),      # o choque vai para a entrante
                   CNR = list(CNR = shock)),   # o choque vai para a incumbente
  priorities = if (is.null(my_orderings)) "all" else my_orderings,
  corridor = list(use = TRUE, multiplier = 1),
  lock_tolerance = "exact",
  name = "thesis_fuels"
)
print(model)

# As metas, a partir das bases: conta, base, choque e meta total em cada cenário
base <- satellite_base(io)
goals <- data.frame(account = names(base), base = base,
                    goal_CR = build_goals(io, model, "CR")[1:3],
                    goal_CNR = build_goals(io, model, "CNR")[1:3], row.names = NULL)
goals$change_CR <- goals$goal_CR - goals$base
goals$change_CNR <- goals$goal_CNR - goals$base
print(goals)

# ------------------------------------------------------------------------------
# Passo 4. Rodar todas as ordens de todos os cenários e gravar as saídas
# ------------------------------------------------------------------------------
res <- run_model(io, model, verbose = TRUE)
write_outputs(res, out_dir)

# ------------------------------------------------------------------------------
# Passo 5. Todos os resultados
# ------------------------------------------------------------------------------
acc <- names(model$accounts)
s <- res$summary
cat("\n================ Cada rodada (cenário x ordem), nível a nível ================\n")
for (r in res$runs) {
  cat("\n")
  print(r)
}
cat("\n================ Uma linha por rodada ================\n")
print(s$runs[, c("scenario", "label", "priorities", "status", grep("^Z[0-9]+$", names(s$runs), value = TRUE),
                 "delta_x", "delta_x_pct", paste0("delta_", acc), "state")], row.names = FALSE)
cat("\n================ Cada conta em cada rodada: meta e valor alcançado ================\n")
print(s$goals[, c("scenario", "label", "account", "direction", "base", "g", "Gx", "delta", "realized", "at_goal")],
      row.names = FALSE)
cat("\n================ Estados distintos (rodadas cujo x* difere no máximo 1e-6) ================\n")
print(s$states, row.names = FALSE)
cat("", paste("Todos os resultados estão em", out_dir),
    "  results.xlsx  a planilha Excel (comece pela aba about):",
    "    final_<cenário>      xD1-xD3 e f'1-f'72 no último nível, todas as ordens lado a lado",
    "    <cenário>_<ordem>    cada etapa (nível 1 a 4) de uma rodada, lado a lado",
    "    Gx_<cenário>, x_<cenário>, runs, levels, goals, states",
    "  README.md     o relatório; as tabelas CSV trazem os mesmos números", "", sep = "\n")

# ------------------------------------------------------------------------------
# Passo 6. Os números publicados na tese
# ------------------------------------------------------------------------------
# Os números dos combustíveis no capítulo 5: a maior fração do choque
# realizada pelos CR e, nessa fronteira, o comovimento dos CNR, a variação da
# produção (delta x) e das ocupações; o estado em que os CNR ficam exatamente
# na meta, no cenário CNR; o número de estados distintos. Eles vêm das seis
# ordens.
if (is.null(my_orderings)) {
  ind <- thesis_indicators(res, entrant = "CR", incumbent = "CNR", labor = "LAB",
                           entrant_scenario = "CR", incumbent_scenario = "CNR")
  cmp <- compare_thesis(list(fuels = ind))
  cmp <- cmp[cmp$market == "fuels", ]
  cat("\n================ Publicado x reconstruído (combustíveis) ================\n")
  print(cmp[, c("item", "published", "reconstructed", "rounded", "match")], row.names = FALSE, digits = 10)
  cat(sprintf("%d de %d números publicados conferem.\n", sum(cmp$match), nrow(cmp)))
  if (!all(cmp$match)) stop("algum número publicado não confere")
}
