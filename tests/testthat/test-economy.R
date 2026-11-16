# The economic block ECO: its keys, and the relative deviations
# (economy: deviation: relative), against the absolute ones (the default).

free_toy <- function() {
  io <- example_io()
  declare_io(Z = io$declared$structure_matrix, x = io$x, f = io$f, E = as.data.frame(io$declared$account_matrix),
             sectors = io$sectors)
}

# the incumbent energy must fall 20%: the economy has to give up some final demand
energy_cut <- function(deviation) {
  define_model(list(I = list(direction = "<=", target = list(type = "growth", rate = -0.2))),
               economy = list(deviation = deviation))
}

test_that("economy keys: defaults, validation and the YAML", {
  m <- define_model(list(A = list(direction = ">=")))
  expect_identical(m$economy, list(direction = ">=", target = "final_demand", position = "last",
                                   deviation = "absolute"))
  expect_error(define_model(list(A = list(direction = ">=")), economy = list(deviation = "percent")), "deviation")
  expect_error(define_model(list(A = list(direction = ">=")), economy = list(weights = 1)), "unknown keys")
  path <- tempfile(fileext = ".yml")
  writeLines(c("accounts:", "  A: {direction: \">=\"}", "economy:", "  deviation: relative"), path)
  expect_identical(read_model(path)$economy$deviation, "relative")
  expect_output(print(read_model(path)), "relative deviations")
})

test_that("absolute deviations (the default): ECO weights 1", {
  io <- example_io()
  m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
  r <- run_experiment(io, m, "E_shock", ordering = 2)
  expect_identical(r$levels[[4]]$terms[[1]]$weight, 1)
  expect_identical(r$economy$deviation, "absolute")
  m$economy$deviation <- NULL      # an object without the key (older) behaves the same
  expect_identical(run_experiment(io, m, "E_shock", ordering = 2)$Z, r$Z)
})

test_that("relative deviations weigh each sector's deviation by 1 / |g_h|", {
  io <- free_toy()
  a <- run_experiment(io, energy_cut("absolute"), ordering = 1)
  r <- run_experiment(io, energy_cut("relative"), ordering = 1)
  eco <- 2:4
  expect_equal(r$levels[[2]]$terms[[1]]$weight, 1 / abs(r$g[eco]))
  expect_identical(a$Z[1], r$Z[1])
  # the optimum of ECO is the sum of the proportional shortfalls
  expect_equal(r$Z[2], sum(r$d_minus[eco] / abs(r$g[eco])), tolerance = 1e-9)
  expect_equal(a$Z[2], sum(a$d_minus[eco]), tolerance = 1e-9)
  # absolute: the smallest loss in currency (industry, 20.45 = 48.7% of its demand);
  # relative: the smallest loss in proportion (agriculture, 32.14 = 45.9%)
  expect_equal(a$d_minus[eco], c(0, 20.4535, 0), tolerance = 1e-5)
  expect_equal(r$d_minus[eco], c(32.1374, 0, 0), tolerance = 1e-5)
  expect_lt(sum(a$d_minus[eco]), sum(r$d_minus[eco]))
  expect_lt(sum(r$d_minus[eco] / r$g[eco]), sum(a$d_minus[eco] / a$g[eco]))
  expect_true(all(r$checks$ok_rel))
  # the same with ECO penalizing both deviations
  m2 <- energy_cut("relative")
  m2 <- define_model(m2$accounts, economy = list(direction = "=", deviation = "relative"))
  r2 <- run_experiment(io, m2, ordering = 1)
  expect_equal(r2$Z[2], sum((r2$d_minus[eco] + r2$d_plus[eco]) / abs(r2$g[eco])), tolerance = 1e-9)
})

test_that("relative deviations need a nonzero economic goal in every sector", {
  io <- free_toy()
  m <- define_model(list(I = list(direction = "<=")), economy = list(target = c(70, 0, 39), deviation = "relative"))
  expect_error(run_experiment(io, m, ordering = 1), "nonzero economic goal.*sector\\(s\\) 2")
})

test_that("the report and the summary say which deviations ECO uses", {
  res <- run_model(free_toy(), energy_cut("relative"), verbose = FALSE)
  dir <- tempfile()
  write_outputs(res, dir)
  rep <- readLines(file.path(dir, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl("relative deviations", rep)))
  expect_true(any(grepl("fixed at the last level", rep)))
})
