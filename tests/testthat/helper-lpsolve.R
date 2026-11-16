# Independent reference: the same lexicographic Goal Programming, built from
# scratch (without the LP functions of the package) and solved with another
# solver (lpSolve). Returns the optimum Z of each level, or NULL if lpSolve
# does not find an optimal solution at some level. Used in test-cross-solver.R
# and test-miller-blair.R. The model of the package stays on GLPK.
#
# `ordering`: a list of levels, each a character vector of goals (account
# names or "ECO"); a character vector of account names means one account per
# level, with ECO appended last. The weights come from the model.
# `slack = 0`: exact locks (`== Z`). `slack > 0`: locks
# `<= Z + slack * max(1, |Z|)`, the same form as `lock_tolerance`.
lexico_lpsolve <- function(io, model, ordering, scenario = 1, slack = 0) {
  acc <- names(model$accounts)
  k <- length(acc)
  n <- io$n
  m <- k + n
  D <- io$D[match(acc, io$accounts), , drop = FALSE]
  G <- rbind(D, io$B)
  g <- build_goals(io, model, scenario)
  sc <- model$scenarios[[scenario]]
  use <- isTRUE(sc$corridor_use)
  lo <- if (use && !is.null(io$floor)) io$floor * sc$corridor_multiplier
  hi <- if (use && !is.null(io$ceiling)) io$ceiling * sc$corridor_multiplier
  nv <- n + 2 * m
  # G x - d+ + d- = g
  eq <- cbind(G, -diag(m), diag(m))
  cap <- NULL
  cap_rhs <- NULL
  for (r in (k + 1):m) {
    h <- r - k
    if (!is.null(lo) && !is.na(lo[h])) {
      row <- numeric(nv)
      row[n + m + r] <- 1
      cap <- rbind(cap, row)
      cap_rhs <- c(cap_rhs, lo[h] * abs(g[r]))
    }
    if (!is.null(hi) && !is.na(hi[h])) {
      row <- numeric(nv)
      row[n + r] <- 1
      cap <- rbind(cap, row)
      cap_rhs <- c(cap_rhs, hi[h] * abs(g[r]))
    }
  }
  pen <- function(rows, d, w = 1) {
    v <- numeric(nv)
    if (d %in% c(">=", "=")) v[n + m + rows] <- w
    if (d %in% c("<=", "=")) v[n + rows] <- w
    v
  }
  if (is.character(ordering)) ordering <- c(as.list(ordering), "ECO")
  if (!"ECO" %in% unlist(ordering)) ordering <- c(ordering, "ECO")
  dirs <- sc$directions
  levels <- lapply(ordering, function(goals) {
    Reduce(`+`, lapply(goals, function(a) {
      if (a == "ECO") return(pen((k + 1):m, dirs[["economy"]]))
      w <- model$accounts[[a]]$weight
      pen(match(a, acc), dirs[[a]], if (is.null(w)) 1 else w)
    }))
  })
  mat <- rbind(eq, cap)
  dir <- c(rep("=", m), rep("<=", NROW(cap)))
  rhs <- c(g, cap_rhs)
  Z <- numeric(length(levels))
  for (j in seq_along(levels)) {
    sol <- lpSolve::lp("min", levels[[j]], mat, dir, rhs)
    if (sol$status != 0) return(NULL)
    Z[j] <- sol$objval
    mat <- rbind(mat, levels[[j]])
    dir <- c(dir, if (slack == 0) "=" else "<=")
    rhs <- c(rhs, Z[j] + slack * max(1, abs(Z[j])))
  }
  Z
}
