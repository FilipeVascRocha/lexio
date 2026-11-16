# Independent check: the same lexicographic Goal Programming, built from
# scratch (helper-lpsolve.R) and solved with another solver (lpSolve), gives
# the same optima Z as the package (GLPK). Only in the tests: the model stays
# on GLPK.

test_that("optima Z equal to those of an independent solver (lpSolve)", {
  testthat::skip_if_not_installed("lpSolve")
  n_cmp <- 0
  for (case in 1:12) {
    n <- c(3, 4, 6)[(case - 1) %% 3 + 1]
    k <- c(1, 2, 3)[(case - 1) %/% 4 + 1]
    io <- simulate_io(n, k, seed = 300 + case)
    m <- simulate_model(io, lock_tolerance = "exact")
    res <- run_model(io, m, verbose = FALSE)
    for (r in res$runs) {
      if (!r$optimal) next
      z_ref <- lexico_lpsolve(io, m, r$levels_goals)
      if (is.null(z_ref)) next
      n_cmp <- n_cmp + 1
      scale <- pmax(abs(z_ref), 1)
      expect_true(all(abs(r$Z - z_ref) <= 1e-6 * scale),
                  label = sprintf("n=%d k=%d %s: %s vs %s", n, k, r$label, paste(signif(r$Z, 8), collapse = " "),
                                  paste(signif(z_ref, 8), collapse = " ")))
    }
  }
  expect_gt(n_cmp, 20)
})
