#' Run one ordering of one scenario
#'
#' Builds the goals of the scenario, the problem `Gx + d- - d+ = g` with the
#' corridor declared with the data (if any, and if the scenario uses it), and
#' solves the lexicographic goal program in the requested priority ordering.
#' To run every ordering of every scenario at once, use [run_model()].
#'
#' When GLPK does not end a level as optimal, the solution it returns is
#' checked against the constraints of the level (`violation`: the largest
#' violation, each row relative to `max(1, |rhs|)`). If the constraints hold
#' (violation up to 1e-4), the flag of GLPK is a numerical false
#' infeasibility: the numbers are kept and the run is flagged as not optimal.
#' If they do not hold, the level has no solution: that level and the
#' following ones are left blank (`NA`), and `infeasible_level` says where it
#' starts.
#'
#' @param io Object of class `lexio_io` ([declare_io()], [read_io()]).
#' @param model Object of class `lexio_model` ([define_model()],
#'   [read_model()]).
#' @param scenario Name or number of the scenario.
#' @param ordering Number or label of an ordering of the model, or an ad hoc
#'   ordering (a character vector with one goal per level, or a list of
#'   levels; see `priorities` in [define_model()]).
#' @param strict If `TRUE` (default), stops with an error when a level does
#'   not end optimal (`GLP_OPT`) or a check fails (relative tolerance 1e-8).
#'   With `FALSE`, returns the run and records the problem in `ok`, `status`
#'   and `checks`.
#' @param keep_lp If `TRUE`, keeps the ROI `OP` object of each level.
#' @param lock_tolerance Lock of the levels already solved (default: the one
#'   of the model; see [define_model()]). `0` or `"exact"` is the exact lock
#'   `d_l == Z_l`.
#'
#' @return Object of class `gp_run`: scenario, ordering (`ordering` = its
#'   number, `label`, `order` = the names of the levels); `g`; the corridor
#'   used (`floor`, `ceiling`); the levels (`levels`: GLPK status, `objval`,
#'   `x`, `d_plus`, `d_minus`, `gx`, `violation`); `Z`; the solution of the
#'   last level (`x_star`, `d_minus`, `d_plus`, `gx`); the checks (`checks`);
#'   `status`, `optimal`, `ok`; `violation` (one value per level) and
#'   `infeasible_level` (the first level without solution, `NA` if none); the
#'   lock tolerance used (`lock_tolerance`, 0 = exact)
#'   and the status with the exact lock (`status_exact`); the base
#'   (`baseline`) and metadata (`meta`).
#' @examples
#' io <- example_io()
#' m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
#' run_experiment(io, m, scenario = "E_shock", ordering = 1)
#' @export
run_experiment <- function(io, model, scenario = 1, ordering = 1, strict = TRUE, keep_lp = FALSE,
                           lock_tolerance = NULL) {
  if (!inherits(io, "lexio_io")) stop("`io` must be a lexio_io object (declare_io, read_io)", call. = FALSE)
  if (!inherits(model, "lexio_model")) stop("`model` must be a lexio_model object (define_model, read_model)",
                                            call. = FALSE)
  sc <- get_scenario(model, scenario)
  acc <- names(model$accounts)
  D <- account_rows(io, acc)
  g <- build_goals(io, model, sc$name)
  floor <- if (sc$corridor_use && !is.null(io$floor)) io$floor * sc$corridor_multiplier else NULL
  ceiling <- if (sc$corridor_use && !is.null(io$ceiling)) io$ceiling * sc$corridor_multiplier else NULL
  pr <- priority_levels(model, sc$name, ordering, io$n, g = g)
  lp <- build_lp(list(D = D, B = io$B), g, floor, ceiling)
  level_status <- function(s) vapply(s$levels, function(l) as.integer(l$status_code), integer(1))
  # First the exact lock; the next tolerances
  # (lock_tolerance) are tried only if some level does not end optimal.
  tols <- lock_tolerances(if (is.null(lock_tolerance)) model$lock_tolerance else lock_tolerance)
  for (tol in tols) {
    sol <- solve_lexicographic(lp, pr$levels, keep_lp = keep_lp, lock_tolerance = tol)
    status <- level_status(sol)
    if (tol == 0) {
      sol_exact <- sol
      status_exact <- status
    }
    if (all(status == 0L)) break
  }
  # no tolerance solved it: keep the run with the exact lock
  if (any(status != 0L)) {
    sol <- sol_exact
    status <- status_exact
  }
  # a level that GLPK did not solve and whose solution breaks its constraints
  # has no solution: it and the following levels are left blank
  violation <- vapply(sol$levels, `[[`, numeric(1), "violation")
  no_solution <- which(status != 0L & violation > infeasible_violation)
  infeasible_level <- if (length(no_solution)) no_solution[1] else NA_integer_
  if (!is.na(infeasible_level)) sol <- blank_levels(sol, infeasible_level)
  last <- sol$levels[[length(sol$levels)]]
  optimal <- all(status == 0L)
  mode <- if (!sc$corridor_use) "not used (free)" else io$corridor_mode
  run <- structure(list(
    model = model$name, scenario = sc$name, ordering = pr$index, label = pr$label, order = pr$level_names,
    levels_goals = lapply(pr$levels, `[[`, "goals"),
    accounts = acc, units = vapply(model$accounts, `[[`, character(1), "unit"),
    targets = sc$targets, directions = sc$directions,
    corridor = list(mode = mode, multiplier = sc$corridor_multiplier), floor = floor, ceiling = ceiling,
    economy = list(deviation = if (is.null(model$economy$deviation)) "absolute" else model$economy$deviation,
                   position = if (is.null(model$economy$position)) "last" else model$economy$position),
    g = g,
    levels = sol$levels, Z = sol$Z,
    x_star = last$x, d_minus = last$d_minus, d_plus = last$d_plus, gx = last$gx,
    checks = sol$checks,
    status = status,
    violation = violation,
    infeasible_level = infeasible_level,
    lock_tolerance = sol$lock_tolerance,
    status_exact = status_exact,
    status_symbol = vapply(sol$levels, function(l) as.character(l$status_symbol), character(1)),
    optimal = optimal,
    ok = optimal && all(sol$checks$ok_rel),
    baseline = list(x = io$x, D = D, base = satellite_base(io, acc), codes = io$sectors$code,
                    names = io$sectors$name),
    meta = run_metadata()
  ), class = "gp_run")
  if (strict && !run$ok) {
    bad <- which(status != 0L)
    msg <- c(
      if (length(bad)) paste0("level ", bad, " (", run$order[bad], ") ended with status ", run$status_symbol[bad]),
      if (!is.na(infeasible_level)) {
        sprintf("level %d has no solution (its constraints are violated by %.3g)", infeasible_level,
                violation[infeasible_level])
      },
      if (!all(sol$checks$ok_rel)) "an objective or preservation check failed (see run$checks)"
    )
    stop("run not optimal: ", paste(msg, collapse = "; "), ". Use strict = FALSE to inspect the run.", call. = FALSE)
  }
  run
}

#' @export
print.gp_run <- function(x, ...) {
  cat("<gp_run>", x$model, "| scenario", x$scenario, "|", x$label, ":", paste(x$order, collapse = " > "), "\n")
  for (k in seq_along(x$levels)) {
    cat(sprintf("  level %d %-12s %-10s Z = %.6g\n", k, x$order[k], x$status_symbol[k], x$Z[k]))
  }
  if (!is.null(x$lock_tolerance) && x$lock_tolerance > 0) {
    cat("  WARNING: solved with the relaxed lock", format(x$lock_tolerance), "(status with the exact lock:",
        paste(x$status_exact, collapse = ""), "); see vignette(\"model-specification\", package = \"lexio\")\n")
  }
  if (!is.null(x$infeasible_level) && !is.na(x$infeasible_level)) {
    cat(sprintf("  WARNING: level %d has no solution (its constraints are violated by %.3g); levels %d to %d are blank\n",
                x$infeasible_level, x$violation[x$infeasible_level], x$infeasible_level, length(x$levels)))
  }
  k <- length(x$accounts)
  if (k && !is.null(x$baseline)) {
    cat("  accounts at the last level:\n")
    # deviations below 1e-6 in absolute value are solver noise: shown as 0
    dev <- function(v) format(signif(if (!is.na(v) && abs(v) < 1e-6) 0 else v, 6))
    for (a in seq_len(k)) {
      cat(sprintf("    %-8s %-2s base %-14s goal %-14s achieved %-14s d- %-12s d+ %s\n", x$accounts[a],
                  x$directions[[x$accounts[a]]], format(signif(x$baseline$base[[a]], 10)), format(signif(x$g[a], 10)),
                  format(signif(x$gx[a], 10)), dev(x$d_minus[a]), dev(x$d_plus[a])))
    }
    eco <- k + seq_along(x$x_star)
    dx <- sum(x$x_star) - sum(x$baseline$x)
    cat(sprintf("  ECO: shortfall sum(d-) = %s, excess sum(d+) = %s | delta x = %s (%.4f%%)\n",
                format(signif(sum(x$d_minus[eco]), 6)), format(signif(sum(x$d_plus[eco]), 6)),
                format(signif(dx, 8)), 100 * dx / sum(x$baseline$x)))
  }
  cat("  corridor:", x$corridor$mode, "| ok:", x$ok, "\n")
  invisible(x)
}

# Largest violation (relative) of its constraints that a level not certified by
# GLPK may have and still count as solved. A level without solution leaves
# violations of order 1e-2 or more; the false infeasibilities of GLPK, below
# 1e-6.
infeasible_violation <- 1e-4

# The levels from `from` on, left blank: they have no solution.
blank_levels <- function(sol, from) {
  for (l in from:length(sol$levels)) {
    lev <- sol$levels[[l]]
    for (v in c("x", "d_plus", "d_minus", "gx")) lev[[v]] <- rep(NA_real_, length(lev[[v]]))
    lev$objval <- NA_real_
    sol$levels[[l]] <- lev
    sol$Z[l] <- NA_real_
  }
  sol
}

run_metadata <- function() {
  ver <- function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  list(lexio = ver("lexio"), R = R.version.string, ROI = ver("ROI"),
       ROI.plugin.glpk = ver("ROI.plugin.glpk"), Rglpk = ver("Rglpk"),
       GLPK = glpk_version(), date = format(Sys.time(), "%Y-%m-%d %H:%M:%S %z"))
}

glpk_version <- function() {
  tryCatch({
    sym <- get("Rglpk_get_engine_version", envir = asNamespace("Rglpk"))
    .C(sym, v = character(1))$v
  }, error = function(e) NA_character_)
}
