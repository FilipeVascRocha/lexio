# The Excel workbook of the results (write_excel), read back with readxl.

toy_model_path <- function() system.file("examples", "toy", "model.yml", package = "lexio")
read_sheet <- function(file, sheet) as.data.frame(readxl::read_xlsx(file, sheet = sheet))

test_that("the workbook has the summary sheets, three sheets per scenario and one per run", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  file <- write_excel(res, tempfile(fileext = ".xlsx"))
  sheets <- readxl::excel_sheets(file)
  scen <- c("E_shock", "I_shock")
  expect_identical(sheets[1:5], c("about", "runs", "levels", "goals", "states"))
  per_scenario <- c("final_", "Gx_", "x_")
  expect_identical(sheets[6:11], c(paste0(per_scenario, scen[1]), paste0(per_scenario, scen[2])))
  expect_identical(sheets[12:23], paste0(rep(scen, each = 6), "_P0", 1:6))
  expect_identical(nrow(read_sheet(file, "runs")), 12L)
  expect_identical(nrow(read_sheet(file, "levels")), 48L)
  expect_identical(nrow(read_sheet(file, "goals")), 36L)
  expect_error(write_excel(res, file), "exists")
  expect_silent(write_excel(res, file, overwrite = TRUE))
  # without the sheets of the runs
  small <- write_excel(res, tempfile(fileext = ".xlsx"), run_sheets = FALSE)
  expect_identical(readxl::excel_sheets(small), sheets[1:11])
})

test_that("the sheets carry the numbers of the runs", {
  res <- run_model(toy_model_path(), verbose = FALSE)
  file <- write_excel(res, tempfile(fileext = ".xlsx"))
  r <- res$runs[[9]]
  expect_identical(c(r$scenario, r$label), c("I_shock", "P03"))
  # one run: every row of G at every level, side by side
  one <- read_sheet(file, "I_shock_P03")
  expect_identical(names(one)[1:5], c("row", "notation", "name", "block", "g"))
  expect_identical(one$row, c("E", "I", "LAB", "S1", "S2", "S3"))
  expect_identical(one$notation, c("xD1", "xD2", "xD3", "f'1", "f'2", "f'3"))
  expect_equal(one$g, r$g, tolerance = 1e-14)
  for (lev in 1:4) {
    L <- r$levels[[lev]]
    expect_equal(one[[sprintf("level%d_Gx", lev)]], as.numeric(L$gx), tolerance = 1e-14)
    expect_equal(one[[sprintf("level%d_d_minus", lev)]], L$d_minus, tolerance = 1e-14)
    expect_equal(one[[sprintf("level%d_d_plus", lev)]], L$d_plus, tolerance = 1e-14)
    expect_equal(one[[sprintf("level%d_x", lev)]], c(NA, NA, NA, L$x), tolerance = 1e-14)
  }
  # the last level of every ordering, side by side
  fin <- read_sheet(file, "final_I_shock")
  expect_identical(ncol(fin), 5L + 6L * 4L)
  expect_equal(fin$P03_Gx, as.numeric(r$gx), tolerance = 1e-14)
  expect_equal(fin$P03_x, c(NA, NA, NA, r$x_star), tolerance = 1e-14)
  gx <- read_sheet(file, "Gx_I_shock")
  expect_equal(gx$P03_Gx_minus_g, as.numeric(r$gx) - r$g, tolerance = 1e-14)
  xs <- read_sheet(file, "x_I_shock")
  expect_identical(names(xs)[1:3], c("row", "name", "x0"))
  expect_equal(xs$P03_x, r$x_star, tolerance = 1e-14)
  expect_equal(xs$P03_delta_x, r$x_star - r$baseline$x, tolerance = 1e-14)
  about <- read_sheet(file, "about")
  expect_true(any(grepl("P03: I > E > LAB > ECO", about$content, fixed = TRUE)))
})

test_that("runs with a different number of levels, and the ECO not last (Miller and Blair)", {
  res <- run_model(system.file("examples", "miller_blair", "model.yml", package = "lexio"), verbose = FALSE)
  file <- write_excel(res, tempfile(fileext = ".xlsx"))
  expect_identical(readxl::excel_sheets(file)[6:10], c("final_main", "Gx_main", "x_main", "main_book_1", "main_book_2"))
  b1 <- read_sheet(file, "main_book_1")
  b2 <- read_sheet(file, "main_book_2")
  expect_identical(ncol(b1), 5L + 4L * 4L)
  expect_identical(ncol(b2), 5L + 5L * 4L)
  expect_equal(b1$level4_x[b1$block == "ECO"], c(32, 44), tolerance = 1e-9)
  expect_equal(b2$level5_x[b2$block == "ECO"], c(10, 10), tolerance = 1e-9)
  fin <- read_sheet(file, "final_main")
  expect_equal(fin$book_1_x[fin$block == "ECO"], c(32, 44), tolerance = 1e-9)
})

test_that("sheet names are valid and unique for Excel", {
  nm <- lexio:::excel_sheet_names(c("a/b", "x[1]", strrep("s", 40), strrep("s", 35), "About", "about"))
  expect_identical(nm[1:2], c("a_b", "x_1_"))
  expect_true(all(nchar(nm) <= 31))
  expect_false(anyDuplicated(tolower(nm)) > 0)
  expect_identical(nm[4], paste0(strrep("s", 29), "~2"))
  expect_identical(nm[6], "about~2")
})
