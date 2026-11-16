# Corridor modes: free, two-sided, floor only, ceiling only, floor and ceiling,
# NA sectors, use = FALSE and the multiplier, in the LP and in the solutions.

corridor_io <- function(...) {
  io <- simulate_io(6, 2, seed = 21, corridor = FALSE)
  declare_io(Z = io$declared$structure_matrix, x = io$x, f = io$f, E = as.data.frame(io$declared$account_matrix),
             ...)
}

lp_of <- function(io, model, scenario = 1) {
  r <- run_experiment(io, model, scenario = scenario, ordering = 1, strict = FALSE)
  build_lp(list(D = io$D, B = io$B), r$g, r$floor, r$ceiling)
}

# rows of the LP that bound a deviation: which variable and which bound
cap_rows <- function(lp) {
  if (!lp$n_cap) return(data.frame(var = integer(), rhs = numeric()))
  A <- lp$A[lp$m + seq_len(lp$n_cap), , drop = FALSE]
  data.frame(var = apply(A, 1, function(r) which(r == 1)), rhs = lp$rhs[lp$m + seq_len(lp$n_cap)])
}

test_that("free: no corridor rows; floor only bounds d-, ceiling only bounds d+", {
  alpha <- c(0.1, 0.2, 0.15, 0.3, 0.05, 0.25)
  free <- corridor_io()
  m <- simulate_model(free)
  lp0 <- lp_of(free, m)
  expect_identical(lp0$n_cap, 0L)
  lo <- corridor_io(floor = alpha)
  lpl <- lp_of(lo, m)
  cl <- cap_rows(lpl)
  expect_identical(nrow(cl), 6L)
  expect_identical(cl$var, lpl$idx_d_min[lpl$n_sat + 1:6])
  expect_equal(cl$rhs, alpha * abs(lpl$g[lpl$n_sat + 1:6]))
  hi <- corridor_io(ceiling = alpha)
  ch <- cap_rows(lp_of(hi, m))
  expect_identical(ch$var, lpl$idx_d_plus[lpl$n_sat + 1:6])
  both <- corridor_io(floor = alpha, ceiling = 2 * alpha)
  cb <- cap_rows(lp_of(both, m))
  expect_identical(nrow(cb), 12L)
  # for each economic row, the bound on d- and then the bound on d+
  expect_identical(cb$var, as.integer(rbind(lpl$idx_d_min[lpl$n_sat + 1:6], lpl$idx_d_plus[lpl$n_sat + 1:6])))
})

test_that("corridor = alpha is identical to floor = ceiling = alpha", {
  alpha <- c(0.1, 0.2, 0.15, 0.3, 0.05, 0.25)
  a <- corridor_io(corridor = alpha)
  b <- corridor_io(floor = alpha, ceiling = alpha)
  m <- simulate_model(a)
  expect_identical(unclass(lp_of(a, m))[c("A", "dir", "rhs")], unclass(lp_of(b, m))[c("A", "dir", "rhs")])
  ra <- run_model(a, m, verbose = FALSE)
  rb <- run_model(b, m, verbose = FALSE)
  for (j in seq_along(ra$runs)) {
    expect_identical(ra$runs[[j]]$Z, rb$runs[[j]]$Z)
    expect_identical(ra$runs[[j]]$x_star, rb$runs[[j]]$x_star)
  }
  expect_identical(ra$runs[[1]]$corridor$mode, "two-sided corridor")
  expect_identical(rb$runs[[1]]$corridor$mode, "floor and ceiling")
})

test_that("NA leaves a sector without bound; use = FALSE is the free model", {
  alpha <- c(0.1, NA, 0.15, 0.3, NA, 0.25)
  io <- corridor_io(corridor = alpha)
  m <- simulate_model(io)
  lp <- lp_of(io, m)
  expect_identical(lp$n_cap, 8L)
  cr <- cap_rows(lp)
  bounded <- lp$n_sat + which(!is.na(alpha))
  expect_identical(cr$var, as.integer(rbind(lp$idx_d_min[bounded], lp$idx_d_plus[bounded])))
  free <- corridor_io()
  m_off <- simulate_model(io, scenarios = list(off = list(corridor = list(use = FALSE))))
  r_off <- run_experiment(io, m_off, scenario = "off", ordering = 1)
  r_free <- run_experiment(free, simulate_model(free), ordering = 1)
  expect_identical(r_off$Z, r_free$Z)
  expect_identical(r_off$x_star, r_free$x_star)
  expect_identical(r_off$corridor$mode, "not used (free)")
  expect_null(r_off$floor)
  expect_identical(lp_of(io, m_off, "off")$n_cap, 0L)
})

test_that("the solutions respect the declared sides, and the multiplier scales them", {
  alpha <- rep(0.02, 6)
  m <- simulate_model(corridor_io(), share = 0.3)
  check <- function(io, mult = 1) {
    mm <- simulate_model(io, share = 0.3, multiplier = mult)
    res <- suppressWarnings(run_model(io, mm, verbose = FALSE))
    k <- length(io$accounts)
    for (r in res$runs) {
      if (!r$optimal) next
      eco <- k + seq_len(io$n)
      if (!is.null(r$floor)) expect_true(all(r$d_minus[eco] <= r$floor * abs(r$g[eco]) + 1e-9 * abs(r$g[eco])))
      if (!is.null(r$ceiling)) expect_true(all(r$d_plus[eco] <= r$ceiling * abs(r$g[eco]) + 1e-9 * abs(r$g[eco])))
    }
    res
  }
  lo <- check(corridor_io(floor = alpha))
  expect_identical(lo$runs[[1]]$ceiling, NULL)
  hi <- check(corridor_io(ceiling = alpha))
  expect_identical(hi$runs[[1]]$floor, NULL)
  two <- check(corridor_io(corridor = alpha), mult = 3)
  expect_identical(two$runs[[1]]$floor, 3 * alpha)
  # a wider corridor never makes the first level worse; the free model is the widest
  z <- vapply(list(corridor_io(corridor = alpha), corridor_io(floor = alpha), corridor_io()), function(io) {
    run_experiment(io, m, ordering = 1, strict = FALSE)$Z[1]
  }, numeric(1))
  expect_true(z[2] <= z[1] + 1e-9 && z[3] <= z[2] + 1e-9)
})
