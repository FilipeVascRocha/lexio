#' Build the goal programming problem
#'
#' Builds the constraints shared by every priority level,
#'
#' \deqn{G x + d^- - d^+ = g, \qquad G = \begin{bmatrix} D \\ I - A \end{bmatrix},}
#'
#' with the decision variables in the order `x_1..x_n, d_1^+..d_m^+,
#' d_1^-..d_m^-` (all `>= 0`, `m = k + n`), and, when declared, the corridor
#' on the economic goals (the rows of `I - A`):
#' `d_h^- <= alpha_h^floor |g_h|` and `d_h^+ <= alpha_h^ceiling |g_h|`
#' (Rocha, 2026, eq. 4.38). A side that is `NULL` or `NA` in a sector has no bound
#' there; with both sides `NULL` the model is free. Satellite rows never have
#' a corridor.
#'
#' The rows of the constraint matrix are, in this order: the `m` goals, then, for each economic row, the bound on `d^-` and
#' the bound on `d^+`. The locks of the levels already solved are added by
#' [solve_lexicographic()].
#'
#' @param inputs List with `D` (k x n account coefficients) and `B`
#'   (`I - A`), for instance a `lexio_io` object.
#' @param g Goal vector (`k + n`), for instance from [build_goals()].
#' @param floor,ceiling Corridor proportions (n, `NA` = no bound) or `NULL`.
#'
#' @return Object of class `lexio_lp`: a list with `G`, the constraint matrix
#'   `A`, `dir`, `rhs`, `bounds` (ROI `V_bound`) and the indices `idx_x`,
#'   `idx_d_plus`, `idx_d_min`.
#' @export
build_lp <- function(inputs, g, floor = NULL, ceiling = NULL) {
  G <- rbind(inputs$D, inputs$B)
  n_sat <- nrow(G) - nrow(inputs$B)
  n <- ncol(G)
  m <- nrow(G)
  n_var <- n + 2 * m
  if (length(g) != m) stop("g must have ", m, " values", call. = FALSE)
  for (side in list(floor, ceiling)) {
    if (!is.null(side) && length(side) != n) stop("the corridor must have ", n, " values", call. = FALSE)
  }
  idx_x <- 1:n
  idx_d_plus <- (n + 1):(n + m)
  idx_d_min <- (n + m + 1):(n + 2 * m)

  # Goals: G x - d+ + d- = g
  A_eq <- cbind(G, -diag(m), diag(m))
  rhs <- as.numeric(g)
  dir <- rep("==", m)

  # Corridor on the economic goals: for each row, d- (floor) then d+ (ceiling)
  eco_rows <- (n_sat + 1):m
  caps <- list()
  for (r in eco_rows) {
    h <- r - n_sat
    if (!is.null(floor) && !is.na(floor[h])) caps[[length(caps) + 1]] <- c(idx_d_min[r], floor[h] * abs(as.numeric(g[r])))
    if (!is.null(ceiling) && !is.na(ceiling[h])) {
      caps[[length(caps) + 1]] <- c(idx_d_plus[r], ceiling[h] * abs(as.numeric(g[r])))
    }
  }
  n_cap <- length(caps)
  A_cap <- matrix(0, nrow = n_cap, ncol = n_var)
  rhs_cap <- numeric(n_cap)
  for (k in seq_len(n_cap)) {
    A_cap[k, caps[[k]][1]] <- 1
    rhs_cap[k] <- caps[[k]][2]
  }

  structure(list(
    G = G,
    A = rbind(A_eq, A_cap),
    dir = c(dir, rep("<=", n_cap)),
    rhs = c(rhs, rhs_cap),
    bounds = ROI::V_bound(li = 1:n_var, ui = 1:n_var, lb = rep(0, n_var), ub = rep(Inf, n_var)),
    g = rhs, floor = floor, ceiling = ceiling,
    n = n, m = m, n_sat = n_sat, n_var = n_var, n_cap = n_cap,
    idx_x = idx_x, idx_d_plus = idx_d_plus, idx_d_min = idx_d_min
  ), class = "lexio_lp")
}

#' Direction of a goal and the deviation it penalizes
#'
#' `">="` (the goal is a floor) penalizes `d-`; `"<="` (a ceiling) penalizes
#' `d+`; `"="` penalizes both.
#'
#' @param direction `">="`, `"<="` or `"="`.
#' @return `"minus"`, `"plus"` or `"both"`.
#' @examples
#' direction_type(c(">=", "<=", "="))
#' @export
direction_type <- function(direction) {
  out <- c(">=" = "minus", "<=" = "plus", "=" = "both")[direction]
  if (anyNA(out)) stop("invalid direction: use '>=', '<=' or '='", call. = FALSE)
  unname(out)
}

# Terms of a priority level: one per goal, each with its G rows, the
# penalized deviation type and a weight. A level written in the short form
# (rows + type) is one term with weight 1.
level_terms <- function(level) {
  if (!is.null(level$terms)) return(level$terms)
  list(list(rows = level$rows, type = level$type, weight = 1))
}

# Indices (in the decision vector) and weights of the penalized deviations of
# a level, in the order of its terms. For one term with weight 1 this is the
# plain index vector of its deviations.
deviation_index <- function(lp, level) {
  idx <- list()
  w <- list()
  for (t in level_terms(level)) {
    i <- switch(t$type,
      minus = lp$idx_d_min[t$rows],
      plus = lp$idx_d_plus[t$rows],
      both = c(lp$idx_d_plus[t$rows], lp$idx_d_min[t$rows]),
      stop("invalid deviation type: ", t$type, call. = FALSE)
    )
    idx[[length(idx) + 1]] <- i
    w[[length(w) + 1]] <- term_weights(t, length(i))
  }
  list(idx = unlist(idx), weight = unlist(w))
}

# Weights of the `len` deviations of a term: one weight for the whole term, or
# one per row (the relative economic deviations), repeated for d+ and d- when
# the term penalizes both.
term_weights <- function(t, len) {
  if (length(t$weight) == 1) rep(t$weight, len) else rep(t$weight, len / length(t$rows))
}

# Weighted sum of the penalized deviations of a level (for "both", d- before
# d+; the summation order fixes the last bit of the sum).
penalized_deviation <- function(d_plus, d_minus, level) {
  vals <- list()
  w <- list()
  for (t in level_terms(level)) {
    v <- switch(t$type,
      minus = d_minus[t$rows],
      plus = d_plus[t$rows],
      both = c(d_minus[t$rows], d_plus[t$rows])
    )
    vals[[length(vals) + 1]] <- v
    w[[length(w) + 1]] <- term_weights(t, length(v))
  }
  vals <- unlist(vals)
  w <- unlist(w)
  if (all(w == 1)) sum(vals) else sum(w * vals)
}
