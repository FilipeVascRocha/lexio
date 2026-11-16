#' Write the results to an Excel workbook
#'
#' Writes the results of [run_model()] to one `.xlsx` workbook. In the result
#' sheets, each row is a row of `G`: first the satellite accounts, then the
#' sectors (the economic block ECO). The sheets are:
#'
#' * `about`: the model, the scenarios, the orderings, the accounts, the
#'   notation and what each sheet holds;
#' * `runs`, `levels`, `goals` and `states`: the tables of [summarize_runs()]
#'   (one row per run, per level of each run, per account of each run and per
#'   distinct state);
#' * for each scenario `<s>`:
#'   * `final_<s>`: the last level of every ordering, side by side: the goal
#'     `g` and, for each ordering, `Gx`, `d_minus`, `d_plus` and `x`;
#'   * `Gx_<s>`: `g`, the `Gx` of each ordering and `Gx - g`;
#'   * `x_<s>`: the base output `x0`, the output `x_star` of each ordering
#'     and `delta_x = x_star - x0`;
#' * for each run, `<s>_<ordering>`: every row of `G` at every priority
#'   level, side by side: `g`, then `Gx`, `d_minus`, `d_plus` and `x` of
#'   level 1 to the last (the table `all_levels.csv` of [write_outputs()]).
#'
#' The rows are identified by `row` (the account name or the sector code),
#' `notation` and `name`. In the notation, `xD_j` is `D_j x`, the level of
#' account `j`, and `f'_h` is row `h` of `(I - A) x`, the net output of
#' sector `h`, whose goal is the final demand `f_h`. The column `x` is empty
#' in the account rows.
#'
#' Sheet names are limited to 31 characters by Excel; longer names are
#' shortened.
#'
#' @param res Object of class `lexio_results`.
#' @param file Path of the `.xlsx` file.
#' @param run_sheets If `TRUE` (default), writes one sheet per run. With many
#'   runs (6 accounts give 720 orderings per scenario), `FALSE` keeps the
#'   workbook small; the same tables are in the `all_levels.csv` files of
#'   [write_outputs()].
#' @param overwrite Allows replacing an existing file.
#' @return `file`, invisibly.
#' @examples
#' res <- run_model(system.file("examples", "toy", "model.yml", package = "lexio"), verbose = FALSE)
#' file <- write_excel(res, tempfile(fileext = ".xlsx"))
#' @export
write_excel <- function(res, file, run_sheets = TRUE, overwrite = FALSE) {
  if (!inherits(res, "lexio_results")) stop("`res` must be a lexio_results object (run_model)", call. = FALSE)
  if (file.exists(file) && !overwrite) {
    stop("the file exists: ", file, " (use overwrite = TRUE or another name)", call. = FALSE)
  }
  writexl::write_xlsx(excel_sheets(res, run_sheets), file)
  invisible(file)
}

# The sheets of the workbook, as a named list of data frames.
excel_sheets <- function(res, run_sheets = TRUE) {
  s <- res$summary
  if (is.null(s$levels)) s <- summarize_runs(res$runs)
  runs <- res$runs
  info <- g_rows(runs[[1]], res$model)
  k <- length(runs[[1]]$accounts)
  scen <- unique(vapply(runs, `[[`, character(1), "scenario"))
  last_level <- function(r) r$levels[[length(r$levels)]]

  sheets <- list(about = excel_about(res, s, scen, run_sheets), runs = s$runs, levels = s$levels,
                 goals = s$goals, states = s$states)
  names_out <- names(sheets)
  for (sc in scen) {
    rs <- runs[vapply(runs, function(r) identical(r$scenario, sc), logical(1))]
    fin <- info
    fin$g <- as.numeric(rs[[1]]$g)
    gx <- fin
    xs <- data.frame(row = rs[[1]]$baseline$codes, name = rs[[1]]$baseline$names, x0 = rs[[1]]$baseline$x,
                     stringsAsFactors = FALSE)
    for (r in rs) {
      L <- last_level(r)
      fin[[paste0(r$label, "_Gx")]] <- as.numeric(L$gx)
      fin[[paste0(r$label, "_d_minus")]] <- as.numeric(L$d_minus)
      fin[[paste0(r$label, "_d_plus")]] <- as.numeric(L$d_plus)
      fin[[paste0(r$label, "_x")]] <- c(rep(NA_real_, k), L$x)
      gx[[paste0(r$label, "_Gx")]] <- as.numeric(L$gx)
    }
    for (r in rs) gx[[paste0(r$label, "_Gx_minus_g")]] <- as.numeric(last_level(r)$gx) - gx$g
    for (r in rs) xs[[paste0(r$label, "_x")]] <- r$x_star
    for (r in rs) xs[[paste0(r$label, "_delta_x")]] <- r$x_star - r$baseline$x
    sheets <- c(sheets, list(fin, gx, xs))
    names_out <- c(names_out, paste0(c("final_", "Gx_", "x_"), sc))
  }
  if (run_sheets) {
    for (r in runs) {
      sheets <- c(sheets, list(all_levels_table(r, info)))
      names_out <- c(names_out, paste0(r$scenario, "_", r$label))
    }
  }
  names(sheets) <- excel_sheet_names(names_out)
  sheets
}

# Identification of the rows of G: the accounts, then the sectors.
g_rows <- function(r, model) {
  k <- length(r$accounts)
  n <- length(r$baseline$codes)
  acc_label <- vapply(r$accounts, function(a) {
    lab <- model$accounts[[a]]$label
    if (is.null(lab)) a else lab
  }, character(1))
  data.frame(row = c(r$accounts, r$baseline$codes),
             notation = c(paste0("xD", seq_len(k)), paste0("f'", seq_len(n))),
             name = c(unname(acc_label), r$baseline$names),
             block = c(rep("account", k), rep("ECO", n)), stringsAsFactors = FALSE)
}

# Every row of G at every level of a run, side by side.
all_levels_table <- function(r, info) {
  k <- length(r$accounts)
  out <- info
  out$g <- as.numeric(r$g)
  for (lev in seq_along(r$levels)) {
    L <- r$levels[[lev]]
    out[[sprintf("level%d_Gx", lev)]] <- as.numeric(L$gx)
    out[[sprintf("level%d_d_minus", lev)]] <- as.numeric(L$d_minus)
    out[[sprintf("level%d_d_plus", lev)]] <- as.numeric(L$d_plus)
    out[[sprintf("level%d_x", lev)]] <- c(rep(NA_real_, k), L$x)
  }
  out
}

# The sheet `about`: two columns, item and content.
excel_about <- function(res, s, scen, run_sheets) {
  m <- res$model
  acc <- names(m$accounts)
  ord <- unique(s$runs[, c("label", "priorities")])
  n_levels <- max(s$levels$level)
  item <- function(name, content) data.frame(item = c(name, rep("", length(content) - 1)), content = content,
                                             stringsAsFactors = FALSE)
  acc_txt <- vapply(acc, function(a) {
    sp <- m$accounts[[a]]
    sprintf("%s: %s%s, direction %s", a, sp$label, if (nzchar(sp$unit)) paste0(" (", sp$unit, ")") else "",
            sp$direction)
  }, character(1))
  notation <- c(
    "row: account name or sector code",
    "xD_j = D_j x, the level of account j; f'_h = row h of (I - A) x, the net output of sector h",
    "g: goal; Gx: achieved value; d_minus, d_plus: deviation below and above the goal (Gx + d_minus - d_plus = g)",
    "x: output of each sector (x0 = base, x_star = solution of the last level); delta_x = x_star - x0",
    "units: each account in its own unit; the sector rows and x in the currency unit of the database"
  )
  sheets <- c(
    paste("runs: one row per run (status of each level, 0 = optimal; infeasible_level, the first level without",
          "solution, blank if none; Z of each level; delta x; change of each account)"),
    paste("levels: one row per priority level of each run (its goals, optimum Z, GLPK status, violation of its",
          "constraints by the solution)"),
    paste("goals: one row per account of each run (base, goal g, achieved Gx, realized share of the intended change,",
          "blank when the goal equals the base)"),
    "states: the distinct final states (runs whose x_star differ by at most 1e-6)",
    "final_<scenario>: the last level of every ordering side by side (g; Gx, d_minus, d_plus and x of each one)",
    "Gx_<scenario>: g, Gx of each ordering and Gx - g",
    "x_<scenario>: x0, x_star of each ordering and delta_x",
    if (run_sheets) {
      "<scenario>_<ordering>: one sheet per run, all levels side by side (g; Gx, d_minus, d_plus and x of each level)"
    } else {
      "one sheet per run: not written (run_sheets = FALSE); see runs/<scenario>/<ordering>/all_levels.csv"
    }
  )
  rbind(
    item("Model", m$name),
    item("Produced", sprintf("%s with lexio %s, %s, GLPK %s", res$meta$date, res$meta$lexio, res$meta$R,
                             res$meta$GLPK)),
    item("Database", sprintf("%d sectors; corridor: %s", res$io$n,
                             paste(unique(s$runs$corridor), collapse = "; "))),
    item("Accounts", unname(acc_txt)),
    item("Scenarios", scen),
    item("Orderings", paste0(ord$label, ": ", ord$priorities)),
    item("Levels", sprintf("up to %d per run, in the order of the ordering; ECO is the economic block", n_levels)),
    item("Notation", notation),
    item("Sheets", sheets)
  )
}

# Valid and unique Excel sheet names: without []:*?/\, at most 31 characters,
# unique regardless of case.
excel_sheet_names <- function(x) {
  x <- substr(gsub("[\\[\\]:*?/\\\\]", "_", x, perl = TRUE), 1, 31)
  seen <- character(0)
  for (i in seq_along(x)) {
    base <- x[i]
    j <- 1
    while (tolower(x[i]) %in% seen) {
      j <- j + 1
      suffix <- paste0("~", j)
      x[i] <- paste0(substr(base, 1, 31 - nchar(suffix)), suffix)
    }
    seen <- c(seen, tolower(x[i]))
  }
  x
}
