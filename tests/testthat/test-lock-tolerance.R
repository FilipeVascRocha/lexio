# lock_tolerance: "auto" by default (exact lock first; the
# relaxed lock only in the runs where the exact one does not end optimal),
# "exact" to keep only the exact lock.

test_that("lock_tolerance: accepted values and sequence of tolerances", {
  expect_identical(lexio:::lock_tolerances(0), 0)
  expect_identical(lexio:::lock_tolerances("exact"), 0)
  expect_identical(lexio:::lock_tolerances("auto"), c(0, 1e-12, 1e-11, 1e-10, 1e-9))
  expect_identical(lexio:::lock_tolerances(1e-9), c(0, 1e-9))
  expect_identical(lexio:::lock_tolerances("1e-9"), c(0, 1e-9))
  for (bad in list(-1, 1e-3, "x", c(0, 1), NA)) expect_error(lexio:::check_lock_tolerance(bad), "lock_tolerance")
  expect_identical(define_model(list(E = list(direction = ">=")))$lock_tolerance, "auto")
  expect_identical(define_model(list(E = list(direction = ">=")), lock_tolerance = "exact")$lock_tolerance, 0)
  yml <- tempfile(fileext = ".yml")
  writeLines(c("accounts:", "  E: {direction: \">=\"}", "lock_tolerance: 1e-10"), yml)
  expect_identical(read_model(yml)$lock_tolerance, 1e-10)
  writeLines(c("accounts:", "  E: {direction: \">=\"}"), yml)
  expect_identical(read_model(yml)$lock_tolerance, "auto")
})

test_that("default auto: runs that are optimal with the exact lock keep it, and the run records it", {
  res <- run_model(system.file("examples", "toy", "model.yml", package = "lexio"), verbose = FALSE)
  expect_identical(res$model$lock_tolerance, "auto")
  for (r in res$runs) {
    expect_identical(r$lock_tolerance, 0)
    expect_identical(r$status_exact, r$status)
  }
  expect_true(all(res$summary$runs$lock_tolerance == 0))
})

test_that("auto does not change the runs that are already optimal with the exact lock", {
  io <- simulate_io(10, 3, seed = 5)
  m <- simulate_model(io, lock_tolerance = "exact")
  a <- run_model(io, m, verbose = FALSE)
  b <- run_model(io, m, verbose = FALSE, lock_tolerance = "auto")
  for (j in seq_along(a$runs)) {
    expect_true(a$runs[[j]]$optimal)
    expect_identical(b$runs[[j]]$Z, a$runs[[j]]$Z)
    expect_identical(b$runs[[j]]$x_star, a$runs[[j]]$x_star)
    expect_identical(b$runs[[j]]$lock_tolerance, 0)
  }
})

test_that("relaxed lock: the same optima, up to the slack, and checks ok", {
  io <- simulate_io(12, 3, seed = 9)
  m <- simulate_model(io)
  r <- run_experiment(io, m, ordering = 4)
  lp <- build_lp(list(D = io$D, B = io$B), r$g, r$floor, r$ceiling)
  pr <- lexio:::priority_levels(m, 1, 4, io$n)
  s <- solve_lexicographic(lp, pr$levels, lock_tolerance = 1e-9)
  expect_true(all(vapply(s$levels, `[[`, numeric(1), "status_code") == 0))
  expect_true(all(s$checks$ok_rel))
  expect_identical(s$lock_tolerance, 1e-9)
  expect_lt(max(abs(s$Z - r$Z) / pmax(abs(r$Z), 1)), 1e-6)
})

test_that("retry: when the exact lock fails, the run is solved again with the relaxed one", {
  io <- simulate_io(6, 2, seed = 3)
  m <- simulate_model(io)
  expect_identical(m$lock_tolerance, "auto")
  real <- lexio:::solve_lexicographic
  tried <- numeric(0)
  # simulates the false infeasibility: with the exact lock and with 1e-12, the last level "fails"
  testthat::local_mocked_bindings(solve_lexicographic = function(lp, priorities, keep_lp = FALSE, lock_tolerance = 0) {
    tried <<- c(tried, lock_tolerance)
    s <- real(lp, priorities, keep_lp = keep_lp, lock_tolerance = lock_tolerance)
    if (lock_tolerance < 1e-11) s$levels[[length(s$levels)]]$status_code <- 1L
    s
  })
  r <- run_experiment(io, m, ordering = 1)
  expect_identical(tried, c(0, 1e-12, 1e-11))
  expect_true(r$optimal)
  expect_identical(r$lock_tolerance, 1e-11)
  expect_identical(r$status_exact, c(0L, 0L, 1L))
  expect_output(print(r), "WARNING: solved with the relaxed lock")
  # exact lock only: the run keeps the exact lock and is flagged
  tried <- numeric(0)
  r0 <- run_experiment(io, m, ordering = 1, strict = FALSE, lock_tolerance = "exact")
  expect_identical(tried, 0)
  expect_false(r0$optimal)
  expect_identical(r0$lock_tolerance, 0)
  # no tolerance solves it: the exact one stays
  testthat::local_mocked_bindings(solve_lexicographic = function(lp, priorities, keep_lp = FALSE, lock_tolerance = 0) {
    s <- real(lp, priorities, keep_lp = keep_lp, lock_tolerance = lock_tolerance)
    s$levels[[length(s$levels)]]$status_code <- 1L
    s
  })
  r1 <- run_experiment(io, m, ordering = 1, strict = FALSE)
  expect_false(r1$optimal)
  expect_identical(r1$lock_tolerance, 0)
  expect_error(run_experiment(io, m, ordering = 1), "not optimal")
})

test_that("warnings, report and summary show the runs with the relaxed lock and its cost", {
  io <- simulate_io(6, 2, seed = 3)
  m <- simulate_model(io)
  real <- lexio:::solve_lexicographic
  testthat::local_mocked_bindings(solve_lexicographic = function(lp, priorities, keep_lp = FALSE, lock_tolerance = 0) {
    s <- real(lp, priorities, keep_lp = keep_lp, lock_tolerance = lock_tolerance)
    if (lock_tolerance == 0) s$levels[[1]]$status_code <- 1L
    s
  })
  expect_warning(res <- run_model(io, m, verbose = FALSE), "relaxed lock")
  expect_identical(res$summary$runs$lock_tolerance, c(1e-12, 1e-12))
  expect_output(print(res), "WARNING: 2 run\\(s\\) solved only with the relaxed lock")
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("relaxed lock", rep)))
  expect_true(any(grepl("Precision cost", rep)))
  ord <- utils::read.csv(file.path(dir, "orderings.csv"))
  expect_true("lock_tolerance" %in% names(ord))
  expect_identical(ord$lock_tolerance, c(1e-12, 1e-12))
})
