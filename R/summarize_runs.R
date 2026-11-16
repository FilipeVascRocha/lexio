#' Summarize the runs
#'
#' Summarizes the solutions of the last level of each run (scenario x
#' ordering), for any number of satellite accounts and priority levels. No
#' plots are produced.
#'
#' For each run, with `x0` the base output and `b = D x0` the base of each
#' account:
#' * `delta_x = sum(x_star) - sum(x0)` and `delta_x_pct = delta_x / sum(x0)`;
#' * for each account: achieved `Gx`, `delta = Gx - b`, intended change
#'   `g - b` and realized share `(Gx - b) / (g - b)`; the share is `NA` when
#'   the intended change is negligible (`|g - b| <= 1e-9 max(1, |b|)`, a goal
#'   equal to the base up to rounding);
#' * distinct states: single-linkage grouping of the solutions `x_star` of
#'   all runs; two solutions are in the same state when
#'   `max |x_star_a - x_star_b| <= tol` (1e-6 by default). A run with a level
#'   that has no solution has no state (`NA`).
#'
#' @param runs A `lexio_results` object ([run_model()]) or a list of `gp_run`
#'   objects ([run_experiment()]) of the same model.
#' @param tol Tolerance (absolute, max norm on `x_star`) to group states.
#' @param goal_tol Relative tolerance to call an account "at goal".
#'
#' @return List with `runs` (one row per run; `infeasible_level` is the first
#'   level without solution, `NA` if none), `levels` (one row per run x
#'   priority level: its goals, optimum `Z`, GLPK status and the violation of
#'   its constraints by the solution, see [run_experiment()]), `goals` (run x
#'   account) and `states` (one row per distinct state).
#' @export
summarize_runs <- function(runs, tol = 1e-6, goal_tol = 1e-9) {
  if (inherits(runs, "lexio_results")) runs <- runs$runs
  if (!length(runs) || !all(vapply(runs, inherits, logical(1), "gp_run"))) {
    stop("runs must be a lexio_results object or a list of gp_run objects", call. = FALSE)
  }
  acc <- runs[[1]]$accounts
  n_levels <- max(vapply(runs, function(r) length(r$Z), integer(1)))
  tab <- do.call(rbind, lapply(runs, function(r) {
    row <- data.frame(scenario = r$scenario, ordering = r$ordering, label = r$label,
                      priorities = paste(r$order, collapse = " > "),
                      status = paste(r$status, collapse = ""),
                      status_glpk = paste(r$status_symbol, collapse = " "), optimal = r$optimal, ok = r$ok,
                      infeasible_level = if (is.null(r$infeasible_level)) NA_integer_ else r$infeasible_level,
                      lock_tolerance = if (is.null(r$lock_tolerance)) 0 else r$lock_tolerance,
                      corridor = r$corridor$mode, stringsAsFactors = FALSE)
    for (j in seq_len(n_levels)) row[[paste0("Z", j)]] <- if (j <= length(r$Z)) r$Z[j] else NA_real_
    row$delta_x <- sum(r$x_star) - sum(r$baseline$x)
    row$delta_x_pct <- row$delta_x / sum(r$baseline$x)
    for (a in seq_along(r$accounts)) row[[paste0("delta_", r$accounts[a])]] <- r$gx[a] - r$baseline$base[[a]]
    row
  }))
  goals <- do.call(rbind, lapply(runs, function(r) {
    do.call(rbind, lapply(seq_along(r$accounts), function(a) {
      b <- r$baseline$base[[a]]
      intended <- r$g[a] - b
      term <- list(rows = a, type = direction_type(r$directions[[r$accounts[a]]]), weight = 1)
      data.frame(
        scenario = r$scenario, ordering = r$ordering, label = r$label, account = r$accounts[a],
        unit = unname(r$units[a]), direction = r$directions[[r$accounts[a]]],
        base = b, g = r$g[a], Gx = r$gx[a], delta = r$gx[a] - b, intended = intended,
        realized = if (negligible_change(intended, b)) NA_real_ else (r$gx[a] - b) / intended,
        deviation = penalized_deviation(r$d_plus, r$d_minus, list(terms = list(term))),
        at_goal = !is.na(r$gx[a]) && abs(r$gx[a] - r$g[a]) <= goal_tol * abs(r$g[a]),
        stringsAsFactors = FALSE
      )
    }))
  }))
  levels <- do.call(rbind, lapply(runs, function(r) {
    data.frame(scenario = r$scenario, ordering = r$ordering, label = r$label, level = seq_along(r$levels),
               goals = r$order, Z = r$Z, status = as.integer(r$status), status_glpk = r$status_symbol,
               optimal = r$status == 0L,
               violation = if (is.null(r$violation)) NA_real_ else r$violation,
               lock_tolerance = if (is.null(r$lock_tolerance)) 0 else r$lock_tolerance,
               stringsAsFactors = FALSE)
  }))
  X <- do.call(cbind, lapply(runs, `[[`, "x_star"))
  solved <- colSums(is.na(X)) == 0
  tab$state <- NA_integer_
  if (any(solved)) tab$state[solved] <- cluster_states(X[, solved, drop = FALSE], tol)
  key <- function(d) paste(d$scenario, d$label, sep = "\r")
  goals$state <- tab$state[match(key(goals), key(tab))]
  levels$state <- tab$state[match(key(levels), key(tab))]
  states <- do.call(rbind, lapply(split(seq_len(nrow(tab)), tab$state), function(i) {
    first <- i[1]
    members <- tapply(tab$label[i], factor(tab$scenario[i], levels = unique(tab$scenario[i])),
                      function(p) paste(p, collapse = ","))
    out <- data.frame(state = tab$state[first], n_runs = length(i),
                      members = paste(paste0(names(members), ": ", members), collapse = " | "),
                      delta_x = tab$delta_x[first], delta_x_pct = tab$delta_x_pct[first],
                      stringsAsFactors = FALSE)
    for (a in acc) out[[paste0("delta_", a)]] <- tab[[paste0("delta_", a)]][first]
    out
  }))
  if (is.null(states)) {
    # no run has a solution
    states <- data.frame(state = integer(0), n_runs = integer(0), members = character(0), delta_x = numeric(0),
                         delta_x_pct = numeric(0), stringsAsFactors = FALSE)
    for (a in acc) states[[paste0("delta_", a)]] <- numeric(0)
  }
  states <- states[order(states$state), ]
  rownames(tab) <- rownames(levels) <- rownames(goals) <- rownames(states) <- NULL
  list(runs = tab, levels = levels, goals = goals, states = states)
}

# TRUE when an intended change g - b is only rounding: a goal equal to the
# base, computed by another route (for instance a level goal written with 15
# digits next to the base D x).
negligible_change <- function(intended, base) {
  abs(intended) <= 1e-9 * pmax(1, abs(base))
}

# Groups the columns of X (one solution per column) by single linkage: two
# columns are in the same state if max |X[, a] - X[, b]| <= tol. States are
# numbered in order of first appearance.
cluster_states <- function(X, tol) {
  n <- ncol(X)
  parent <- seq_len(n)
  find <- function(i) {
    while (parent[i] != i) i <- parent[i]
    i
  }
  for (a in seq_len(n - 1)) {
    for (b in (a + 1):n) {
      if (max(abs(X[, a] - X[, b])) <= tol) {
        ra <- find(a)
        rb <- find(b)
        if (ra != rb) parent[max(ra, rb)] <- min(ra, rb)
      }
    }
  }
  roots <- vapply(seq_len(n), find, integer(1))
  match(roots, unique(roots))
}
