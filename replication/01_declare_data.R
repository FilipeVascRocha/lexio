# Declares the database of the thesis in the lexio format, from the
# input-output matrix of Brazil with energy-sector detail published by EPE
# (base year 2018, built by EPE and FIPE).
#
# This step is optional: the same files are attached to the GitHub release of
# lexio (lexio-thesis-data-2018.zip), and 02_reproduce.R downloads them when
# they are missing. Run this script to build them yourself from the public
# workbook. The release file also keeps a copy of the EPE workbook, unchanged,
# in data/: unzipped in replication/, it is where this script looks for it.
#
# Source: EPE, "Nota Técnica — Matriz Insumo Produto com detalhamento do setor
# energético: notas e tabelas auxiliares", file MIP_EPE_Divulgação.xlsx,
# sheet "Usos SxS":
#   https://www.epe.gov.br/pt/publicacoes-dados-abertos/publicacoes/nota-tecnica-matriz-insumo-produto-com-detalhamento-do-setor-energetico-notas-e-tabelas-auxiliares
# Method: EPE and FIPE, "Metodologia para construção de uma Matriz
# Insumo-Produto com detalhamento dos setores energéticos" (joint technical
# note, Dec. 2023).
#
# What is read from the sheet (rows and columns), in the notation of the
# thesis (section 4.2):
#   sectors      codes (row 2) and names (row 3) of columns D:BW (72 sectors)
#   Z            intermediate consumption, D5:BW76 (R$ million)
#   f            final demand, CF5:CF76
#   x            gross output, CG5:CG76
#   E_LAB        jobs, row 102
#   energy       rows 125 (petroleum products), 126 (biodiesel), 127 (ethanol),
#                128 (electricity, centralized generation), 129 (distributed
#                generation) and 130 (natural gas), in thousand toe; converted
#                to toe (x 1000)
#   fuels        E_CR = biodiesel + ethanol; E_CNR = petroleum products + natural
#                gas; corridor alpha_h = (row 23 + row 47 + row 24 + row 26) / x_h,
#                the intersectoral purchases of petroleum products, natural gas,
#                biodiesel and biofuels as a proportion of output
#   electricity  E_GD = row 129; E_GC = row 128; corridor alpha_h =
#                (row 44 + row 45) / x_h, the intersectoral purchases of
#                electricity as a proportion of output
#
# Output, in thesis_data/<market>/ (market = fuels, electricity):
#   base/            the declared flows: sectors, Z, x, f, E (levels) and corridor (alpha)
#   model.yml        the model of the thesis, with the goals declared by their rules
#   coefficients/    B = I - A, D, x, f and alpha rounded to 15 significant digits,
#                    as stored in the computations of the thesis
#   model_exact.yml  the same model, with the goals of each scenario rounded in
#                    the same way; with coefficients/, the problem is identical
#                    to the one solved in the thesis
# and thesis_data/README.md (English) and README.pt-BR.md (Portuguese).
#
# Usage, from the root of the repository (RStudio: open lexio.Rproj, then
# Source this file):
#   Rscript replication/01_declare_data.R [path/to/MIP_EPE_Divulgação.xlsx] [--out folder]
# Without a path, the workbook is looked for in replication/data/. The output
# folder must not exist (default replication/thesis_data).

library(lexio)
here <- file.path(here::here(), "replication")

args <- commandArgs(trailingOnly = TRUE)
i <- match("--out", args)
out_root <- if (is.na(i)) file.path(here, "thesis_data") else args[i + 1]
if (!is.na(i)) args <- args[-c(i, i + 1)]
if (dir.exists(out_root)) stop(out_root, " already exists; remove it or use --out with another folder")
xlsx <- if (length(args)) args[1] else {
  cand <- file.path(here, "data", c("MIP_EPE_Divulgação.xlsx", "MIP_EPE_Divulgacao.xlsx"))
  cand <- cand[file.exists(cand)]
  if (!length(cand)) stop("put MIP_EPE_Divulgação.xlsx (EPE) in replication/data/ or give its path")
  cand[1]
}
sheet <- "Usos SxS"
if (!sheet %in% readxl::excel_sheets(xlsx)) stop("the workbook has no sheet \"", sheet, "\"")
xlsx_sha <- digest::digest(xlsx, algo = "sha256", file = TRUE)
cat("workbook:", xlsx, "\nSHA-256:", xlsx_sha, "\n")

rd <- function(range) {
  m <- as.matrix(suppressMessages(readxl::read_excel(xlsx, sheet = sheet, range = range, col_names = FALSE)))
  dimnames(m) <- NULL
  m
}
row_vec <- function(r) as.numeric(rd(paste0("D", r, ":BW", r)))
txt <- as.matrix(suppressMessages(readxl::read_excel(xlsx, sheet = sheet, range = "D2:BW3", col_names = FALSE,
                                                     col_types = "text")))
sectors <- data.frame(code = as.character(txt[1, ]), name = as.character(txt[2, ]), stringsAsFactors = FALSE)
Z <- rd("D5:BW76")
f <- as.numeric(rd("CF5:CF76"))
x <- as.numeric(rd("CG5:CG76"))
E_LAB <- row_vec(102)
energy <- lapply(c(PTRL = 125, BDSL = 126, ETAN = 127, GC = 128, GD = 129, NGAS = 130), function(r) {
  v <- row_vec(r)
  v[is.na(v)] <- 0
  v * 1000   # thousand toe -> toe
})
dimnames(Z) <- list(sectors$code, sectors$code)

markets <- list(
  fuels = list(
    E = list(CR = energy$BDSL + energy$ETAN, CNR = energy$PTRL + energy$NGAS, LAB = E_LAB),
    alpha = ((row_vec(23) + row_vec(47)) + (row_vec(24) + row_vec(26))) / x,
    share = "0.05",
    labels = c(CR = "Renewable fuels (biodiesel + ethanol)",
               CNR = "Non-renewable fuels (petroleum products + natural gas)",
               LAB = "Labour (jobs)")
  ),
  electricity = list(
    E = list(GD = energy$GD, GC = energy$GC, LAB = E_LAB),
    alpha = (row_vec(44) + row_vec(45)) / x,
    share = "0.01",
    labels = c(GD = "Electricity, distributed generation",
               GC = "Electricity, centralized generation",
               LAB = "Labour (jobs)")
  )
)

# Rounding to 15 significant digits: a number written to CSV with write.table
# and read back. The computations of the thesis stored the coefficients and the
# goals in this way between their steps.
round15 <- function(v) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  utils::write.table(v, tmp, sep = ";", dec = ",", row.names = FALSE, col.names = FALSE)
  out <- as.matrix(utils::read.csv2(tmp, header = FALSE))
  dimnames(out) <- NULL
  out
}

# A number as the shortest decimal (15 to 17 significant digits) that R reads
# back as the same double.
exact <- function(v) {
  vapply(v, function(z) {
    for (d in 15:17) {
      s <- trimws(formatC(z, digits = d, format = "g"))
      if (as.numeric(s) == z) return(s)
    }
    s
  }, character(1), USE.NAMES = FALSE)
}

# The text of the two model files.
account_block <- function(a, label, direction, target) {
  c(sprintf("  %s:", a), sprintf("    label: %s", label),
    sprintf("    unit: %s", if (a == "LAB") "jobs" else "toe"),
    sprintf("    direction: \"%s\"", direction), sprintf("    target: %s", target))
}
common_tail <- c(
  "",
  "# Economic block ECO: G_h x = (I - A) x >= f, one goal per sector, fixed at the",
  "# last level (it absorbs the final impact), with absolute deviations (R$ million).",
  "economy:", "  direction: \">=\"", "  target: final_demand", "  position: last", "  deviation: absolute",
  "",
  "# The corridor declared with the data (alpha_h, a proportion of |g_h|), on both sides.",
  "corridor:", "  use: true", "  multiplier: 1"
)
model_tail <- function(e, i) c(
  "",
  "# One account per level, all 3! = 6 orderings (P01 to P06, P1 to P6 in the",
  "# thesis), ECO last. To run only some orderings, list them instead, e.g.",
  "#   priorities:",
  sprintf("#     only_one: [%s, %s, LAB]", i, e),
  "priorities: all",
  "",
  "# Exact lock d_l == Z_l on the levels already solved.",
  "lock_tolerance: exact"
)

for (m in names(markets)) {
  b <- markets[[m]]
  acc <- names(b$E)
  e <- acc[1]
  inc <- acc[2]
  dir_m <- file.path(out_root, m)

  # base/: the database as published (flows and levels), with every digit
  io <- declare_io(Z = Z, x = x, f = f, E = b$E, corridor = b$alpha, sectors = sectors)
  print(io)
  write_io(io, file.path(dir_m, "base"))
  back <- read_io(file.path(dir_m, "base"))
  stopifnot(identical(back$B, io$B), identical(back$D, io$D), identical(back$floor, io$floor))

  # model.yml: the goals by their rules
  writeLines(enc2utf8(c(
    sprintf("# Model of the thesis: %s market (EPE/FIPE input-output matrix, base year 2018).", m),
    "# Each scenario applies the shock to one of the two energy accounts; labour",
    "# grows by the same share. Six orderings per scenario.",
    sprintf("name: thesis_%s", m),
    "data: base",
    "",
    "# Entrant (>=, floor), incumbent (<=, ceiling) and labour (>=).",
    "accounts:",
    account_block(e, b$labels[[e]], ">=", "{type: base}"),
    account_block(inc, b$labels[[inc]], "<=", "{type: base}"),
    account_block("LAB", b$labels[["LAB"]], ">=", sprintf("{type: growth, rate: %s}", b$share)),
    common_tail,
    "",
    "# The two shocks: a share of the pooled base of the two energy accounts.",
    "scenarios:",
    sprintf("  %s:", e), sprintf("    %s: {type: pooled_share, share: %s, pool: [%s, %s]}", e, b$share, e, inc),
    sprintf("  %s:", inc), sprintf("    %s: {type: pooled_share, share: %s, pool: [%s, %s]}", inc, b$share, e, inc),
    model_tail(e, inc))), file.path(dir_m, "model.yml"), useBytes = TRUE)
  mm <- read_model(file.path(dir_m, "model.yml"))
  stopifnot(length(mm$scenarios) == 2, length(mm$orderings) == 6, identical(mm$lock_tolerance, 0))

  # coefficients/: B, D, x, f and alpha rounded to 15 significant digits
  D15 <- lapply(stats::setNames(acc, acc), function(a) as.numeric(round15(io$D[match(a, io$accounts), , drop = FALSE])))
  io_c <- declare_io(B = round15(io$B), D = D15, x = as.numeric(round15(matrix(io$x, ncol = 1))),
                     f = as.numeric(round15(matrix(io$f, ncol = 1))),
                     corridor = as.numeric(round15(matrix(io$floor, ncol = 1))), sectors = sectors)
  write_io(io_c, file.path(dir_m, "coefficients"))
  back_c <- read_io(file.path(dir_m, "coefficients"))
  stopifnot(identical(back_c$B, io_c$B), identical(back_c$D, io_c$D), identical(back_c$floor, io_c$floor),
            identical(back_c$x, io_c$x), identical(back_c$f, io_c$f))

  # model_exact.yml: the goals of each scenario, computed from base/ by the
  # rules of model.yml and rounded to 15 significant digits
  goals <- lapply(stats::setNames(names(mm$scenarios), names(mm$scenarios)), function(sc) {
    as.numeric(round15(matrix(build_goals(io, mm, sc), ncol = 1)))
  })
  base_c <- satellite_base(io_c, acc)
  dirs <- vapply(mm$accounts, `[[`, character(1), "direction")
  yml <- c(sprintf("# Exact reproduction of the thesis: %s market.", m),
           "# The coefficients (coefficients/) and the goals below are rounded to 15 significant",
           "# digits, as stored in the computations of the thesis; with them the problem is identical",
           "# to the one solved in the thesis. Each goal is the total level of the account in the",
           "# scenario (base + shock; labour x (1 + share)). model.yml declares the same goals by",
           "# their rules.",
           sprintf("name: thesis_%s_exact", m), "data: coefficients", "", "accounts:")
  for (j in seq_along(acc)) {
    yml <- c(yml, account_block(acc[j], b$labels[[acc[j]]], dirs[[j]],
                                sprintf("{type: level, value: %s}", exact(base_c[[j]]))))
  }
  yml <- c(yml, common_tail, "", "scenarios:")
  for (sc in names(goals)) {
    yml <- c(yml, sprintf("  %s:", sc))
    for (j in seq_along(acc)) {
      yml <- c(yml, sprintf("    %s: {type: level, value: %s}", acc[j], exact(goals[[sc]][j])))
    }
  }
  yml <- c(yml, model_tail(e, inc))
  writeLines(enc2utf8(yml), file.path(dir_m, "model_exact.yml"), useBytes = TRUE)
  me <- read_model(file.path(dir_m, "model_exact.yml"))
  for (sc in names(goals)) stopifnot(identical(build_goals(back_c, me, sc), goals[[sc]]))
}

epe_url <- paste0("https://www.epe.gov.br/pt/publicacoes-dados-abertos/publicacoes/nota-tecnica-matriz-insumo-",
                  "produto-com-detalhamento-do-setor-energetico-notas-e-tabelas-auxiliares")
writeLines(enc2utf8(c(
  "# Database of the thesis, declared for lexio",
  "",
  "Filipe Vasconcelos Rocha (ORCID 0000-0002-0927-3799), Programa de Pós-graduação em Economia,",
  "Universidade Federal de Juiz de Fora (PPGE/UFJF).",
  "",
  "The database of the doctoral thesis in the format of the lexio package, for the fuel and",
  "electricity markets of Brazil, base year 2018. Portuguese version: `README.pt-BR.md`.",
  "",
  "## The release file",
  "",
  "`lexio-thesis-data-2018.zip`, attached to the release v1.0.0 of lexio",
  "(https://github.com/FilipeVascRocha/lexio/releases/tag/v1.0.0), holds two folders. Unzip it in",
  "`replication/` of the lexio repository and run the scripts described in `replication/README.md`.",
  "",
  "- `thesis_data/`: this folder, the declared database described below, with `metadata.xlsx`, a",
  "  dictionary of every file and column, in English and Portuguese;",
  "- `data/`: the EPE workbook `MIP_EPE_Divulgacao.xlsx` (`MIP_EPE_Divulgação.xlsx` on the EPE",
  "  site), unchanged, so that the database can be rebuilt even if the workbook leaves the EPE",
  "  site. `replication/01_declare_data.R` reads it from `replication/data/`.",
  "",
  "## Source",
  "",
  "Input-output matrix of Brazil with energy-sector detail, base year 2018, published by",
  "Empresa de Pesquisa Energética (EPE) and built with FIPE:",
  "",
  "- EPE. Nota Técnica — Matriz Insumo Produto com detalhamento do setor energético: notas e tabelas",
  "  auxiliares. Rio de Janeiro: EPE, 2026. File `MIP_EPE_Divulgação.xlsx`, sheet \"Usos SxS\".",
  paste0("  ", epe_url),
  "- EPE; FIPE. Metodologia para construção de uma Matriz Insumo-Produto com detalhamento dos setores",
  "  energéticos. Nota Técnica conjunta. Rio de Janeiro: EPE, Dec. 2023.",
  "",
  paste0("SHA-256 of the workbook used: `", xlsx_sha, "`."),
  "",
  "## Contents (notation of the thesis, section 4.2)",
  "",
  "One folder per market, `fuels/` and `electricity/`, with:",
  "",
  "- `base/`: the database as published, with every digit:",
  "  - `sectors`, `Z` (intermediate consumption, D5:BW76), `x` (gross output, CG5:CG76) and `f`",
  "    (final demand, CF5:CF76), the same in both markets (72 sectors, R$ million of 2018);",
  "  - `E`, the levels of the satellite accounts: energy in toe (the EPE workbook gives thousand",
  "    toe, multiplied here by 1,000) and labour in jobs (row 102). Fuels: CR = biodiesel + ethanol",
  "    (rows 126 + 127), CNR = petroleum products + natural gas (rows 125 + 130). Electricity:",
  "    GD = distributed generation (row 129), GC = centralized generation (row 128);",
  "  - `corridor` (column `alpha`): the proportion alpha_h of |g_h| that bounds the deviations of",
  "    the economic goals. It is the intersectoral purchase of the energy products of the market",
  "    divided by the output of the sector: fuels, (rows 23 + 47 + 24 + 26) / x; electricity,",
  "    (rows 44 + 45) / x.",
  "- `model.yml`: the model of the thesis, with the goals declared by their rules (a shock of 5% in",
  "  fuels and of 1% in electricity, applied to the entrant or to the incumbent; labour +5% or +1%;",
  "  six orderings per scenario).",
  "- `coefficients/` and `model_exact.yml`: the coefficients (B = I - A, D, x, f, alpha) and the goals",
  "  rounded to 15 significant digits, as stored in the computations of the thesis. With them the",
  "  problem is identical to the one solved in the thesis.",
  "",
  "Built by `replication/01_declare_data.R` from the EPE workbook. The numbers are written with up",
  "to 17 significant digits; the CSV files use `,` as separator and `.` as decimal mark."
)), file.path(out_root, "README.md"), useBytes = TRUE)
writeLines(enc2utf8(c(
  "# Base de dados da tese, declarada para o lexio",
  "",
  "Filipe Vasconcelos Rocha (ORCID 0000-0002-0927-3799), Programa de Pós-graduação em Economia,",
  "Universidade Federal de Juiz de Fora (PPGE/UFJF).",
  "",
  "A base de dados da tese de doutorado no formato do pacote lexio, para os mercados de",
  "combustíveis e de eletricidade do Brasil, ano-base 2018. Versão em inglês: `README.md`.",
  "",
  "## O arquivo da release",
  "",
  "`lexio-thesis-data-2018.zip`, anexado à release v1.0.0 do lexio",
  "(https://github.com/FilipeVascRocha/lexio/releases/tag/v1.0.0), tem duas pastas. Descompacte-o",
  "em `replication/` do repositório do lexio e rode os scripts descritos em",
  "`replication/README.pt-BR.md`.",
  "",
  "- `thesis_data/`: esta pasta, a base declarada descrita abaixo, com o `metadata.xlsx`, um",
  "  dicionário de todos os arquivos e colunas, em inglês e em português;",
  "- `data/`: a planilha da EPE `MIP_EPE_Divulgacao.xlsx` (`MIP_EPE_Divulgação.xlsx` no site da",
  "  EPE), sem nenhuma alteração, para que a base possa ser refeita mesmo que a planilha saia do",
  "  site da EPE. O `replication/01_declare_data.R` a lê em `replication/data/`.",
  "",
  "## Fonte",
  "",
  "Matriz de insumo-produto do Brasil com detalhamento do setor energético, ano-base 2018,",
  "publicada pela Empresa de Pesquisa Energética (EPE) e construída com a FIPE:",
  "",
  "- EPE. Nota Técnica — Matriz Insumo Produto com detalhamento do setor energético: notas e tabelas",
  "  auxiliares. Rio de Janeiro: EPE, 2026. Arquivo `MIP_EPE_Divulgação.xlsx`, aba \"Usos SxS\".",
  paste0("  ", epe_url),
  "- EPE; FIPE. Metodologia para construção de uma Matriz Insumo-Produto com detalhamento dos setores",
  "  energéticos. Nota Técnica conjunta. Rio de Janeiro: EPE, dez. 2023.",
  "",
  paste0("SHA-256 da planilha usada: `", xlsx_sha, "`."),
  "",
  "## Conteúdo (notação da tese, seção 4.2)",
  "",
  "Uma pasta por mercado, `fuels/` (combustíveis) e `electricity/` (eletricidade), com:",
  "",
  "- `base/`: a base como publicada, com todos os algarismos:",
  "  - `sectors`, `Z` (consumo intermediário, D5:BW76), `x` (valor bruto da produção, CG5:CG76) e",
  "    `f` (demanda final, CF5:CF76), iguais nos dois mercados (72 setores, R$ milhões de 2018);",
  "  - `E`, os níveis das contas satélite: energia em tep (a planilha da EPE dá mil tep,",
  "    multiplicados aqui por 1.000) e trabalho em ocupações (linha 102). Combustíveis: CR = biodiesel",
  "    + etanol (linhas 126 + 127), CNR = derivados de petróleo + gás natural (linhas 125 + 130).",
  "    Eletricidade: GD = geração distribuída (linha 129), GC = geração centralizada (linha 128);",
  "  - `corridor` (coluna `alpha`): a proporção alpha_h de |g_h| que limita os desvios das metas",
  "    econômicas. É a compra intersetorial dos produtos energéticos do mercado dividida pela",
  "    produção do setor: combustíveis, (linhas 23 + 47 + 24 + 26) / x; eletricidade,",
  "    (linhas 44 + 45) / x.",
  "- `model.yml`: o modelo da tese, com as metas declaradas pelas suas regras (choque de 5% nos",
  "  combustíveis e de 1% na eletricidade, aplicado ao entrante ou ao incumbente; trabalho +5% ou",
  "  +1%; seis ordens por cenário).",
  "- `coefficients/` e `model_exact.yml`: os coeficientes (B = I - A, D, x, f, alpha) e as metas",
  "  arredondados a 15 algarismos significativos, como guardados nas contas da tese. Com eles, o",
  "  problema é idêntico ao resolvido na tese.",
  "",
  "Feita pelo `replication/01_declare_data.R` a partir da planilha da EPE. Os números estão escritos",
  "com até 17 algarismos significativos; os CSV usam `,` como separador e `.` como marca decimal."
)), file.path(out_root, "README.pt-BR.md"), useBytes = TRUE)
cat("ok: database of the thesis declared in", out_root, "\n")
