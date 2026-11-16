# Synthetic databases for the generalization tests: n sectors, k satellite
# accounts, consistent (f = x - Z 1, so f = (I - A) x), with a productive A.
# The accounts are declared as levels E (a data frame, one column per
# account); the corridor is two-sided unless `corridor = FALSE`.
simulate_io <- function(n, k, seed = 1, density = 0.6, corridor = TRUE) {
  set.seed(seed)
  f <- stats::runif(n, 20, 200)
  # columns of A summing to less than 0.6: A is productive
  A <- matrix(stats::runif(n * n), n) * (matrix(stats::runif(n * n), n) < density)
  A <- sweep(A, 2, pmax(colSums(A), 1e-12) / stats::runif(n, 0.2, 0.6), "/")
  x <- as.numeric(solve(diag(n) - A, f))
  Z <- A * matrix(x, n, n, byrow = TRUE)
  S <- matrix(stats::runif(n * k, 0.5, 5), n, k) * x / 100
  colnames(S) <- paste0("C", seq_len(k))
  alpha <- stats::runif(n, 0.05, 0.3)
  declare_io(Z = Z, x = x, f = x - rowSums(Z), E = as.data.frame(S), corridor = if (corridor) alpha)
}

# Synthetic model: the 1st account is a floor that gets a shock of `share`
# on the sum of the first two; the others alternate ceiling (base) and floor
# (growth of 2%).
simulate_model <- function(io, share = 0.05, multiplier = 1, ...) {
  acc <- io$accounts
  spec <- lapply(seq_along(acc), function(i) {
    if (i == 1) {
      list(direction = ">=", target = list(type = "pooled_share", share = share, pool = acc[seq_len(min(2, length(acc)))]))
    } else if (i %% 2 == 0) {
      list(direction = "<=", target = "base")
    } else {
      list(direction = ">=", target = list(type = "growth", rate = 0.02))
    }
  })
  names(spec) <- acc
  define_model(spec, corridor = list(use = TRUE, multiplier = multiplier), ...)
}
