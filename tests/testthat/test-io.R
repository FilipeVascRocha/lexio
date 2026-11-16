# Declared database: declare_io (Z/A/B, E/D, corridor modes), reading (CSV and
# xlsx), exact writing, validation and the template.

toy_dir <- function() system.file("examples", "toy", "base", package = "lexio")
toy_tables <- c("sectors", "Z", "x", "f", "E", "corridor")

toy_vectors <- function() {
  io <- example_io()
  list(io = io, Z = io$declared$structure_matrix,
       E = lapply(stats::setNames(io$accounts, io$accounts), function(a) io$declared$account_matrix[, a]))
}

test_that("the example database is read and the coefficients are A = Z / x and D = E / x", {
  io <- example_io()
  expect_s3_class(io, "lexio_io")
  expect_identical(io$n, 3L)
  expect_identical(io$accounts, c("E", "I", "LAB"))
  expect_equal(io$D, rbind(c(0.02, 0.05, 0.01), c(0.10, 0.20, 0.05), c(1, 0.5, 2)), tolerance = 1e-15)
  expect_identical(io$floor, c(0.1, 0.2, 0.15))
  expect_identical(io$ceiling, io$floor)
  expect_identical(io$corridor_mode, "two-sided corridor")
  Z <- io$declared$structure_matrix
  expect_identical(io$B, diag(1, 3) - Z / matrix(io$x, 3, 3, byrow = TRUE))
  expect_identical(io$f, c(70, 42, 39))
})

test_that("CSV files with semicolons and the xlsx workbook give the same database", {
  a <- read_io(toy_dir())
  dir <- tempfile()
  dir.create(dir)
  for (t in toy_tables) {
    df <- utils::read.csv(file.path(toy_dir(), paste0(t, ".csv")), check.names = FALSE, stringsAsFactors = FALSE)
    utils::write.csv2(df, file.path(dir, paste0(t, ".csv")), row.names = FALSE)
  }
  b <- read_io(dir)
  x <- read_io(system.file("examples", "toy", "base.xlsx", package = "lexio"))
  for (o in list(b, x)) {
    expect_identical(o$B, a$B)
    expect_identical(o$D, a$D)
    expect_identical(o$floor, a$floor)
    expect_identical(o$ceiling, a$ceiling)
    expect_identical(o$f, a$f)
    expect_identical(o$x, a$x)
  }
})

test_that("rows are matched to sectors by code, in any order", {
  a <- read_io(toy_dir())
  dir <- tempfile()
  dir.create(dir)
  for (t in toy_tables) {
    df <- utils::read.csv(file.path(toy_dir(), paste0(t, ".csv")), check.names = FALSE, stringsAsFactors = FALSE)
    if (t != "sectors") df <- df[c(3, 1, 2), ]
    utils::write.csv(df, file.path(dir, paste0(t, ".csv")), row.names = FALSE)
  }
  b <- read_io(dir)
  expect_identical(b$B, a$B)
  expect_identical(b$D, a$D)
  expect_identical(b$floor, a$floor)
})

test_that("accounts are declared as vectors from the R environment, a data frame or a matrix", {
  v <- toy_vectors()
  io <- v$io
  E_GD <- v$E$E
  E_GC <- v$E$I
  E_LAB <- v$E$LAB
  a <- declare_io(Z = v$Z, x = io$x, f = io$f, E = list(E = E_GD, I = E_GC, LAB = E_LAB), corridor = io$floor)
  expect_identical(a$D, io$D)
  expect_identical(a$B, io$B)
  b <- declare_io(Z = v$Z, x = io$x, f = io$f, E = as.data.frame(v$E), corridor = io$floor)
  expect_identical(b$D, io$D)
  S <- do.call(cbind, v$E)
  expect_identical(declare_io(Z = v$Z, x = io$x, f = io$f, E = S[, 1:2])$D, io$D[1:2, ])
  expect_identical(declare_io(Z = v$Z, x = io$x, f = io$f, E = t(S[, 1:2]))$D, io$D[1:2, ])
  D <- lapply(stats::setNames(io$accounts, io$accounts), function(s) io$D[match(s, io$accounts), ])
  d <- declare_io(B = io$B, x = io$x, f = io$f, D = D, corridor = io$floor)
  expect_identical(d$D, io$D)
  expect_identical(d$B, io$B)
  d2 <- declare_io(A = diag(1, 3) - io$B, x = io$x, f = io$f, D = D)
  expect_equal(d2$B, io$B, tolerance = 1e-15)
  expect_identical(d2$corridor_mode, "free")
  expect_null(d2$floor)
  expect_null(d2$ceiling)
})

test_that("corridor modes: two-sided, floor only, ceiling only, both, NA and free", {
  v <- toy_vectors()
  io <- v$io
  base <- function(...) declare_io(Z = v$Z, x = io$x, f = io$f, E = v$E, ...)
  expect_identical(base()$corridor_mode, "free")
  lo <- base(floor = c(0.1, NA, 0.3))
  expect_identical(lo$corridor_mode, "floor only")
  expect_identical(lo$floor, c(0.1, NA, 0.3))
  expect_null(lo$ceiling)
  hi <- base(ceiling = c(0.2, 0.2, 0.2))
  expect_identical(hi$corridor_mode, "ceiling only")
  expect_null(hi$floor)
  both <- base(floor = c(0.1, 0.1, 0.1), ceiling = c(0.5, NA, 0.5))
  expect_identical(both$corridor_mode, "floor and ceiling")
  two <- base(corridor = c(0.1, 0.2, 0.15))
  expect_identical(two$floor, two$ceiling)
  expect_error(base(corridor = c(0.1, 0.2, 0.15), floor = c(0.1, 0.2, 0.15)), "not both")
  expect_error(base(corridor = c(0.1, Inf, 0.15)), "corridor")
  expect_error(base(floor = c(0.1, 0.2)), "floor")
})

test_that("clear errors in the declaration", {
  v <- toy_vectors()
  io <- v$io
  Z <- v$Z
  E <- v$E
  ok <- function(...) declare_io(Z = Z, x = io$x, f = io$f, E = E, corridor = io$floor, ...)
  expect_s3_class(ok(), "lexio_io")
  expect_error(declare_io(Z = Z[, 1:2], x = io$x, f = io$f, E = E), "square")
  expect_error(declare_io(Z = Z, A = Z, x = io$x, f = io$f, E = E), "exactly one of Z, A or B")
  expect_error(declare_io(x = io$x, f = io$f, E = E), "exactly one of Z, A or B")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f), "exactly one of E")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f, E = E, D = E), "exactly one of E")
  expect_error(declare_io(Z = Z, x = c(100, 0, 60), f = io$f, E = E), "positive")
  expect_error(declare_io(Z = Z, x = c(100, NA, 60), f = io$f, E = E), "non-finite")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f[1:2], E = E), "3 values")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f, E = list(E = E$E, LAB = E$LAB[1:2])), "LAB")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f, E = E$E), "named list")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f, E = unname(E)), "names")
  expect_error(declare_io(Z = Z, x = io$x, f = io$f, E = do.call(cbind, E)), "ambiguous")
})

test_that("write_io keeps the numbers exactly and writes what was declared", {
  # R reads decimal numbers with 16 or 17 significant digits exactly where C
  # long double has extended precision (Windows, Linux, Intel Macs); where it
  # is the same as double (Macs with Apple silicon), the last bit can differ.
  same <- if (.Machine$sizeof.longdouble > 8) expect_identical else {
    function(a, b) expect_equal(a, b, tolerance = 4 * .Machine$double.eps)
  }
  set.seed(1)
  n <- 4
  Z <- matrix(stats::runif(n * n) * 10, n)
  x <- rowSums(Z) + stats::runif(n) * 50 + 20
  E <- list(A = stats::runif(n) * 3, B = stats::runif(n) * 1e6)
  for (cor in list(list(corridor = stats::runif(n)), list(floor = c(stats::runif(n - 1), NA)),
                   list(ceiling = stats::runif(n)), list())) {
    io <- do.call(declare_io, c(list(Z = Z, x = x, f = x - rowSums(Z), E = E), cor))
    dir <- tempfile()
    write_io(io, dir)
    expect_setequal(list.files(dir), paste0(c("sectors", "x", "f", "Z", "E", names(cor)), ".csv"))
    back <- read_io(dir)
    same(back$declared$structure_matrix, io$declared$structure_matrix)
    same(back$x, io$x)
    same(back$B, io$B)
    same(back$D, io$D)
    same(back$floor, io$floor)
    same(back$ceiling, io$ceiling)
    expect_identical(back$corridor_mode, io$corridor_mode)
  }
})

test_that("a database declared by coefficients is written and read exactly", {
  io <- example_io()
  D <- lapply(stats::setNames(io$accounts, io$accounts), function(s) io$D[match(s, io$accounts), ])
  cf <- declare_io(B = io$B, D = D, x = io$x, f = io$f, corridor = io$floor, sectors = io$sectors)
  dir <- tempfile()
  write_io(cf, dir)
  expect_true(all(file.exists(file.path(dir, c("B.csv", "D.csv", "corridor.csv")))))
  expect_false(file.exists(file.path(dir, "Z.csv")))
  back <- read_io(dir)
  expect_identical(back$declared$structure, "B")
  expect_identical(back$declared$accounts, "D")
  expect_identical(back$B, cf$B)
  expect_identical(back$D, cf$D)
  expect_identical(back$floor, cf$floor)
  expect_identical(back$accounts, cf$accounts)
  model <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
  res_a <- run_model(back, model, verbose = FALSE)
  res_b <- run_model(io, model, verbose = FALSE)
  expect_identical(res_a$runs[[3]]$Z, res_b$runs[[3]]$Z)
  file.copy(file.path(dir, "B.csv"), file.path(dir, "A.csv"))
  expect_error(read_io(dir), "exactly one of Z, A or B")
  unlink(file.path(dir, c("A.csv", "B.csv")))
  expect_error(read_io(dir), "exactly one of Z, A or B")
})

test_that("validate_io warns about columns of A, signs and the balance", {
  io <- example_io()
  v <- validate_io(io)
  expect_true(all(c("columns of A", "I - A", "corridor", "balance (I - A) x = f") %in% v$check))
  expect_false(any(v$level == "warning"))
  vv <- toy_vectors()
  Z <- vv$Z
  Z[, 1] <- Z[, 1] * 10
  bad <- declare_io(Z = Z, x = io$x, f = io$f, E = vv$E, corridor = io$floor)
  vb <- bad$validation
  expect_true(any(vb$level == "warning" & vb$check == "columns of A"))
  free <- validate_io(declare_io(Z = vv$Z, x = io$x, f = io$f, E = vv$E))
  expect_match(free$detail[free$check == "corridor"], "free")
})

test_that("a negative corridor is refused", {
  vv <- toy_vectors()
  io <- vv$io
  expect_error(declare_io(Z = vv$Z, x = io$x, f = io$f, E = vv$E, corridor = -io$floor), "proportions >= 0")
  expect_error(declare_io(Z = vv$Z, x = io$x, f = io$f, E = vv$E, floor = c(0.1, -0.01, NA)), "negative in 1 sector")
  expect_silent(declare_io(Z = vv$Z, x = io$x, f = io$f, E = vv$E, ceiling = c(0, NA, 0.2)))
})

test_that("the balance (I - A) x = f is reported whatever the declaration", {
  vv <- toy_vectors()
  io <- vv$io
  D <- stats::setNames(lapply(seq_along(io$accounts), function(i) io$D[i, ]), io$accounts)
  f <- io$f + c(0, 1, 0)
  for (d in list(declare_io(Z = vv$Z, x = io$x, f = f, E = vv$E), declare_io(B = io$B, x = io$x, f = f, D = D),
                 declare_io(A = diag(3) - io$B, x = io$x, f = f, D = D))) {
    v <- d$validation
    expect_match(v$detail[v$check == "balance (I - A) x = f"], "largest |(I - A) x - f| 1 (", fixed = TRUE)
  }
})

test_that("CSV files saved by Excel as CSV UTF-8 (with a byte order mark) are read", {
  src <- system.file("examples", "toy", "base", package = "lexio")
  dir <- tempfile()
  dir.create(dir)
  file.copy(list.files(src, full.names = TRUE), dir)
  with_bom <- function(f, bytes = readBin(f, "raw", file.size(f))) writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), bytes), f)
  for (f in list.files(dir, pattern = "[.]csv$", full.names = TRUE)) with_bom(f)
  a <- read_io(src)
  b <- read_io(dir)
  for (v in c("sectors", "x", "f", "B", "D", "floor", "ceiling")) expect_identical(b[[v]], a[[v]], label = v)
  # the economic goal read from a file with the mark
  goal <- file.path(dir, "goal.csv")
  with_bom(goal, charToRaw(paste0("code,value\n", paste0(a$sectors$code, ",", c(1.5, 2.25, 3), collapse = "\n"), "\n")))
  expect_identical(economy_goal(goal, a), c(1.5, 2.25, 3))
})

test_that("accented names in CSV files with a byte order mark survive a non-UTF-8 locale", {
  src <- system.file("examples", "toy", "base", package = "lexio")
  dir <- tempfile()
  dir.create(dir)
  file.copy(list.files(src, full.names = TRUE), dir)
  s <- file.path(dir, "sectors.csv")
  txt <- readLines(s, encoding = "UTF-8")
  txt[2] <- sub(",[^,]*$", ",\"Indústria\"", txt[2])
  writeBin(charToRaw(enc2utf8(paste0(paste(txt, collapse = "\n"), "\n"))), s)
  plain <- read_io(dir)$sectors
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), readBin(s, "raw", file.size(s))), s)
  old <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  if (!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", "C")))) skip("the C locale is not available")
  bom <- read_io(dir)$sectors
  Sys.setlocale("LC_CTYPE", old)
  expect_identical(bom, plain)
  expect_identical(plain$name[1], "Indústria")
})

test_that("lexio_template writes databases and models that the package reads", {
  for (fmt in c("csv", "xlsx")) {
    dir <- file.path(tempfile(), "model")
    lexio_template(dir, format = fmt)
    m <- read_model(file.path(dir, "model.yml"))
    io <- read_io(m$data)
    expect_identical(io$B, example_io()$B)
    expect_identical(io$floor, example_io()$floor)
    expect_error(lexio_template(dir), "already exists")
  }
})
