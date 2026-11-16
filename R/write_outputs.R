#' Write the results
#'
#' Writes the results of [run_model()] to an organized folder:
#'
#' ```
#' <dir>/
#'   README.md            readable report (model, corridor, tables per scenario, states, warnings)
#'   results.xlsx         the Excel workbook of write_excel(): every table below, the final
#'                        results of all orderings side by side and one sheet per run
#'   orderings.csv        one row per scenario x ordering: priorities, GLPK status, lock used,
#'                        Z of each level, delta_x and the change of each account, state
#'   levels.csv           one row per scenario x ordering x priority level (each stage of each
#'                        run): its goals, optimum Z, GLPK status
#'   level_results.csv    every run, every level, every row of G: g, Gx, d_minus, d_plus and,
#'                        in the ECO rows, the output x of the level (all level_<l>.csv in one table)
#'   account_goals.csv    scenario x ordering x account: base, goal g, achieved Gx, delta,
#'                        realized share of the intended change, deviation, state
#'   x_star_all_runs.csv  one row per sector: x0 and the final output x_star of every run
#'   states.csv           distinct states and the runs of each one
#'   runs/<scenario>/<label>_<priorities>/
#'                        all_levels.csv (every row of G, all levels side by side),
#'                        level_<l>.csv (g, Gx, d_minus, d_plus and x of one level)
#'                        and x_star.csv (x0, x_star and delta_x per sector)
#'   inputs/              the model.yml used and the SHA-256 of the database files
#'   results.rds          the full object
#'   session.txt          versions of R, of the packages and of GLPK
#' ```
#'
#' @param res Object of class `lexio_results`.
#' @param dir Destination folder. If it exists and is not empty,
#'   `overwrite = TRUE` is needed.
#' @param format `"intl"` (default: `,` and `.`) or `"br"` (`;` and `,`, for
#'   spreadsheets with a comma as decimal mark) for the tables.
#' @param overwrite Allows writing into a folder that already has files.
#' @param excel If `TRUE` (default), also writes `results.xlsx` with
#'   [write_excel()].
#' @return `dir`, invisibly.
#' @export
write_outputs <- function(res, dir, format = c("intl", "br"), overwrite = FALSE, excel = TRUE) {
  if (!inherits(res, "lexio_results")) stop("`res` must be a lexio_results object (run_model)", call. = FALSE)
  format <- match.arg(format)
  if (dir.exists(dir) && length(list.files(dir)) && !overwrite) {
    stop("the folder exists and is not empty: ", dir, " (use overwrite = TRUE or another folder)", call. = FALSE)
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  sep <- if (format == "br") ";" else ","
  dec <- if (format == "br") "," else "."
  w <- function(df, path) {
    utils::write.table(df, path, sep = sep, dec = dec, row.names = FALSE, qmethod = "double",
                       fileEncoding = "UTF-8")
  }
  s <- res$summary
  if (is.null(s$levels)) s <- summarize_runs(res$runs)
  w(s$runs, file.path(dir, "orderings.csv"))
  w(s$levels, file.path(dir, "levels.csv"))
  w(do.call(rbind, lapply(res$runs, function(r) {
    do.call(rbind, lapply(seq_along(r$levels), function(lev) {
      cbind(data.frame(scenario = r$scenario, ordering = r$ordering, label = r$label, level = lev,
                       level_goals = r$order[lev], stringsAsFactors = FALSE), level_table(r, lev))
    }))
  })), file.path(dir, "level_results.csv"))
  w(s$goals, file.path(dir, "account_goals.csv"))
  first <- res$runs[[1]]$baseline
  xs <- data.frame(code = first$codes, name = first$names, x0 = first$x, stringsAsFactors = FALSE)
  for (r in res$runs) xs[[paste(r$scenario, r$label, sep = "_")]] <- r$x_star
  w(xs, file.path(dir, "x_star_all_runs.csv"))
  w(s$states, file.path(dir, "states.csv"))

  safe <- function(x) gsub("[^A-Za-z0-9_.+-]", "_", x)
  info <- g_rows(res$runs[[1]], res$model)
  for (r in res$runs) {
    run_dir <- file.path(dir, "runs", safe(r$scenario), safe(run_folder(r)))
    dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
    w(all_levels_table(r, info), file.path(run_dir, "all_levels.csv"))
    for (lev in seq_along(r$levels)) w(level_table(r, lev), file.path(run_dir, sprintf("level_%d.csv", lev)))
    w(data.frame(code = r$baseline$codes, name = r$baseline$names, x0 = r$baseline$x, x_star = r$x_star,
                 delta_x = r$x_star - r$baseline$x, stringsAsFactors = FALSE),
      file.path(run_dir, "x_star.csv"))
  }
  if (excel) write_excel(res, file.path(dir, "results.xlsx"), overwrite = TRUE)

  inp <- file.path(dir, "inputs")
  dir.create(inp, showWarnings = FALSE)
  if (!is.null(res$model$source) && file.exists(res$model$source)) {
    file.copy(res$model$source, file.path(inp, "model.yml"), overwrite = TRUE)
  }
  src <- res$io$source
  if (!is.null(src) && file.exists(src)) {
    files <- if (dir.exists(src)) list.files(src, full.names = TRUE) else src
    w(data.frame(file = basename(files), sha256 = vapply(files, function(f) digest::digest(f, algo = "sha256",
                                                                                             file = TRUE),
                                                           character(1)), stringsAsFactors = FALSE),
      file.path(inp, "inputs_sha256.csv"))
  }
  saveRDS(res, file.path(dir, "results.rds"))
  writeLines(c(sprintf("%s: %s", names(res$meta), vapply(res$meta, function(v) paste(format(v), collapse = " "),
                                                          character(1))),
               "", utils::capture.output(utils::sessionInfo())),
             file.path(dir, "session.txt"), useBytes = TRUE)
  writeLines(enc2utf8(report_markdown(res, excel)), file.path(dir, "README.md"), useBytes = TRUE)
  invisible(dir)
}

# Folder of a run: "P04_GC-LAB-GD"; ECO is written only when it is not last.
run_folder <- function(r) {
  lv <- r$order
  if (identical(lv[length(lv)], "ECO")) lv <- lv[-length(lv)]
  paste0(r$label, "_", paste(lv, collapse = "-"))
}

# One row per row of G at level `lev`: goal, g, Gx, deviations, and the
# output x of the level in the economic rows.
level_table <- function(r, lev) {
  L <- r$levels[[lev]]
  k <- length(r$accounts)
  n <- length(L$x)
  data.frame(row = c(r$accounts, r$baseline$codes), block = c(rep("account", k), rep("ECO", n)),
             g = r$g, Gx = L$gx, d_minus = L$d_minus, d_plus = L$d_plus,
             x = c(rep(NA_real_, k), L$x), stringsAsFactors = FALSE)
}

# The database as shown in the report: its path relative to the folder of
# model.yml when it is inside it, otherwise only its name (no local paths).
source_label <- function(source, model_file = NULL) {
  src <- normalizePath(source, winslash = "/", mustWork = FALSE)
  if (!is.null(model_file)) {
    base <- normalizePath(dirname(model_file), winslash = "/", mustWork = FALSE)
    if (startsWith(src, paste0(base, "/"))) return(substring(src, nchar(base) + 2))
  }
  basename(src)
}

# Numbers of the report. The decimals follow the scale of the quantity: d
# decimals when the scale is 1 or more, otherwise enough for three significant
# digits of the scale (base 0.03 and goal 0.0315 show as 0.0300 and 0.0315,
# not 0.03 and 0.03), up to 6. The scale of an account is its base, so a
# rounding residue of a large account (a change of 1e-6 on a base of 1e6)
# still shows as 0.00. Without a scale, each value is its own scale, and
# values below 5e-7 show as 0. NA shows as an empty cell.
report_num <- function(v, d = 2, scale = NULL) {
  if (is.null(scale)) {
    v[!is.na(v) & abs(v) < 0.5e-6] <- 0
    scale <- v
  }
  scale <- rep_len(abs(scale), length(v))
  dec <- ifelse(is.na(scale) | scale == 0 | scale >= 1, d, pmin(6, pmax(d, 2 - floor(log10(scale)))))
  v[!is.na(v) & abs(v) < 0.5 * 10^-dec] <- 0
  vapply(seq_along(v), function(i) {
    if (is.na(v[i])) "" else formatC(v[i], format = "f", digits = dec[i], big.mark = ",")
  }, character(1))
}

# Percentages, with d decimals.
report_pct <- function(v, d = 2) ifelse(is.na(v), "", paste0(report_num(100 * v, d, scale = 1), "%"))

# Markdown report of the results.
report_markdown <- function(res, excel = TRUE) {
  m <- res$model
  s <- res$summary
  acc <- names(m$accounts)
  num <- report_num
  pct <- report_pct
  table_md <- function(df) {
    c(paste0("| ", paste(names(df), collapse = " | "), " |"),
      paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
      apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
  }
  # Status of a run from its GLPK codes per level; from the level without
  # solution on, the levels are blank, not "not optimal".
  status_txt <- function(r, none = NA) {
    bad <- which(r != "0")
    if (!is.na(none)) bad <- bad[bad < none]
    out <- c(if (length(bad)) paste0("not optimal at level ", paste(bad, collapse = ", ")),
             if (!is.na(none)) paste0("no solution from level ", none))
    if (length(out)) paste(out, collapse = "; ") else "optimal"
  }
  units <- vapply(m$accounts, `[[`, character(1), "unit")
  base <- satellite_base(res$io, acc)
  x_scale <- sum(abs(res$io$x))
  relaxed <- s$runs[s$runs$lock_tolerance > 0, ]
  out <- c(
    paste0("# lexio results: ", m$name), "",
    sprintf("- Produced on %s with lexio %s, %s, GLPK %s.", res$meta$date, res$meta$lexio, res$meta$R, res$meta$GLPK),
    sprintf("- Database: %d sectors, declared as %s + %s%s.", res$io$n, res$io$declared$structure,
            res$io$declared$accounts,
            if (!is.null(res$io$source)) paste0(" (`", source_label(res$io$source, m$source), "`)") else ""),
    sprintf("- Corridor: %s.", paste(unique(s$runs$corridor), collapse = "; ")),
    sprintf("- Economic block ECO: %s; %s.",
            if (identical(m$economy$position, "free")) "position free, as declared by the operator"
            else "fixed at the last level",
            if (identical(m$economy$deviation, "relative")) {
              "relative deviations (each sector's deviation divided by |g_h|; its Z is a sum of proportions)"
            } else {
              "absolute deviations (currency units)"
            }),
    sprintf("- Lock of the levels already solved: %s.", describe_lock(m$lock_tolerance)),
    sprintf("- %d scenario(s), %d run(s); %s.", length(unique(s$runs$scenario)), nrow(s$runs),
            if (all(s$runs$optimal)) "every level of every run is optimal"
            else paste(sum(!s$runs$optimal), "run(s) with a non-optimal level (see Warnings)")),
    if (nrow(relaxed)) {
      sprintf("- **%d run(s) were optimal only with the relaxed lock** (see Warnings); the others use the exact lock.",
              nrow(relaxed))
    },
    "", "## Model", "",
    paste("Direction `>=` penalizes the shortfall (d-), `<=` the excess (d+), `=` both.",
          "ECO is the economic block: one goal per sector, the final demand by default."),
    ""
  )
  mod <- data.frame(Account = acc, Unit = units, Direction = vapply(m$accounts, `[[`, character(1), "direction"),
                    Weight = vapply(m$accounts, `[[`, numeric(1), "weight"), "Base (D x)" = num(base),
                    check.names = FALSE, stringsAsFactors = FALSE)
  for (sc in m$scenarios) mod[[paste("Goal:", sc$name)]] <- vapply(acc, function(a) describe_target(sc$targets[[a]]),
                                                                  character(1))
  out <- c(out, table_md(mod), "")
  for (sc in unique(s$runs$scenario)) {
    d <- s$runs[s$runs$scenario == sc, ]
    zc <- grep("^Z[0-9]+$", names(d), value = TRUE)
    tb <- data.frame(Ordering = d$label, Priorities = d$priorities,
                     Status = mapply(status_txt, strsplit(d$status, ""), d$infeasible_level, USE.NAMES = FALSE),
                     stringsAsFactors = FALSE)
    for (z in zc) tb[[z]] <- num(d[[z]])
    tb[["delta x"]] <- num(d$delta_x, scale = x_scale)
    tb[["delta x (%)"]] <- pct(d$delta_x_pct, 3)
    for (a in acc) tb[[paste("delta", a)]] <- num(d[[paste0("delta_", a)]], scale = base[[a]])
    if (nrow(relaxed)) tb$Lock <- ifelse(d$lock_tolerance > 0, paste("relaxed", format(d$lock_tolerance)), "exact")
    tb$State <- d$state
    gl <- s$goals[s$goals$scenario == sc & !negligible_change(s$goals$intended, s$goals$base), ]
    out <- c(out, paste0("## Scenario: ", sc), "", "### Orderings", "",
             "Z<l> is the optimum of priority level l (the weighted deviations of its goals).", "",
             table_md(tb), "")
    if (nrow(gl)) {
      gt <- data.frame(Ordering = gl$label, Account = gl$account, Base = num(gl$base, scale = gl$base),
                       Goal = num(gl$g, scale = gl$base), Achieved = num(gl$Gx, scale = gl$base),
                       "Realized change" = pct(gl$realized, 1), check.names = FALSE,
                       stringsAsFactors = FALSE)
      out <- c(out, "### Accounts whose goal differs from the base", "",
               "Realized change = (achieved - base) / (goal - base).", "", table_md(gt), "")
    }
  }
  st <- s$states
  stt <- data.frame(State = st$state, Runs = st$members, "delta x" = num(st$delta_x, scale = x_scale),
                    "delta x (%)" = pct(st$delta_x_pct, 3), check.names = FALSE, stringsAsFactors = FALSE)
  for (a in acc) stt[[paste("delta", a)]] <- num(st[[paste0("delta_", a)]], scale = base[[a]])
  out <- c(out, "## Distinct states", "",
           "Runs whose outputs x_star differ by at most 1e-6 (in any sector) form one state.", "",
           table_md(stt), "")
  bad <- s$runs[!s$runs$optimal, ]
  warn <- res$io$validation[res$io$validation$level == "warning", ]
  out <- c(out, "## Warnings", "")
  if (!nrow(bad) && !nrow(warn) && !nrow(relaxed)) out <- c(out, "None.", "")
  if (nrow(relaxed)) {
    out <- c(out, sprintf("- %s %s (%s): optimal with the relaxed lock %s (with the exact lock, GLPK did not certify some level).",
                          relaxed$scenario, relaxed$label, relaxed$priorities, format(relaxed$lock_tolerance)),
             "",
             paste("**Precision cost.** In these runs each level already solved may stay above its optimum by up to",
                   "t * max(1, |Z|), and the following levels may use that slack: in the tests, later levels moved",
                   "by up to about 2e-4 (relative) from an exact solution. Runs that are optimal with the exact lock",
                   "are not affected. Use `lock_tolerance: exact` to keep only the exact lock (see the vignette *Declaring data and models*)."),
             "")
  }
  if (nrow(bad)) {
    lv <- s$levels
    what <- vapply(seq_len(nrow(bad)), function(i) {
      b <- bad[i, ]
      if (!is.na(b$infeasible_level)) {
        v <- lv$violation[lv$scenario == b$scenario & lv$label == b$label & lv$level == b$infeasible_level]
        return(sprintf("level %d has no solution (its constraints are violated by %.3g); it and the following levels are blank",
                       b$infeasible_level, v))
      }
      v <- lv$violation[lv$scenario == b$scenario & lv$label == b$label & !lv$optimal]
      sprintf("%s; the solution meets every constraint (largest violation %.2g): a numerical false infeasibility",
              status_txt(strsplit(b$status, "")[[1]]), max(v))
    }, character(1))
    out <- c(out, sprintf("- %s %s (%s): %s.", bad$scenario, bad$label, bad$priorities, what),
             "", paste("A non-optimal level means that GLPK did not certify that solution. lexio then checks it against",
                       "the constraints of the level. If they hold, the flag is a numerical false infeasibility (see",
                       "the vignette *Declaring data and models*): the numbers are kept, but their optimality is not",
                       "certified. If they do not hold, the level has no solution, and it and the following levels",
                       "are left blank in every table."), "")
  }
  if (nrow(bad) && identical(m$lock_tolerance, 0)) {
    out <- c(out, paste("To try to solve them, run again with `lock_tolerance: auto` in model.yml (relaxed lock only",
                        "in the runs that fail; see the vignette *Declaring data and models*)."), "")
  }
  if (nrow(warn)) out <- c(out, paste0("- Database: ", warn$check, ": ", warn$detail, "."), "")
  c(out, "## Files", "",
    if (excel) {
      paste("- `results.xlsx`: every table in one workbook, with the final results of all orderings side by side",
            "and one sheet per run (see the sheet `about`).")
    },
    "- `orderings.csv`, `account_goals.csv`, `states.csv`: the tables above, complete.",
    "- `levels.csv` and `level_results.csv`: each priority level of each run.",
    paste("- `runs/<scenario>/<ordering>/`: `all_levels.csv` (every row of G, all levels side by side),",
          "`level_<l>.csv` and `x_star.csv`."),
    paste("- `inputs/`: the model used and the SHA-256 of the database; `results.rds`: the full object;",
          "`session.txt`: versions."))
}
