# Helpers of the replication of the thesis:
#   thesis_data_dir()     the folder of the declared database, downloaded if missing
#   new_output_dir()      a new output folder (nothing is overwritten)
#   thesis_indicators()   the indicators reported in chapter 5 of the thesis
#   thesis_published()    the values printed in the thesis
#   compare_thesis()      reconstructed x published values
# They use only the public functions of lexio.
#
# Rocha, F. V. (2026). Modelo generalizado de insumo-produto com Goal
# Programming preemptivo aplicado à transição energética brasileira:
# eletricidade e combustíveis na estrutura produtiva de 2018. Doctoral thesis,
# Programa de Pós-graduação em Economia, Universidade Federal de Juiz de Fora.

# The data are the attachment of the release v1.0.0, whatever the latest
# release is; the file is checked against its SHA-256 before use.
data_url <- "https://github.com/FilipeVascRocha/lexio/releases/download/v1.0.0/lexio-thesis-data-2018.zip"
data_sha256 <- "36e109d140be7661554b857385d836fa8e3831317377e8cc1f134d9cb60f3ecc"

# The folder replication/thesis_data. If it is missing, the attachment of the
# GitHub release is downloaded, checked and unzipped there.
thesis_data_dir <- function(replication_dir) {
  dir <- file.path(replication_dir, "thesis_data")
  if (dir.exists(file.path(dir, "fuels")) && dir.exists(file.path(dir, "electricity"))) return(dir)
  zip_file <- file.path(tempdir(), "lexio-thesis-data-2018.zip")
  message("replication/thesis_data not found; downloading ", data_url)
  ok <- tryCatch({
    utils::download.file(data_url, zip_file, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) {
    stop("could not download the data. Download lexio-thesis-data-2018.zip from ",
         "https://github.com/FilipeVascRocha/lexio/releases/tag/v1.0.0 and unzip it in replication/, ",
         "or build the data with replication/01_declare_data.R.", call. = FALSE)
  }
  sha <- digest::digest(zip_file, algo = "sha256", file = TRUE)
  if (!identical(sha, data_sha256)) {
    stop("the downloaded file has SHA-256 ", sha, ", not ", data_sha256, " (the data of the thesis); ",
         "nothing was unzipped.", call. = FALSE)
  }
  message("SHA-256 checked: ", sha)
  utils::unzip(zip_file, exdir = replication_dir)
  dir
}

# A new folder <base>, or <base>_2, <base>_3, ... if it exists.
new_output_dir <- function(base) {
  out <- base
  n <- 1
  while (dir.exists(out)) {
    n <- n + 1
    out <- paste0(base, "_", n)
  }
  out
}

# Indicators of one market, from the runs of the two shock scenarios (on the
# entrant and on the incumbent):
# - the largest share of the shock realized by the entrant, in the entrant
#   scenario; the frontier is the run where the entrant achieves the most;
# - at the frontier: the ratio change of the incumbent / change of the
#   entrant, the change in total output (delta_x) and the change in jobs;
# - delta_x and the change in jobs in the state where the incumbent is exactly
#   at its goal, in the incumbent scenario;
# - the number of distinct states.
thesis_indicators <- function(runs, entrant, incumbent, labor, entrant_scenario, incumbent_scenario,
                              tol = 1e-6, goal_tol = 1e-9) {
  s <- summarize_runs(runs, tol = tol, goal_tol = goal_tol)
  tab <- s$runs
  gl <- s$goals
  ent <- gl[gl$scenario == entrant_scenario & gl$account == entrant, ]
  if (!nrow(ent)) stop("no runs of the scenario ", entrant_scenario, call. = FALSE)
  front <- ent[which.max(ent$Gx), ]
  fr <- tab[tab$scenario == front$scenario & tab$label == front$label, ]
  inc <- gl[gl$scenario == incumbent_scenario & gl$account == incumbent & gl$at_goal, ]
  ir <- if (nrow(inc)) tab[tab$scenario == inc$scenario[1] & tab$label == inc$label[1], ] else NULL
  data.frame(
    n_states = length(unique(tab$state)),
    max_realized_share = front$realized,
    frontier_state = fr$state,
    frontier_ratio = fr[[paste0("delta_", incumbent)]] / fr[[paste0("delta_", entrant)]],
    frontier_delta_x = fr$delta_x,
    frontier_delta_x_pct = fr$delta_x_pct,
    frontier_delta_jobs = fr[[paste0("delta_", labor)]],
    incumbent_goal_state = if (nrow(inc)) paste(unique(inc$state), collapse = ",") else NA_character_,
    incumbent_goal_delta_x = if (!is.null(ir)) ir$delta_x else NA_real_,
    incumbent_goal_delta_x_pct = if (!is.null(ir)) ir$delta_x_pct else NA_real_,
    incumbent_goal_delta_jobs = if (!is.null(ir)) ir[[paste0("delta_", labor)]] else NA_real_,
    stringsAsFactors = FALSE
  )
}

# The values printed in chapters 3 and 5 of the thesis, with the column of
# thesis_indicators() they come from, the conversion to the printed unit and
# the number of decimal places used in print.
thesis_published <- function() {
  data.frame(
    item = c("Largest share of the shock realized by the entrant (GD, %)",
             "Largest share of the shock realized by the entrant (CR, %)",
             "Co-movement at the frontier (toe GC per toe GD)",
             "Co-movement at the frontier (toe CNR per toe CR)",
             "Fuels frontier: delta x (R$ billion)",
             "Fuels frontier: delta x (%)",
             "Fuels frontier: delta jobs (million)",
             "CNR-at-goal state: delta x (R$ billion)",
             "CNR-at-goal state: delta x (%)",
             "CNR-at-goal state: delta jobs (million)",
             "Distinct states (electricity)",
             "Distinct states (fuels)"),
    market = c("electricity", "fuels", "electricity", "fuels", rep("fuels", 6), "electricity", "fuels"),
    field = c("max_realized_share", "max_realized_share", "frontier_ratio", "frontier_ratio",
              "frontier_delta_x", "frontier_delta_x_pct", "frontier_delta_jobs",
              "incumbent_goal_delta_x", "incumbent_goal_delta_x_pct", "incumbent_goal_delta_jobs",
              "n_states", "n_states"),
    scale = c(100, 100, 1, 1, 1e-3, 100, 1e-6, 1e-3, 100, 1e-6, 1, 1),
    published = c(31.0, 27.2, 6.06, 4.42, 284.8, 2.39, 1.72, 254.4, 2.13, 1.63, 5, 4),
    decimals = c(1, 1, 2, 2, 1, 2, 2, 1, 2, 2, 0, 0),
    stringsAsFactors = FALSE
  )
}

# The reconstructed indicators next to the published ones, rounded to the
# same decimal places. `indicators` is a named list (fuels, electricity) of
# outputs of thesis_indicators(); a market left out gives NA in its rows.
compare_thesis <- function(indicators) {
  pub <- thesis_published()
  pub$reconstructed <- mapply(function(m, f, s) {
    d <- indicators[[m]]
    if (is.null(d) || !f %in% names(d)) NA_real_ else as.numeric(d[[f]][1]) * s
  }, pub$market, pub$field, pub$scale)
  pub$rounded <- round(pub$reconstructed, pub$decimals)
  pub$match <- !is.na(pub$rounded) & abs(pub$rounded - pub$published) < 1e-9
  pub[, c("item", "market", "published", "reconstructed", "rounded", "match")]
}
