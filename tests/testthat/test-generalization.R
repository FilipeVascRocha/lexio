# Generalization: synthetic databases with n sectors and k satellite accounts.
# Properties of a lexicographic Goal Programming (those of Phase 1b) and
# invariances of the declaration. The models use the default lock ("auto"):
# runs solved only with the relaxed lock are flagged, with a warning.

grid <- expand.grid(n = c(2, 5, 10, 30), k = 1:4)
grid <- rbind(grid, data.frame(n = c(100, 12), k = c(3, 5)))

# run_model, keeping the warnings about relaxed locks aside
run_quiet <- function(...) suppressWarnings(run_model(...))

test_that("dimensions, number of orderings and ECO last, for several n and k", {
  for (i in seq_len(nrow(grid))) {
    n <- grid$n[i]
    k <- grid$k[i]
    io <- simulate_io(n, k, seed = i)
    m <- simulate_model(io)
    res <- run_quiet(io, m, verbose = FALSE)
    lab <- sprintf("n=%d k=%d", n, k)
    expect_length(res$runs, factorial(k))
    expect_identical(vapply(res$runs, `[[`, numeric(1), "ordering"), as.double(seq_len(factorial(k))), label = lab)
    for (r in res$runs) {
      expect_length(r$levels, k + 1)
      expect_identical(r$order[k + 1], "ECO")
      expect_length(r$x_star, n)
      expect_identical(nrow(lexio:::all_levels_table(r, lexio:::g_rows(r, m))), as.integer(k + n))
    }
    expect_identical(nrow(res$summary$goals), as.integer(factorial(k) * k))
  }
})

test_that("no degradation, and a higher priority never does worse, for several n and k", {
  n_opt <- 0
  n_runs <- 0
  n_relaxed <- 0
  for (i in seq_len(nrow(grid))) {
    io <- simulate_io(grid$n[i], grid$k[i], seed = 100 + i)
    m <- simulate_model(io)
    res <- run_quiet(io, m, verbose = FALSE)
    acc <- io$accounts
    for (r in res$runs) {
      n_runs <- n_runs + 1
      # a relaxed lock is used only where the exact lock did not end optimal
      expect_identical(r$lock_tolerance > 0, r$optimal && any(r$status_exact != 0L))
      n_relaxed <- n_relaxed + (r$lock_tolerance > 0)
      if (!r$optimal) next
      n_opt <- n_opt + 1
      expect_true(all(r$checks$ok_rel), label = sprintf("n=%d k=%d %s", grid$n[i], grid$k[i], r$label))
    }
    # final penalized deviation of each account: with it first <= with it in any other position
    for (a in seq_along(acc)) {
      dev <- vapply(res$runs, function(r) {
        term <- list(rows = a, type = direction_type(r$directions[[acc[a]]]), weight = 1)
        lexio:::penalized_deviation(r$d_plus, r$d_minus, list(terms = list(term)))
      }, numeric(1))
      first <- vapply(res$runs, function(r) r$order[1] == acc[a], logical(1))
      ok <- vapply(res$runs, `[[`, logical(1), "optimal")
      if (any(first & ok) && any(!first & ok)) {
        tol <- 1e-8 * max(1, abs(satellite_base(io)[[a]]))
        expect_true(max(dev[first & ok]) <= min(dev[!first & ok]) + tol,
                    label = sprintf("n=%d k=%d account %s", grid$n[i], grid$k[i], acc[a]))
      }
    }
  }
  # the false infeasibility of GLPK is rare in these databases, and "auto" solves most of it
  expect_gt(n_opt / n_runs, 0.95)
})

test_that("zero shock with a consistent database: Z = 0 and x* = x", {
  for (i in seq_len(nrow(grid))) {
    io <- simulate_io(grid$n[i], grid$k[i], seed = 200 + i)
    spec <- stats::setNames(lapply(io$accounts, function(a) list(direction = ">=", target = "base")), io$accounts)
    res <- run_quiet(io, define_model(spec, corridor = list(multiplier = 0)), verbose = FALSE)
    for (r in res$runs) {
      if (!r$optimal) next
      expect_equal(r$Z, rep(0, length(r$Z)), tolerance = 1e-8)
      expect_equal(r$x_star, io$x, tolerance = 1e-8)
    }
  }
})

test_that("monotonicity in the corridor and in the shock", {
  io <- simulate_io(10, 3, seed = 7)
  z_alpha <- vapply(c(0, 0.5, 1, 2, 10), function(mu) {
    run_experiment(io, simulate_model(io, multiplier = mu), ordering = 1, strict = FALSE)$Z[1]
  }, numeric(1))
  expect_true(all(diff(z_alpha) <= 1e-8 * max(1, z_alpha)))
  z_s <- vapply(c(0, 0.01, 0.05, 0.2, 1), function(s) {
    run_experiment(io, simulate_model(io, share = s), ordering = 1, strict = FALSE)$Z[1]
  }, numeric(1))
  expect_true(all(diff(z_s) >= -1e-8 * max(1, z_s)))
})

test_that("invariances: order of sectors, order of declaration of the accounts, unit and form of the corridor", {
  io <- simulate_io(8, 3, seed = 11)
  m <- simulate_model(io)
  base <- run_quiet(io, m, verbose = FALSE)
  Z <- io$declared$structure_matrix
  S <- io$declared$account_matrix
  # 1. sectors in another order
  p <- c(5, 2, 8, 1, 7, 3, 6, 4)
  io_p <- declare_io(Z = Z[p, p], x = io$x[p], f = io$f[p], E = as.data.frame(S[p, ]), corridor = io$floor[p],
                     sectors = io$sectors[p, ])
  res_p <- run_quiet(io_p, m, verbose = FALSE)
  for (j in seq_along(base$runs)) {
    expect_equal(res_p$runs[[j]]$Z, base$runs[[j]]$Z, tolerance = 1e-8)
    expect_equal(res_p$runs[[j]]$gx[1:3], base$runs[[j]]$gx[1:3], tolerance = 1e-8)
  }
  # 2. accounts declared in another order: the same priority ordering gives the same Z
  m_r <- define_model(m$accounts[c(3, 1, 2)])
  for (j in seq_along(base$runs)) {
    ord <- base$runs[[j]]$order[1:3]
    r <- run_experiment(io, m_r, ordering = ord, strict = FALSE)
    expect_equal(r$Z, base$runs[[j]]$Z, tolerance = 1e-8)
  }
  # 3. the 3rd account in another unit (x 1000): Z of that level scales, the others and x* stay
  S3 <- S
  S3[, 3] <- S3[, 3] * 1000
  io_u <- declare_io(Z = Z, x = io$x, f = io$f, E = as.data.frame(S3), corridor = io$floor, sectors = io$sectors)
  res_u <- run_quiet(io_u, m, verbose = FALSE)
  for (j in seq_along(base$runs)) {
    lev3 <- which(base$runs[[j]]$order == "C3")
    expect_equal(res_u$runs[[j]]$Z[lev3], 1000 * base$runs[[j]]$Z[lev3], tolerance = 1e-7)
    expect_equal(res_u$runs[[j]]$Z[-lev3], base$runs[[j]]$Z[-lev3], tolerance = 1e-7)
  }
  # 4. the same corridor declared as floor and ceiling: the same problem, the same numbers
  io_b <- declare_io(Z = Z, x = io$x, f = io$f, E = as.data.frame(S), floor = io$floor, ceiling = io$floor,
                     sectors = io$sectors)
  res_b <- run_quiet(io_b, m, verbose = FALSE)
  for (j in seq_along(base$runs)) expect_identical(res_b$runs[[j]]$Z, base$runs[[j]]$Z)
  # 5. accounts declared as coefficients D: the same numbers
  D <- lapply(stats::setNames(io$accounts, io$accounts), function(a) io$D[match(a, io$accounts), ])
  io_d <- declare_io(B = io$B, x = io$x, f = io$f, D = D, corridor = io$floor, sectors = io$sectors)
  res_d <- run_quiet(io_d, m, verbose = FALSE)
  for (j in seq_along(base$runs)) expect_identical(res_d$runs[[j]]$Z, base$runs[[j]]$Z)
})
