# The goal programming example of Miller and Blair (2022, section 13.8; 2009,
# section 10.4): two sectors, five accounts declared as coefficients D, no
# corridor, levels with several goals and, in the structures of the book, ECO
# at the second level (declared with economy: position: free).

mb_path <- function() system.file("examples", "miller_blair", "model.yml", package = "lexio")

mb_io <- function() {
  declare_io(Z = matrix(c(3, 2, 1, 7), 2, byrow = TRUE), x = c(10, 10), f = c(5, 2),
             D = list(OIL = c(0.2, 0.3), COAL = c(0.1, 0.4), SO2 = c(0.5, 1.1), HC = c(0.7, 0.7),
                      EMP = c(0.1, 0.2)))
}

# Value of each level of an ordering at a given x (the penalized deviations).
mb_level_values <- function(io, model, ordering, x) {
  g <- build_goals(io, model)
  gx <- as.numeric(rbind(io$D, io$B) %*% x)
  dp <- pmax(gx - g, 0)
  dm <- pmax(g - gx, 0)
  pr <- lexio:::priority_levels(model, 1, ordering, io$n)
  vapply(pr$levels, function(l) lexio:::penalized_deviation(dp, dm, l), numeric(1))
}

test_that("the example is free and its database matches the declaration by vectors", {
  m <- read_model(mb_path())
  io <- read_io(m$data)
  expect_identical(io$corridor_mode, "free")
  expect_null(io$floor)
  expect_null(io$ceiling)
  v <- mb_io()
  expect_identical(io$B, v$B)
  expect_identical(io$D, v$D)
  expect_identical(build_goals(io, m), c(20, 20, 16, 20, 12, 5, 10))
  expect_identical(vapply(m$orderings, `[[`, character(1), "label"), c("book_1", "book_2"))
  expect_identical(m$orderings[[1]]$levels, list("EMP", "ECO", c("OIL", "COAL"), c("SO2", "HC")))
  expect_identical(m$economy$position, "free")
  # without the explicit declaration, ECO cannot be the second level
  yml <- readLines(mb_path(), encoding = "UTF-8")
  tmp <- file.path(tempfile(), "model.yml")
  dir.create(dirname(tmp))
  writeLines(sub("^  position: free$", "  position: last", yml), tmp)
  expect_error(read_model(tmp), "ECO is fixed at the last level")
})

test_that("after level 2 of the first structure GLPK stands on the book's point; level 3 moves it", {
  r <- run_model(mb_path(), verbose = FALSE)$runs[[1]]
  expect_equal(r$levels[[2]]$x, c(21.25, 49.375), tolerance = 1e-10)
  expect_equal(r$levels[[3]]$x, c(32, 44), tolerance = 1e-10)
})

test_that("all 5! = 120 orderings with ECO at the last level (the default)", {
  m <- read_model(mb_path())
  m_all <- define_model(m$accounts, economy = list(direction = ">=", target = c(5, 10)))
  res <- run_model(mb_io(), m_all, verbose = FALSE)
  expect_length(res$runs, 120)
  expect_true(all(vapply(res$runs, function(r) identical(r$order[6], "ECO"), logical(1))))
  expect_true(all(res$summary$runs$optimal))
  expect_identical(nrow(res$summary$levels), 720L)
  expect_identical(nrow(res$summary$states), 6L)
})

test_that("ordering 1 (eq. 13.17): the lexicographic optimum is (32, 44), not the printed (21.25, 49.375)", {
  res <- run_model(mb_path(), verbose = FALSE)
  r <- res$runs[[1]]
  expect_identical(r$label, "book_1")
  expect_true(r$ok)
  expect_identical(r$lock_tolerance, 0)
  expect_equal(r$x_star, c(32, 44), tolerance = 1e-10)
  expect_equal(r$Z, c(0, 0, 0.8, 81.6), tolerance = 1e-10)
  expect_identical(r$order, c("EMP", "ECO", "OIL+COAL", "SO2+HC"))
  # the printed point meets the first two levels, but not the optimum of level 3
  io <- read_io(read_model(mb_path())$data)
  m <- read_model(mb_path())
  book <- mb_level_values(io, m, "book_1", c(21.25, 49.375))
  expect_equal(book[1:2], c(0, 0), tolerance = 1e-12)
  expect_equal(book[3], 1.875, tolerance = 1e-12)
  expect_gt(book[3], r$Z[3])
  expect_equal(mb_level_values(io, m, "book_1", r$x_star), r$Z, tolerance = 1e-10)
})

test_that("ordering 2 (2022, p. 648) agrees with the book: (10, 10)", {
  r <- run_model(mb_path(), verbose = FALSE)$runs[[2]]
  expect_identical(r$label, "book_2")
  expect_true(r$ok)
  expect_equal(r$x_star, c(10, 10), tolerance = 1e-10)
  expect_equal(r$Z, c(0, 8, 0, 0, 9), tolerance = 1e-10)
})

test_that("one goal at a time gives the same point as ordering 1", {
  io <- mb_io()
  m <- read_model(mb_path())
  r <- run_experiment(io, m, ordering = list("EMP", "ECO", "OIL", "COAL", "SO2", "HC"))
  expect_equal(r$x_star, c(32, 44), tolerance = 1e-10)
  expect_equal(r$Z, c(0, 0, 0, 0.8, 48.4, 33.2), tolerance = 1e-10)
  expect_identical(r$label, "O01")
})

test_that("GLPK and an independent solver (lpSolve) agree on both orderings of the book", {
  testthat::skip_if_not_installed("lpSolve")
  io <- mb_io()
  m <- read_model(mb_path())
  for (o in m$orderings) {
    r <- run_experiment(io, m, ordering = o$label)
    z <- lexico_lpsolve(io, m, o$levels)
    expect_equal(r$Z, z, tolerance = 1e-9, label = o$label)
  }
})

test_that("the outputs have one file per level, with ECO in the folder name when it is not last", {
  res <- run_model(mb_path(), verbose = FALSE)
  dir <- tempfile()
  write_outputs(res, dir)
  run_dir <- file.path(dir, "runs", "main", "book_1_EMP-ECO-OIL+COAL-SO2+HC")
  expect_true(all(file.exists(file.path(run_dir, c(paste0("level_", 1:4, ".csv"), "x_star.csv")))))
  expect_true(file.exists(file.path(dir, "runs", "main", "book_2_SO2-ECO-OIL+COAL-HC-EMP", "level_5.csv")))
  ord <- utils::read.csv(file.path(dir, "orderings.csv"))
  expect_identical(ord$priorities, c("EMP > ECO > OIL+COAL > SO2+HC", "SO2 > ECO > OIL+COAL > HC > EMP"))
  expect_true(is.na(ord$Z5[1]))
  expect_equal(ord$Z5[2], 9, tolerance = 1e-10)
  expect_identical(ord$corridor, c("free", "free"))
  al <- utils::read.csv(file.path(dir, "runs", "main", "book_2_SO2-ECO-OIL+COAL-HC-EMP", "all_levels.csv"),
                        check.names = FALSE)
  expect_identical(names(al)[c(1:5, ncol(al))], c("row", "notation", "name", "block", "g", "level5_x"))
  expect_equal(al$level5_x[al$block == "ECO"], c(10, 10), tolerance = 1e-10)
  # every stage of every run in one table
  lv <- utils::read.csv(file.path(dir, "levels.csv"))
  expect_identical(nrow(lv), 9L)
  expect_identical(lv$goals[1:4], c("EMP", "ECO", "OIL+COAL", "SO2+HC"))
  lr <- utils::read.csv(file.path(dir, "level_results.csv"))
  expect_identical(nrow(lr), 9L * 7L)
  expect_equal(lr$x[lr$label == "book_1" & lr$level == 2 & lr$block == "ECO"], c(21.25, 49.375), tolerance = 1e-10)
})
