# Priorities: "all" (the default), permute with groups, explicit orderings with
# several goals per level, weights, the position of ECO (fixed at the last
# level unless the operator declares economy: position: free) and the errors.

acc3 <- function() {
  stats::setNames(lapply(c(">=", "<=", ">="), function(d) list(direction = d, target = "base")), c("A", "B", "C"))
}

test_that("\"all\" numbers the orderings P01..P06 in lexicographic order, ECO last", {
  m <- define_model(acc3())
  expect_identical(m$economy$position, "last")
  expect_length(m$orderings, 6)
  expect_identical(vapply(m$orderings, `[[`, character(1), "label"), sprintf("P%02d", 1:6))
  expect_identical(vapply(m$orderings, `[[`, numeric(1), "index"), as.double(1:6))
  p <- lex_permutations(3)
  for (i in 1:6) expect_identical(m$orderings[[i]]$levels, c(as.list(c("A", "B", "C")[p[i, ]]), list("ECO")))
  expect_identical(define_model(acc3(), priorities = list(permute = list("A", "B", "C")))$orderings, m$orderings)
})

test_that("permute: g! orderings with ECO last; groups are levels with several goals", {
  acc <- stats::setNames(lapply(1:4, function(i) list(direction = ">=")), c("A", "B", "C", "D"))
  m <- define_model(acc, priorities = list(permute = list(c("A", "B"), "C", "D")))
  expect_length(m$orderings, 6)
  expect_true(all(vapply(m$orderings, function(o) identical(o$levels[[4]], "ECO"), logical(1))))
  expect_identical(m$orderings[[1]]$levels, list(c("A", "B"), "C", "D", "ECO"))
  expect_error(define_model(acc, priorities = list(permute = list(c("A", "B"), "C"))), "missing: D")
  expect_error(define_model(acc, priorities = list(permute = list("A", "B", "C", "D", "ECO"))), "unknown goals")
  # the position of ECO is not a key of priorities
  expect_error(define_model(acc, priorities = list(permute = as.list(LETTERS[1:4]), economy = "free")),
               "economy: position")
})

test_that("only the declared orderings are run; without a declaration, all of them", {
  io <- example_io()
  acc <- list(E = list(direction = ">="), I = list(direction = "<="), LAB = list(direction = ">="))
  expect_length(run_model(io, define_model(acc), verbose = FALSE)$runs, 6)
  one <- run_model(io, define_model(acc, priorities = list(c("I", "E", "LAB"))), verbose = FALSE)
  expect_length(one$runs, 1)
  expect_identical(one$runs[[1]]$order, c("I", "E", "LAB", "ECO"))
  expect_identical(one$runs[[1]]$label, "P03")
})

test_that("ECO is fixed at the last level unless economy: position: free is declared", {
  # written last: accepted; elsewhere: an error that says how to free it
  m <- define_model(acc3(), priorities = list(list("C", "A", "B", "ECO")))
  expect_identical(m$orderings[[1]]$levels, list("C", "A", "B", "ECO"))
  expect_identical(m$orderings[[1]]$label, "P05")
  expect_error(define_model(acc3(), priorities = list(list("C", "ECO", c("A", "B")))),
               "ECO is fixed at the last level.*position: free")
  # declared free: ECO anywhere in explicit orderings ...
  free <- define_model(acc3(), economy = list(position = "free"),
                       priorities = list(first = c("C", "A", "B"), second = list("C", "ECO", c("A", "B"))))
  expect_identical(free$orderings[[1]]$levels, list("C", "A", "B", "ECO"))
  expect_identical(free$orderings[[2]]$levels, list("C", "ECO", c("A", "B")))
  # ... and ECO in the permutations: (k + 1)! orderings with "all", (g + 1)! with permute
  all_free <- define_model(acc3(), economy = list(position = "free"))
  expect_length(all_free$orderings, 24)
  expect_identical(all_free$orderings[[1]]$levels, list("A", "B", "C", "ECO"))
  expect_identical(all_free$orderings[[24]]$levels, list("ECO", "C", "B", "A"))
  acc4 <- stats::setNames(lapply(1:4, function(i) list(direction = ">=")), c("A", "B", "C", "D"))
  pf <- define_model(acc4, economy = list(position = "free"), priorities = list(permute = list(c("A", "B"), c("C", "D"))))
  expect_length(pf$orderings, 6)
  expect_identical(pf$orderings[[6]]$levels, list("ECO", c("C", "D"), c("A", "B")))
  r <- run_experiment(example_io(), define_model(list(E = list(direction = ">="), I = list(direction = "<="),
                                                      LAB = list(direction = ">=")),
                                                 economy = list(position = "free"),
                                                 priorities = list(x = list("ECO", c("E", "I"), "LAB"))),
                      ordering = "x")
  expect_identical(r$order, c("ECO", "E+I", "LAB"))
  expect_identical(r$levels[[2]]$type, "mixed")
  expect_identical(r$economy$position, "free")
  expect_true(r$ok)
  expect_error(define_model(acc3(), economy = list(position = "first")), "position")
})

test_that("explicit orderings: names, several goals per level, labels", {
  m <- define_model(acc3(), priorities = list(first = c("C", "A", "B"), second = list(c("A", "B"), "C"),
                                              list("B", "A", "C")))
  expect_identical(vapply(m$orderings, `[[`, character(1), "label"), c("first", "second", "P03"))
  expect_identical(m$orderings[[1]]$levels, list("C", "A", "B", "ECO"))
  expect_identical(m$orderings[[1]]$index, 5)
  expect_identical(m$orderings[[2]]$levels, list(c("A", "B"), "C", "ECO"))
  expect_identical(m$orderings[[2]]$index, 2)
  expect_identical(m$orderings[[3]]$index, 3)
  un <- define_model(acc3(), priorities = list(list(c("A", "B"), "C")))
  expect_identical(un$orderings[[1]]$label, "O01")
})

test_that("errors for missing, repeated or unknown goals and for ECO sharing a level", {
  expect_error(define_model(acc3(), priorities = list(c("A", "B"))), "missing: C")
  expect_error(define_model(acc3(), priorities = list(c("A", "B", "B", "C"))), "repeated: B")
  expect_error(define_model(acc3(), economy = list(position = "free"),
                            priorities = list(list("A", "ECO", "B", "C", "ECO"))), "repeated: ECO")
  expect_error(define_model(acc3(), priorities = list(c("A", "B", "X"))), "unknown goals")
  expect_error(define_model(acc3(), economy = list(position = "free"),
                            priorities = list(list(c("A", "ECO"), "B", "C"))), "ECO must be alone")
  expect_error(define_model(acc3(), priorities = list(p = c("A", "B", "C"), p = c("C", "B", "A"))), "repeated")
  expect_error(define_model(acc3(), priorities = list(c("A", "B", "C"), c("A", "B", "C"))), "repeated")
  expect_error(define_model(acc3(), priorities = 3), "priorities")
  big <- stats::setNames(lapply(1:7, function(i) list(direction = ">=")), LETTERS[1:7])
  expect_error(define_model(big), "orderings \\(limit 720\\)")
  expect_length(define_model(big, max_orderings = 5040)$orderings, 5040)
  m7 <- define_model(big, priorities = list(LETTERS[7:1]))
  expect_identical(m7$orderings[[1]]$index, factorial(7))
})

test_that("weights: weight 1 is identical to no weight; weights change a shared level", {
  io <- example_io()
  base_acc <- list(E = list(direction = ">=", target = list(type = "pooled_share", share = 0.2, pool = c("E", "I"))),
                   I = list(direction = "<=", target = list(type = "pooled_share", share = -0.2, pool = c("E", "I"))),
                   LAB = list(direction = ">=", target = list(type = "growth", rate = 0.3)))
  pri <- list(shared = list(c("E", "I", "LAB")))
  a <- run_experiment(io, define_model(base_acc, priorities = pri), ordering = "shared")
  w1 <- base_acc
  for (k in names(w1)) w1[[k]]$weight <- 1
  b <- run_experiment(io, define_model(w1, priorities = pri), ordering = "shared")
  expect_identical(a$Z, b$Z)
  expect_identical(a$x_star, b$x_star)
  expect_identical(a$levels[[1]]$obj_idx, b$levels[[1]]$obj_idx)
  w <- base_acc
  w$LAB$weight <- 1000
  c3 <- run_experiment(io, define_model(w, priorities = pri), ordering = "shared")
  # a heavier labour goal leaves labour closer to its goal
  expect_lte(c3$d_minus[3], a$d_minus[3] + 1e-9)
  # the optimum of the shared level is the weighted sum of its deviations
  lev <- c3$levels[[1]]
  expect_equal(c3$Z[1], c3$d_minus[1] + c3$d_plus[2] + 1000 * c3$d_minus[3], tolerance = 1e-9)
  expect_identical(lev$name, "E+I+LAB")
})

test_that("priorities in YAML: all, permute, explicit orderings and the position of ECO", {
  dir <- tempfile()
  dir.create(dir)
  path <- file.path(dir, "model.yml")
  head <- c("accounts:", "  A: {direction: \">=\"}", "  B: {direction: \"<=\"}", "  C: {direction: \">=\"}")
  writeLines(c(head, "priorities: all"), path)
  expect_length(read_model(path)$orderings, 6)
  writeLines(c(head, "priorities: {permute: [[A, B], C]}"), path)
  m <- read_model(path)
  expect_length(m$orderings, 2)
  expect_identical(m$orderings[[1]]$levels, list(c("A", "B"), "C", "ECO"))
  writeLines(c(head, "economy: {position: free}", "priorities: {permute: [[A, B], C]}"), path)
  expect_length(read_model(path)$orderings, 6)
  writeLines(c(head, "priorities:", "  one: [C, A, B]", "  two: [C, ECO, [A, B]]"), path)
  expect_error(read_model(path), "ECO is fixed at the last level")
  writeLines(c(head, "economy: {position: free}", "priorities:", "  one: [C, A, B]", "  two: [C, ECO, [A, B]]"), path)
  m <- read_model(path)
  expect_identical(m$orderings[[2]]$levels, list("C", "ECO", c("A", "B")))
  expect_identical(m$orderings[[1]]$levels, list("C", "A", "B", "ECO"))
})
