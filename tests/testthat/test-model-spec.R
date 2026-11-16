# Model specification: goals, directions, weights, scenarios, the corridor
# switch, the lock and the YAML keys. The priority orderings have their own
# tests (test-priorities.R).

toy_model <- function() read_model(system.file("examples", "toy", "model.yml", package = "lexio"))

test_that("lex_permutations gives the k! orders in lexicographic order", {
  expect_identical(lex_permutations(3), rbind(c(1L, 2L, 3L), c(1L, 3L, 2L), c(2L, 1L, 3L),
                                              c(2L, 3L, 1L), c(3L, 1L, 2L), c(3L, 2L, 1L)))
  for (k in 1:5) {
    p <- lex_permutations(k)
    expect_identical(nrow(p), as.integer(factorial(k)))
    expect_false(anyDuplicated(apply(p, 1, paste, collapse = "-")) > 0)
    keys <- apply(p, 1, function(r) paste(sprintf("%02d", r), collapse = ""))
    expect_identical(keys, sort(keys))
    expect_identical(vapply(seq_len(nrow(p)), function(i) lexio:::lex_rank(p[i, ]), numeric(1)),
                     as.double(seq_len(nrow(p))))
  }
})

test_that("the example model is read with its scenarios and orderings", {
  m <- toy_model()
  expect_s3_class(m, "lexio_model")
  expect_identical(names(m$accounts), c("E", "I", "LAB"))
  expect_identical(names(m$scenarios), c("E_shock", "I_shock"))
  expect_length(m$orderings, 6)
  expect_identical(m$orderings[[4]]$levels, list("I", "LAB", "E", "ECO"))
  expect_identical(m$orderings[[4]]$index, 4)
  expect_identical(m$orderings[[4]]$label, "P04")
  expect_identical(m$lock_tolerance, "auto")
  expect_identical(m$corridor, list(use = TRUE, multiplier = 1))
  expect_true(dir.exists(m$data))
  sc <- m$scenarios$E_shock
  expect_identical(sc$targets$E, list(type = "pooled_share", share = 0.05, pool = c("E", "I")))
  expect_identical(sc$targets$I, list(type = "base"))
  expect_identical(sc$targets$LAB, list(type = "growth", rate = 0.05))
  expect_identical(unname(sc$directions), c(">=", "<=", ">=", ">="))
  expect_true(sc$corridor_use)
  expect_identical(m$accounts$E$weight, 1)
})

test_that("goals, directions, weights and specification errors", {
  acc <- list(A = list(direction = ">=", target = "base"), B = list(direction = "<=", target = "base"))
  m <- define_model(acc)
  expect_identical(names(m$scenarios), "main")
  expect_length(m$orderings, 2)
  expect_error(define_model(list(A = list(direction = ">", target = "base"))), "invalid direction")
  expect_error(define_model(list(A = list(target = "base"))), "direction is missing")
  expect_error(define_model(list(A = list(direction = ">=", target = list(type = "xx")))), "unknown")
  expect_error(define_model(list(A = list(direction = ">=", target = list(type = "growth")))), "rate")
  expect_error(define_model(list(A = list(direction = ">=",
                                          target = list(type = "pooled_share", share = 0.1, pool = "Z")))), "pool")
  for (r in c("ECO", "economy", "corridor")) {
    expect_error(define_model(stats::setNames(list(list(direction = ">=")), r)), "reserved")
  }
  expect_error(define_model(list(A = list(direction = ">=", weight = 0))), "weight")
  expect_error(define_model(list(A = list(direction = ">=", weight = "a"))), "weight")
  expect_identical(define_model(list(A = list(direction = ">=", weight = 2.5)))$accounts$A$weight, 2.5)
  expect_error(define_model(acc, scenarios = list(s1 = list(C = "base"))), "unknown keys")
  sc <- define_model(acc, scenarios = list(s1 = list(directions = list(economy = "="), corridor = list(multiplier = 2)),
                                           s2 = list(corridor = list(use = FALSE))))
  expect_identical(sc$scenarios$s1$directions[["economy"]], "=")
  expect_identical(sc$scenarios$s1$corridor_multiplier, 2)
  expect_true(sc$scenarios$s1$corridor_use)
  expect_false(sc$scenarios$s2$corridor_use)
  expect_error(define_model(acc, corridor = list(use = "yes")), "use must be TRUE or FALSE")
  expect_error(define_model(acc, corridor = list(alpha = 1)), "unknown corridor keys")
  expect_error(define_model(acc, economy = list(direction = ">")), "invalid direction")
})

test_that("lock_tolerance: auto by default, exact, or a small number", {
  acc <- list(A = list(direction = ">=", target = "base"))
  expect_identical(define_model(acc)$lock_tolerance, "auto")
  expect_identical(define_model(acc, lock_tolerance = "exact")$lock_tolerance, 0)
  expect_identical(define_model(acc, lock_tolerance = 0)$lock_tolerance, 0)
  expect_identical(define_model(acc, lock_tolerance = 1e-9)$lock_tolerance, 1e-9)
  expect_error(define_model(acc, lock_tolerance = 1e-3), "lock_tolerance")
  expect_error(define_model(acc, lock_tolerance = "loose"), "lock_tolerance")
  expect_identical(lexio:::lock_tolerances("auto"), c(0, 1e-12, 1e-11, 1e-10, 1e-9))
  expect_identical(lexio:::lock_tolerances(0), 0)
  expect_identical(lexio:::lock_tolerances(1e-9), c(0, 1e-9))
})

test_that("the YAML file accepts only the documented keys", {
  dir <- tempfile()
  dir.create(dir)
  path <- file.path(dir, "model.yml")
  writeLines(c("name: t", "accounts:", "  A: {direction: \">=\", target: {type: base}}", "lock_tolerance: exact",
               "priorities: all"), path)
  m <- read_model(path)
  expect_identical(m$lock_tolerance, 0)
  expect_identical(m$name, "t")
  writeLines(c("accounts:", "  A: {direction: \">=\"}", "permutations: all"), path)
  expect_error(read_model(path), "unknown keys: permutations")
  writeLines(c("name: t"), path)
  expect_error(read_model(path), "accounts is missing")
})
