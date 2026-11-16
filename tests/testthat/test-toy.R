# Tests on the toy model (3 sectors), without external data.

toy_model_path <- function() system.file("examples", "toy", "model.yml", package = "lexio")

test_that("the goals follow the goal rules", {
  io <- example_io()
  m <- read_model(toy_model_path())
  b <- unname(satellite_base(io))
  expect_equal(b, c(6.6, 29, 260))
  MtE <- (b[1] + b[2]) * 0.05
  expect_identical(build_goals(io, m, "E_shock"), c(b[1] + MtE, b[2], b[3] + b[3] * 0.05, io$f))
  expect_identical(build_goals(io, m, "I_shock"), c(b[1], b[2] + MtE, b[3] + b[3] * 0.05, io$f))
  expect_equal(build_goals(io, m, "E_shock"), c(8.38, 29, 273, 70, 42, 39))
  m2 <- define_model(list(E = list(direction = ">=", target = list(type = "delta", value = 1)),
                          I = list(direction = "<=", target = list(type = "level", value = 30))),
                     economy = list(target = c(1, 2, 3)))
  expect_identical(build_goals(io, m2), c(b[1] + 1, 30, 1, 2, 3))
  expect_error(build_goals(io, define_model(list(X = list(direction = ">=", target = "base")))),
               "not in the database")
})

test_that("run_model runs every ordering of every scenario", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  expect_s3_class(res, "lexio_results")
  expect_length(res$runs, 12)
  s <- res$summary
  expect_identical(nrow(s$runs), 12L)
  expect_true(all(s$runs$ok))
  expect_true(all(s$runs$lock_tolerance == 0))
  expect_identical(unique(s$runs$scenario), c("E_shock", "I_shock"))
  expect_identical(s$runs$ordering[1:6], as.double(1:6))
  expect_identical(s$runs$label[1:6], sprintf("P%02d", 1:6))
  expect_identical(s$runs$priorities[4], "I > LAB > E > ECO")
  expect_identical(s$runs$corridor[1], "two-sided corridor")
  expect_identical(nrow(s$goals), 36L)
  expect_true(nrow(s$states) >= 1)
})

test_that("regression values of the toy model (scenario E_shock)", {
  res <- run_model(toy_model_path(), scenarios = "E_shock", verbose = FALSE)
  ref <- list(c(0.781323975116, 4.31383314723, 0, 0),
              c(0.781323975116, 0, 4.31383314723, 0),
              c(0, 1.72818473308, 30.0487146313, 12.85),
              c(0, 0, 1.80407407407, 3.27808641975),
              c(0, 0.781323975116, 4.31383314723, 0),
              c(0, 0, 1.80407407407, 3.27808641975))
  for (P in 1:6) expect_equal(res$runs[[P]]$Z, ref[[P]], tolerance = 1e-10)
})

test_that("zero shock with consistent goals: Z = 0, x* = x and Gx = g", {
  io <- example_io()
  m <- define_model(list(E = list(direction = ">=", target = "base"), I = list(direction = "<=", target = "base"),
                         LAB = list(direction = ">=", target = "base")))
  res <- run_model(io, m, verbose = FALSE)
  for (r in res$runs) {
    expect_true(r$ok)
    expect_equal(r$Z, rep(0, 4), tolerance = 1e-10)
    expect_equal(r$x_star, io$x, tolerance = 1e-10)
    expect_equal(r$gx, r$g, tolerance = 1e-10)
  }
})

test_that("levels are preserved and a higher priority never does worse", {
  res <- run_model(toy_model_path(), scenarios = "E_shock", verbose = FALSE)
  for (r in res$runs) {
    expect_true(all(r$checks$ok_rel))
    expect_true(all(r$checks$ok))
  }
  dev_e <- vapply(res$runs, function(r) r$d_minus[1], numeric(1))
  expect_true(all(dev_e[1:2] <= min(dev_e[3:6]) + 1e-10))
  dev_i <- vapply(res$runs, function(r) r$d_plus[2], numeric(1))
  expect_true(all(dev_i[3:4] <= min(dev_i[c(1, 2, 5, 6)]) + 1e-10))
})

test_that("monotonicity in the corridor and in the shock", {
  io <- example_io()
  acc <- list(E = list(direction = ">=", target = list(type = "pooled_share", share = 0.05, pool = c("E", "I"))),
              I = list(direction = "<=", target = "base"),
              LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05)))
  z1_alpha <- vapply(c(0, 0.5, 1, 2, 10), function(a) {
    run_experiment(io, define_model(acc, corridor = list(multiplier = a)), ordering = 1)$Z[1]
  }, numeric(1))
  expect_true(all(diff(z1_alpha) <= 1e-10))
  z1_free <- run_experiment(io, define_model(acc, corridor = list(use = FALSE)), ordering = 1)$Z[1]
  expect_true(z1_free <= min(z1_alpha) + 1e-10)
  z1_s <- vapply(c(0, 0.01, 0.05, 0.2, 1), function(s) {
    acc$E$target$share <- s
    run_experiment(io, define_model(acc), ordering = 1)$Z[1]
  }, numeric(1))
  expect_true(all(diff(z1_s) >= -1e-10))
})

test_that("ordering by names, direction '=' and a scenario with its own directions", {
  io <- example_io()
  m <- read_model(toy_model_path())
  r <- run_experiment(io, m, "E_shock", ordering = c("LAB", "E", "I"))
  expect_identical(r$order, c("LAB", "E", "I", "ECO"))
  expect_identical(r$ordering, 5)
  expect_identical(r$label, "P05")
  expect_identical(run_experiment(io, m, "E_shock", ordering = "P05")$Z, r$Z)
  m2 <- define_model(m$accounts, scenarios = list(eq = list(directions = list(economy = "="))))
  r2 <- run_experiment(io, m2, "eq", ordering = 1)
  expect_true(r2$ok)
  expect_identical(r2$levels[[4]]$type, "both")
  expect_error(run_experiment(io, m, "E_shock", ordering = c("E", "E", "I")), "once")
  expect_error(run_experiment(io, m, "E_shock", ordering = 7), "does not exist")
  expect_error(run_experiment(io, m, "no_such_scenario"), "scenario does not exist")
})

test_that("a level without solution: error with strict; left blank and flagged without strict", {
  io <- example_io()
  m <- read_model(toy_model_path())
  expect_error(define_model(m$accounts, scenarios = list(bad = list(corridor = list(multiplier = -1)))), ">= 0")
  # a zero corridor and an economic goal that needs a negative output: no solution
  m_bad <- define_model(m$accounts, economy = list(direction = ">=", target = c(10, -500, 10)),
                        scenarios = list(bad = list(corridor = list(multiplier = 0))), lock_tolerance = "exact")
  expect_error(run_experiment(io, m_bad, "bad", ordering = 1), "no solution")
  r <- run_experiment(io, m_bad, "bad", ordering = 1, strict = FALSE)
  expect_false(r$ok)
  expect_identical(r$infeasible_level, 1L)
  expect_gt(r$violation[1], 1e-4)
  expect_true(all(is.na(r$Z)))
  expect_true(all(is.na(r$x_star)))
  expect_output(print(r), "level 1 has no solution")
  expect_warning(res <- run_model(io, m_bad, verbose = FALSE), "no solution")
  expect_false(any(res$summary$runs$optimal))
  expect_true(all(res$summary$runs$infeasible_level == 1L))
  expect_true(all(is.na(res$summary$runs$state)))
  expect_identical(nrow(res$summary$states), 0L)
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("level 1 has no solution", rep)))
  expect_true(file.exists(file.path(dir, "results.xlsx")))
})

test_that("print and report: a scenario without solution next to a solved one", {
  io <- example_io()
  m <- read_model(toy_model_path())
  m2 <- define_model(m$accounts, economy = list(direction = ">=", target = c(10, -500, 10)),
                     scenarios = list(bad = list(corridor = list(multiplier = 0)),
                                      free = list(corridor = list(use = FALSE))), lock_tolerance = "exact")
  expect_warning(res <- run_model(io, m2, verbose = FALSE), "no solution")
  out <- capture.output(print(res))
  expect_match(grep("scenario bad", out, value = TRUE), "6 with a non-optimal level (6 without solution) | 0 distinct",
               fixed = TRUE)
  n_free <- nrow(res$summary$states)
  expect_gt(n_free, 0)
  expect_match(grep("scenario free", out, value = TRUE), paste0("all optimal | ", n_free, " distinct"), fixed = TRUE)
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_identical(sum(grepl("| no solution from level 1 |", rep, fixed = TRUE)), 6L)
  expect_false(any(grepl("not optimal at level 1, 2", rep, fixed = TRUE)))
})

test_that("numbers of the report: decimals follow the scale of the quantity", {
  expect_identical(lexio:::report_num(c(12345.678, 0.03, 0.0315, 0.0015, -0.03, 0.8, 1e-9, NA, 0)),
                   c("12,345.68", "0.0300", "0.0315", "0.00150", "-0.0300", "0.800", "0.00", "", "0.00"))
  # the scale of an account is its base: a residue of a large account is 0
  expect_identical(lexio:::report_num(c(-1e-6, 0.0015, 0.0315), scale = c(1e6, 0.03, 0.03)),
                   c("0.00", "0.0015", "0.0315"))
  expect_identical(lexio:::report_pct(c(1, 0.000123, -1e-9, NA), 1), c("100.0%", "0.0%", "0.0%", ""))
  # an account of small scale in the report
  io <- example_io()
  D <- stats::setNames(lapply(seq_along(io$accounts), function(i) io$D[i, ]), io$accounts)
  D$LAB <- D$LAB * 0.03 / sum(D$LAB * io$x)
  io2 <- declare_io(B = io$B, x = io$x, f = io$f, D = D, floor = io$floor, ceiling = io$ceiling)
  res <- run_model(io2, read_model(toy_model_path()), verbose = FALSE)
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("| LAB | 0.0300 | 0.0315 |", rep, fixed = TRUE)))
})

test_that("solved levels: tiny violation of the constraints and no level without solution", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  expect_true(all(res$summary$levels$violation < 1e-9))
  expect_true(all(is.na(res$summary$runs$infeasible_level)))
})

test_that("the realized share is NA when the goal equals the base up to rounding", {
  io <- example_io()
  b <- stats::setNames(as.numeric(io$D %*% io$x), io$accounts)
  m <- define_model(list(
    E = list(direction = ">=", target = list(type = "pooled_share", share = 0.05, pool = c("E", "I"))),
    I = list(direction = "<=", target = list(type = "level", value = b[["I"]] * (1 + 1e-12))),
    LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))
  ))
  res <- run_model(io, m, verbose = FALSE)
  gl <- res$summary$goals
  expect_true(all(gl$intended[gl$account == "I"] != 0))
  expect_true(all(is.na(gl$realized[gl$account == "I"])))
  expect_false(anyNA(gl$realized[gl$account == "E"]))
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("^\\| P0[0-9] \\| E \\|", rep)))
  expect_false(any(grepl("^\\| P0[0-9] \\| I \\|", rep)))
})

test_that("the report shows the database without local paths", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  dir <- tempfile()
  write_outputs(res, dir)
  db <- grep("^- Database:", readLines(file.path(dir, "README.md"), encoding = "UTF-8"), value = TRUE)
  expect_match(db, "(`base`)", fixed = TRUE)
  expect_false(grepl(normalizePath(dirname(toy_model_path()), winslash = "/"), db, fixed = TRUE))
})

test_that("k = 1 and k = 2 accounts: levels and orderings", {
  io <- example_io()
  m1 <- define_model(list(LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))))
  r1 <- run_model(io, m1, verbose = FALSE)
  expect_length(r1$runs, 1)
  expect_length(r1$runs[[1]]$levels, 2)
  expect_identical(lexio:::all_levels_table(r1$runs[[1]], lexio:::g_rows(r1$runs[[1]], m1))$notation[1:2],
                   c("xD1", "f'1"))
  m2 <- define_model(list(I = list(direction = "<=", target = "base"),
                          E = list(direction = ">=", target = list(type = "pooled_share", share = 0.05,
                                                                   pool = c("E", "I")))))
  r2 <- run_model(io, m2, verbose = FALSE)
  expect_length(r2$runs, 2)
  expect_identical(r2$runs[[2]]$order, c("E", "I", "ECO"))
  expect_true(all(r2$summary$runs$ok))
  expect_identical(r2$runs[[1]]$g[1:2], unname(build_goals(io, m2)[1:2]))
})

test_that("write_outputs writes the results structure and the report", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  dir <- tempfile()
  write_outputs(res, dir)
  expect_true(all(file.exists(file.path(dir, c("README.md", "orderings.csv", "levels.csv", "level_results.csv",
                                               "account_goals.csv", "x_star_all_runs.csv", "states.csv",
                                               "results.rds", "session.txt", "inputs/model.yml",
                                               "inputs/inputs_sha256.csv")))))
  # every stage of every run: 12 runs x 4 levels, and every row of G in each
  lvs <- utils::read.csv(file.path(dir, "levels.csv"))
  expect_identical(nrow(lvs), 48L)
  expect_identical(names(lvs), c("scenario", "ordering", "label", "level", "goals", "Z", "status", "status_glpk",
                                 "optimal", "violation", "lock_tolerance", "state"))
  expect_equal(lvs$Z[lvs$scenario == "E_shock" & lvs$label == "P03"], res$runs[[3]]$Z)
  lr <- utils::read.csv(file.path(dir, "level_results.csv"))
  expect_identical(nrow(lr), 48L * 6L)
  xa <- utils::read.csv(file.path(dir, "x_star_all_runs.csv"))
  expect_identical(names(xa)[1:4], c("code", "name", "x0", "E_shock_P01"))
  expect_identical(ncol(xa), 3L + 12L)
  expect_equal(xa$I_shock_P06, res$runs[[12]]$x_star)
  run_dir <- file.path(dir, "runs", "E_shock", "P04_I-LAB-E")
  expect_true(all(file.exists(file.path(run_dir, c(paste0("level_", 1:4, ".csv"), "x_star.csv")))))
  lv <- utils::read.csv(file.path(run_dir, "level_4.csv"))
  expect_identical(names(lv), c("row", "block", "g", "Gx", "d_minus", "d_plus", "x"))
  expect_identical(lv$row, c("E", "I", "LAB", "S1", "S2", "S3"))
  xs <- utils::read.csv(file.path(run_dir, "x_star.csv"))
  expect_identical(names(xs), c("code", "name", "x0", "x_star", "delta_x"))
  # all the levels of a run side by side, with the same numbers as level_<l>.csv
  al <- utils::read.csv(file.path(run_dir, "all_levels.csv"))
  expect_identical(names(al)[1:5], c("row", "notation", "name", "block", "g"))
  expect_identical(names(al)[6:9], paste0("level1_", c("Gx", "d_minus", "d_plus", "x")))
  expect_identical(ncol(al), 5L + 4L * 4L)
  expect_identical(al$notation, c("xD1", "xD2", "xD3", "f'1", "f'2", "f'3"))
  expect_equal(al$level4_Gx, lv$Gx, tolerance = 1e-14)
  expect_equal(al$level4_x, lv$x, tolerance = 1e-14)
  expect_true(file.exists(file.path(dir, "results.xlsx")))
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("Scenario: E_shock", rep)))
  expect_true(any(grepl("Distinct states", rep)))
  ord <- utils::read.csv(file.path(dir, "orderings.csv"))
  expect_identical(nrow(ord), 12L)
  expect_true(all(paste0("Z", 1:4) %in% names(ord)))
  expect_error(write_outputs(res, dir), "not empty")
  dir2 <- tempfile()
  write_outputs(res, dir2, format = "br")
  expect_identical(nrow(utils::read.csv2(file.path(dir2, "states.csv"))), nrow(res$summary$states))
})
