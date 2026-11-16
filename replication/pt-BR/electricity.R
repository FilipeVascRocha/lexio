# O modelo da tese, passo a passo: o mercado de ELETRICIDADE.
# (Cópia de replication/electricity.R com os comentários em português.)
#
# Geração distribuída (GD, a entrante) contra geração centralizada (GC, a
# incumbente), com o trabalho (LAB), na matriz de insumo-produto do Brasil com
# detalhamento do setor energético (EPE/FIPE, 72 setores, ano-base 2018). Leia
# o script de cima para baixo: cada objeto do modelo é declarado aqui, em
# código R. O fuels.R faz o mesmo para o mercado de combustíveis, e o
# 02_reproduce.R roda os dois mercados com todas as conferências.
#
# Notação da tese (seção 4.2) e nomes no lexio:
#   x     valor bruto da produção (n)               declare_io(x = )
#   f     demanda final (n)                         declare_io(f = )
#   B     I - A, A = coeficientes técnicos          declare_io(B = )
#   D     coeficientes das contas (conta por unidade de produção)  declare_io(D = list(...))
#   alpha corredor, uma proporção de |g_h|          declare_io(corridor = )
#   G, g  G = [D; B] e as metas g = (g_D, f)        build_goals()
#   P_l   nível de prioridade l                     define_model(priorities = )
#   ECO   o bloco econômico (as linhas de B)        sempre o último nível
#
# Saída: todos os resultados, numa pasta nova (nada é sobrescrito):
# replication/outputs_electricity, depois _2, _3, ... O console mostra cada
# rodada, nível a nível, as tabelas de resumo e os números publicados.
#
# Uso, na raiz do repositório:
#   RStudio: abra o lexio.Rproj, abra este arquivo e clique em Source (ou rode
#            linha a linha com Ctrl+Enter);
#   terminal: Rscript replication/pt-BR/electricity.R

library(lexio)
replication_dir <- file.path(here::here(), "replication")
source(file.path(replication_dir, "R", "thesis_helpers.R"))
if (!interactive()) options(width = 200)
out_dir <- new_output_dir(file.path(replication_dir, "outputs_electricity"))

# ------------------------------------------------------------------------------
# Passo 0. Onde estão os dados
# ------------------------------------------------------------------------------
# replication/thesis_data/ traz a base da tese no formato do lexio: o anexo
# lexio-thesis-data-2018.zip da release do GitHub (baixado aqui, se a pasta
# não existir), ou a saída do 01_declare_data.R, que a monta a partir da
# planilha pública da EPE.
data_dir <- file.path(thesis_data_dir(replication_dir), "electricity", "coefficients")

# ------------------------------------------------------------------------------
# Passo 1. Os dados, como vetores na sessão do R
# ------------------------------------------------------------------------------
# coefficients/ tem um arquivo CSV por objeto, uma linha por setor (o código
# do setor na primeira coluna):
#   sectors.csv   code, name          os 72 setores e a sua ordem
#   B.csv         code + 72 colunas   B = I - A
#   x.csv         code, value         valor bruto da produção x, R$ milhões
#   f.csv         code, value         demanda final f, R$ milhões
#   D.csv         code, GD, GC, LAB   coeficientes: tep (GD, GC) e ocupações (LAB) por R$ milhão produzido
#   corridor.csv  code, alpha         corredor: compras intersetoriais de eletricidade / x
# São os coeficientes dos fluxos publicados (thesis_data/electricity/base/: Z
# e os níveis E), arredondados a 15 algarismos significativos, como nas contas
# da tese. Os fluxos também podem ser declarados diretamente, com
# declare_io(Z = Z, E = list(GD = E_GD, ...)); o pacote calcula então A, B e D
# (veja o 01_declare_data.R).
read_table <- function(name) {
  utils::read.csv(file.path(data_dir, paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE,
                  colClasses = c(code = "character"), encoding = "UTF-8")
}
sectors <- read_table("sectors")          # código e nome dos 72 setores
B <- as.matrix(read_table("B")[, -1])     # I - A (a primeira coluna é o código)
x <- read_table("x")$value                # valor bruto da produção
f <- read_table("f")$value                # demanda final
D <- read_table("D")
D_GD <- D$GD                              # eletricidade da geração distribuída, tep por R$ milhão
D_GC <- D$GC                              # eletricidade da geração centralizada, tep por R$ milhão
D_LAB <- D$LAB                            # ocupações por R$ milhão
alpha <- read_table("corridor")$alpha     # corredor

# ------------------------------------------------------------------------------
# Passo 2. Declarar a base
# ------------------------------------------------------------------------------
# Cada argumento diz o que o objeto é: B = I - A, x = valor bruto da produção,
# f = demanda final, D = os coeficientes das contas satélite (uma lista
# nomeada: os nomes são os nomes das contas). corridor = alpha limita os dois
# desvios de cada meta econômica, d_h^- <= alpha_h |g_h| e
# d_h^+ <= alpha_h |g_h|; sem ele, o modelo seria solto.
io <- declare_io(B = B, x = x, f = f,
                 D = list(GD = D_GD, GC = D_GC, LAB = D_LAB),
                 corridor = alpha,
                 sectors = sectors)
print(io)            # a base de cada conta, b_j = D_j x

# ------------------------------------------------------------------------------
# Passo 3. Declarar o modelo
# ------------------------------------------------------------------------------
# Direção de cada meta: ">=" é um piso (penaliza a falta d-), "<=" um teto
# (penaliza o excesso d+).
#   GD   entrante,    ">=": não deve ficar abaixo da meta
#   GC   incumbente,  "<=": não deve passar da meta
#   LAB  trabalho,    ">=": cresce a fração do choque (1%)
# A meta de cada conta é o seu nível total no cenário (base + choque), não só
# o choque. O choque é 1% da base conjunta de GD e GC:
#   cenário GD: g_GD = b_GD + 0,01 (b_GD + b_GC), g_GC = b_GC
#   cenário GC: g_GC = b_GC + 0,01 (b_GD + b_GC), g_GD = b_GD
#   nos dois:   g_LAB = b_LAB x 1,01
#
# Ordens de prioridade. Com my_orderings <- NULL, todas as ordens das três
# contas são rodadas: 3! = 6, P01..P06 (P1..P6 na tese). Para rodar só
# algumas, liste-as, por exemplo
#   my_orderings <- list(c("GC", "GD", "LAB"))
# O ECO é sempre o último nível.
share <- 0.01
shock <- list(type = "pooled_share", share = share, pool = c("GD", "GC"))
my_orderings <- NULL
model <- define_model(
  accounts = list(
    GD = list(direction = ">=", target = list(type = "base"), unit = "toe",
              label = "Electricity, distributed generation"),
    GC = list(direction = "<=", target = list(type = "base"), unit = "toe",
              label = "Electricity, centralized generation"),
    LAB = list(direction = ">=", target = list(type = "growth", rate = share), unit = "jobs",
               label = "Labour (jobs)")
  ),
  # ECO: (I - A) x >= f, uma meta por setor, no último nível, desvios absolutos
  economy = list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute"),
  scenarios = list(GD = list(GD = shock),    # o choque vai para a entrante
                   GC = list(GC = shock)),   # o choque vai para a incumbente
  priorities = if (is.null(my_orderings)) "all" else my_orderings,
  # o corredor declarado com os dados, na largura declarada (multiplier = 2 o dobra)
  corridor = list(use = TRUE, multiplier = 1),
  # trava exata dos níveis já resolvidos, d_l == Z_l
  lock_tolerance = "exact",
  name = "thesis_electricity"
)
print(model)

# As metas, a partir das bases: conta, base, choque e meta total em cada cenário
base <- satellite_base(io)
goals <- data.frame(account = names(base), base = base,
                    goal_GD = build_goals(io, model, "GD")[1:3],
                    goal_GC = build_goals(io, model, "GC")[1:3], row.names = NULL)
goals$change_GD <- goals$goal_GD - goals$base
goals$change_GC <- goals$goal_GC - goals$base
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
# Os números da eletricidade no capítulo 5: a maior fração do choque realizada
# pela GD, o comovimento da GC nessa fronteira e o número de estados
# distintos. Eles vêm das seis ordens.
if (is.null(my_orderings)) {
  ind <- thesis_indicators(res, entrant = "GD", incumbent = "GC", labor = "LAB",
                           entrant_scenario = "GD", incumbent_scenario = "GC")
  cmp <- compare_thesis(list(electricity = ind))
  cmp <- cmp[cmp$market == "electricity", ]
  cat("\n================ Publicado x reconstruído (eletricidade) ================\n")
  print(cmp[, c("item", "published", "reconstructed", "rounded", "match")], row.names = FALSE, digits = 10)
  cat(sprintf("%d de %d números publicados conferem.\n", sum(cmp$match), nrow(cmp)))
  if (!all(cmp$match)) stop("algum número publicado não confere")
}
