#' Solve the lexicographic program
#'
#' Solves the preemptive goal program level by level (Rocha, 2026, section 4.4.1):
#' level `l` minimizes the weighted sum of the penalized deviations of its
#' goals, with the levels already solved locked at their optima
#' (`d_j == Z_j`, `j < l`). Works for any number of levels and any number of
#' goals per level.
#'
#' Each LP is solved with `ROI::ROI_solve(op, solver = "glpk")` and the
#' default solver options. After each run two checks are applied: the
#' optimum of each level equals
#' the sum of its penalized deviations, and every earlier level stays at its
#' optimum.
#'
#' @param lp Object of class `lexio_lp` from [build_lp()].
#' @param priorities List of levels, in priority order. Each level is a list
#'   with `name` and either `terms` (a list of goals, each with `rows` of `G`,
#'   `type` (`"minus"`, `"plus"` or `"both"`, see [direction_type()]) and
#'   `weight`) or, for a level with a single goal of weight 1, `rows` and
#'   `type`.
#' @param keep_lp If `TRUE`, keeps the ROI `OP` object of each level.
#' @param lock_tolerance `0` (default): exact lock `d_l == Z_l`. `t > 0`: relaxed lock `d_l <= Z_l + t * max(1, |Z_l|)`
#'   (see `lock_tolerance` in [define_model()]).
#'
#' @return List with `levels` (one element per level: GLPK status, `objval`,
#'   `x`, `d_plus`, `d_minus`, `gx = G x` and `violation`, the largest
#'   violation of the constraints of the level by that solution, see
#'   [run_experiment()]), `Z` (the optima of the levels), `checks` (data
#'   frame) and `lock_tolerance`.
#' @export
solve_lexicographic <- function(lp, priorities, keep_lp = FALSE, lock_tolerance = 0) {
  ensure_glpk()
  A <- lp$A
  dir <- lp$dir
  rhs <- lp$rhs
  n_levels <- length(priorities)
  levels <- vector("list", n_levels)
  Z <- rep(NA_real_, n_levels)
  for (k in seq_len(n_levels)) {
    pr <- priorities[[k]]
    di <- deviation_index(lp, pr)
    obj_idx <- di$idx
    cvec <- rep(0, lp$n_var)
    if (all(di$weight == 1)) cvec[obj_idx] <- 1 else cvec[obj_idx] <- di$weight
    op <- ROI::OP(objective = ROI::L_objective(cvec),
                  constraints = ROI::L_constraint(L = A, dir = dir, rhs = rhs),
                  bounds = lp$bounds)
    sol <- ROI::ROI_solve(op, solver = "glpk")
    s <- sol$solution
    lev <- list(
      name = pr$name, rows = pr$rows, type = pr$type, terms = level_terms(pr), obj_idx = obj_idx,
      status_code = sol$status$code,
      status_symbol = sol$status$msg$symbol,
      status_message = sol$status$msg$message,
      objval = sol$objval,
      x = s[lp$idx_x], d_plus = s[lp$idx_d_plus], d_minus = s[lp$idx_d_min],
      violation = constraint_violation(A, dir, rhs, s)
    )
    lev$gx <- as.numeric(lp$G %*% lev$x)
    if (keep_lp) lev$op <- op
    levels[[k]] <- lev
    Z[k] <- sol$objval
    if (k < n_levels) {
      # lock of level k: its weighted deviations == Z_k
      lock <- cvec
      A <- rbind(A, lock)
      if (lock_tolerance == 0) {
        dir <- c(dir, "==")
        rhs <- c(rhs, Z[k])
      } else {
        # relaxed lock (optional): weighted deviations <= Z_k + t * max(1, |Z_k|)
        dir <- c(dir, "<=")
        rhs <- c(rhs, Z[k] + lock_tolerance * max(1, abs(Z[k])))
      }
    }
  }
  list(levels = levels, Z = Z, checks = level_checks(levels, Z, lp$g, lock_tolerance = lock_tolerance),
       lock_tolerance = lock_tolerance)
}

# Checks of a solved run (the objective of each level and the preservation of
# the earlier levels), with an absolute tolerance (1e-6, column `ok`) and a relative one
# (1e-8 * max(|reference|, scale of the goal), column `ok_rel`). With a
# relaxed lock, preservation also admits the slack of the lock.
level_checks <- function(levels, Z, g, tol_abs = 1e-6, tol_rel = 1e-8, lock_tolerance = 0) {
  rows <- list()
  # scale of a level: sum of |g| of its rows, weighted as its objective
  scale_of <- function(lev) {
    terms <- lev$terms
    if (all(vapply(terms, function(t) all(t$weight == 1), logical(1)))) {
      return(sum(abs(g[unlist(lapply(terms, `[[`, "rows"))])))
    }
    sum(vapply(terms, function(t) sum(t$weight * abs(g[t$rows])), numeric(1)))
  }
  add <- function(level, against, value, reference, diff, scale) {
    slack <- if (is.na(against)) 0 else lock_tolerance * max(1, abs(reference))
    rows[[length(rows) + 1]] <<- data.frame(
      level = level, name = levels[[level]]$name, check = if (is.na(against)) "objective" else "preservation",
      against = against, value = value, reference = reference, diff = diff, scale = scale,
      ok = abs(diff) <= tol_abs + slack, ok_rel = abs(diff) <= tol_rel * max(abs(reference), scale) + slack,
      stringsAsFactors = FALSE
    )
  }
  for (k in seq_along(levels)) {
    lev <- levels[[k]]
    total <- penalized_deviation(lev$d_plus, lev$d_minus, lev)
    add(k, NA_integer_, total, lev$objval, lev$objval - total, scale_of(lev))
    for (j in seq_len(k - 1)) {
      prev <- levels[[j]]
      total_j <- penalized_deviation(lev$d_plus, lev$d_minus, prev)
      add(k, j, total_j, Z[j], total_j - Z[j], scale_of(prev))
    }
  }
  do.call(rbind, rows)
}

# Largest violation of the constraints of a level (goals, corridor, locks of
# the earlier levels, x and d >= 0) by the solution returned by GLPK: each row
# relative to max(1, |rhs|), a negative variable relative to the largest |rhs|.
# It is tiny when the level is solved, and also when the "not optimal" of GLPK
# is a numerical false infeasibility; a level without solution leaves a large
# violation.
constraint_violation <- function(A, dir, rhs, s) {
  if (anyNA(s)) return(Inf)
  r <- as.numeric(A %*% s) - rhs
  v <- ifelse(dir == "==", abs(r), ifelse(dir == "<=", pmax(r, 0), pmax(-r, 0)))
  max(v / pmax(1, abs(rhs)), max(pmax(-s, 0)) / max(1, abs(rhs)))
}

ensure_glpk <- function() {
  if (!requireNamespace("ROI.plugin.glpk", quietly = TRUE)) {
    stop("the package ROI.plugin.glpk (GLPK) is needed to solve the model", call. = FALSE)
  }
  invisible(TRUE)
}
