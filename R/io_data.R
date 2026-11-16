#' Declare the database
#'
#' Builds the database used by the model from objects the user already has:
#' the technical structure, gross output, final demand, the satellite
#' accounts and, optionally, a corridor. The package never parses free-form
#' spreadsheets and never searches a database for accounts or corridors: the
#' user states what each object is. The vectors may be objects already in the
#' R session; pass them by name.
#'
#' Notation (Rocha, 2026, section 4.2): `Z` intermediate consumption, `x` gross
#' output (VBP), `f` final demand, `A = Z x^-1` technical coefficients,
#' `B = I - A`, `E_j` level of a satellite account in sector j (toe, jobs,
#' ...), `D = E x^-1` direct impact coefficients (one row per account),
#' `alpha_h` corridor of sector h.
#'
#' * **Technical structure**: exactly one of `Z` (flows, then `A = Z / x` by
#'   column), `A` or `B`.
#' * **Satellite accounts**: exactly one of `E` (levels, then `D = E / x`) or
#'   `D` (coefficients). Each can be a named list of vectors (one per
#'   account), a data frame with one column
#'   per account, or a matrix (sectors x accounts for `E`; accounts x sectors
#'   for `D`, as in the notation above). The names are the account names.
#' * **Corridor** (optional), a vector of proportions `alpha_h` (one per
#'   sector) that bounds the deviations of the economic goals:
#'   `corridor = alpha` bounds both sides, `d_h^- <= alpha_h |g_h|` and
#'   `d_h^+ <= alpha_h |g_h|`; `floor = alpha` bounds only `d^-`
#'   (`G_h x >= g_h - alpha_h |g_h|`); `ceiling = alpha` bounds only `d^+`
#'   (`G_h x <= g_h + alpha_h |g_h|`). `floor` and `ceiling` can be given
#'   together, with different values. `NA` in a sector means no bound in that
#'   sector. With no corridor, the model is free (no bound on the economic
#'   deviations).
#'
#' @param Z,A,B Technical structure (n x n): give exactly one.
#' @param x Gross output (n). Must be positive.
#' @param f Final demand (n): the default economic goals.
#' @param E,D Satellite accounts: give exactly one (see above).
#' @param corridor,floor,ceiling Corridor (n, proportions `alpha_h`): give
#'   `corridor`, or `floor` and/or `ceiling`, or none (free).
#' @param sectors Data frame with columns `code` and `name` (optional).
#'   Without it, codes come from the names of `x`, the column names of `Z`,
#'   or become `S01`, `S02`, ...
#'
#' @return Object of class `lexio_io`.
#' @seealso [read_io()] to read the same database from a folder of CSV files
#'   or an `.xlsx` workbook, [validate_io()], [write_io()].
#' @examples
#' Z <- matrix(c(3, 1, 2, 7), 2)          # Miller and Blair (2022), Example 13.7
#' x <- c(10, 10)
#' io <- declare_io(Z = Z, x = x, f = x - rowSums(Z),
#'                  D = list(OIL = c(0.2, 0.3), EMP = c(0.1, 0.2)))
#' io
#' @export
declare_io <- function(Z = NULL, x, f, E = NULL, D = NULL, A = NULL, B = NULL,
                       corridor = NULL, floor = NULL, ceiling = NULL, sectors = NULL) {
  given <- c(Z = !is.null(Z), A = !is.null(A), B = !is.null(B))
  if (sum(given) != 1) stop("give exactly one of Z, A or B (the technical structure)", call. = FALSE)
  structure_type <- names(given)[given]
  M <- as_numeric_matrix(switch(structure_type, Z = Z, A = A, B = B), structure_type)
  n <- nrow(M)
  if (ncol(M) != n) stop(structure_type, " must be square (", n, " x ", ncol(M), ")", call. = FALSE)
  sectors <- resolve_sectors(sectors, n, x, if (structure_type == "Z") M else NULL)
  x <- as_numeric_vector(x, "x", n)
  f <- as_numeric_vector(f, "f", n)
  if (is.null(E) == is.null(D)) stop("give exactly one of E (account levels) or D (account coefficients)",
                                     call. = FALSE)
  account_type <- if (!is.null(E)) "E" else "D"
  S <- as_account_matrix(if (account_type == "E") E else D, account_type, n, sectors$code)
  accounts <- colnames(S)
  check_finite(list(x = x, f = f))
  check_finite(stats::setNames(list(M), structure_type))
  check_finite(stats::setNames(list(S), account_type))
  if (any(x <= 0)) {
    stop("x must be positive in every sector (zero or negative in: ", paste(sectors$code[x <= 0], collapse = ", "),
         ")", call. = FALSE)
  }
  k <- ncol(S)
  # element-wise division by x: D[j, h] = E[h, j] / x[h]
  if (account_type == "E") {
    Dm <- t(S) / matrix(x, nrow = k, ncol = n, byrow = TRUE)
  } else {
    Dm <- t(S)
  }
  Bm <- switch(structure_type,
    Z = diag(1, n) - M / matrix(x, nrow = n, ncol = n, byrow = TRUE),
    A = diag(1, n) - M,
    B = M
  )
  dimnames(Dm) <- NULL
  dimnames(Bm) <- NULL
  cor <- resolve_corridor(corridor, floor, ceiling, n)
  dimnames(M) <- NULL
  dimnames(S) <- list(NULL, accounts)
  new_io(
    sectors = sectors, accounts = accounts, x = x, f = f, B = Bm, D = Dm,
    floor = cor$floor, ceiling = cor$ceiling, corridor_mode = cor$mode,
    declared = list(structure = structure_type, structure_matrix = M, accounts = account_type, account_matrix = S,
                    corridor = cor$declared)
  )
}

#' Read a declared database
#'
#' Reads the database from a folder of CSV files or from an `.xlsx` workbook
#' with sheets of the same names (see [lexio_template()]):
#'
#' | file / sheet | content |
#' |---|---|
#' | `sectors` | columns `code` and `name`: the sectors and their order |
#' | `Z`, `A` or `B` (one) | column `code` + one column per sector (codes) |
#' | `x` | columns `code` and `value`: gross output |
#' | `f` | columns `code` and `value`: final demand |
#' | `E` or `D` (one) | column `code` + one column per satellite account (levels or coefficients) |
#' | `corridor`, or `floor` and/or `ceiling` (optional) | columns `code` and `alpha` (proportions; empty or `NA` = no bound) |
#'
#' CSV files may use `,` as separator and `.` as decimal mark, or `;` and
#' `,`; the format is detected from the first line of each file. Rows are
#' matched to sectors by code, in any order. Without a corridor file, the
#' model is free.
#'
#' @param path Folder with the CSV files, or an `.xlsx` file.
#' @return Object of class `lexio_io`.
#' @export
read_io <- function(path) {
  if (dir.exists(path)) {
    avail <- sub("\\.csv$", "", list.files(path, pattern = "\\.csv$"))
    reader <- function(t) read_io_csv(path, t)
  } else if (file.exists(path) && grepl("\\.xlsx$", path, ignore.case = TRUE)) {
    avail <- readxl::excel_sheets(path)
    reader <- function(t) as.data.frame(readxl::read_excel(path, sheet = t), stringsAsFactors = FALSE)
  } else {
    stop("database not found: ", path, " (give a folder of CSV files or an .xlsx file)", call. = FALSE)
  }
  structure_type <- intersect(c("Z", "A", "B"), avail)
  account_type <- intersect(c("E", "D"), avail)
  if (length(structure_type) != 1) {
    stop(path, ": the database needs exactly one of Z, A or B (found: ",
         if (length(structure_type)) paste(structure_type, collapse = ", ") else "none", ")", call. = FALSE)
  }
  if (length(account_type) != 1) {
    stop(path, ": the database needs exactly one of E (account levels) or D (account coefficients) (found: ",
         if (length(account_type)) paste(account_type, collapse = ", ") else "none", ")", call. = FALSE)
  }
  miss <- setdiff(c("sectors", "x", "f"), avail)
  if (length(miss)) stop(path, ": missing ", paste(miss, collapse = ", "), call. = FALSE)
  corridor_files <- intersect(c("corridor", "floor", "ceiling"), avail)
  needed <- c("sectors", structure_type, "x", "f", account_type, corridor_files)
  tab <- lapply(stats::setNames(needed, needed), reader)
  sectors <- tab$sectors
  if (!all(c("code", "name") %in% names(sectors))) stop("sectors needs the columns code and name", call. = FALSE)
  code <- as.character(sectors$code)
  pick <- function(df, what) {
    if (!"code" %in% names(df)) stop(what, " needs a column named code", call. = FALSE)
    idx <- match(code, as.character(df$code))
    if (anyNA(idx) || nrow(df) != length(code)) {
      stop(what, ": the codes do not match sectors (missing: ", paste(code[is.na(idx)], collapse = ", "), ")",
           call. = FALSE)
    }
    df[idx, setdiff(names(df), "code"), drop = FALSE]
  }
  Mdf <- pick(tab[[structure_type]], structure_type)
  miss <- setdiff(code, names(Mdf))
  if (length(miss)) stop(structure_type, ": missing columns for sectors ", paste(miss, collapse = ", "), call. = FALSE)
  M <- as.matrix(Mdf[, code])
  xv <- pick(tab$x, "x")
  fv <- pick(tab$f, "f")
  if (!"value" %in% names(xv) || !"value" %in% names(fv)) stop("x and f need a column named value", call. = FALSE)
  S <- as.matrix(pick(tab[[account_type]], account_type))
  alpha_col <- function(t) {
    df <- pick(tab[[t]], t)
    if (!"alpha" %in% names(df)) stop(t, " needs a column named alpha", call. = FALSE)
    suppressWarnings(as.numeric(df$alpha))
  }
  args <- list(x = xv$value, f = fv$value, sectors = sectors[, c("code", "name")])
  args[[structure_type]] <- M
  # one column per account, one row per sector, for both E and D (unambiguous)
  args[[account_type]] <- as.data.frame(S, check.names = FALSE, stringsAsFactors = FALSE)
  for (t in corridor_files) args[[t]] <- alpha_col(t)
  io <- do.call(declare_io, args)
  io$source <- normalizePath(path, winslash = "/", mustWork = FALSE)
  io
}

#' Write a declared database as CSV files
#'
#' Writes the database in the format read by [read_io()], with the shortest
#' decimal representation that preserves each number exactly (up to 17
#' significant digits). The objects are written as they were declared: `Z`,
#' `A` or `B`; `E` or `D`; and the corridor files, if any.
#'
#' Reading the files back gives the same numbers, bit for bit, where R reads
#' decimal numbers with extended precision (Windows, Linux and Intel Macs). On
#' Macs with Apple silicon, R itself may read a number written with 16 or 17
#' significant digits with a difference in the last bit (about 1e-16,
#' relative); numbers with up to 15 significant digits are read exactly
#' everywhere.
#'
#' @param io Object of class `lexio_io`.
#' @param dir Destination folder (created if needed).
#' @return `dir`, invisibly.
#' @export
write_io <- function(io, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  code <- io$sectors$code
  w <- function(df, name) {
    utils::write.csv(df, file.path(dir, paste0(name, ".csv")), row.names = FALSE, na = "",
                     quote = which(names(df) %in% c("code", "name")))
  }
  by_sector <- function(cols, values_of) {
    df <- data.frame(code = code, stringsAsFactors = FALSE)
    for (j in seq_along(cols)) df[[cols[j]]] <- exact_decimal(values_of(j))
    df
  }
  dec <- io$declared
  w(io$sectors, "sectors")
  w(data.frame(code = code, value = exact_decimal(io$x)), "x")
  w(data.frame(code = code, value = exact_decimal(io$f)), "f")
  w(by_sector(code, function(j) dec$structure_matrix[, j]), dec$structure)
  if (dec$accounts == "E") {
    w(by_sector(io$accounts, function(s) dec$account_matrix[, s]), "E")
  } else {
    w(by_sector(io$accounts, function(s) io$D[s, ]), "D")
  }
  for (side in names(dec$corridor)) {
    w(data.frame(code = code, alpha = exact_decimal(dec$corridor[[side]]), stringsAsFactors = FALSE), side)
  }
  invisible(dir)
}

#' Validate a declared database
#'
#' Checks the database and returns a report. Problems that make the model
#' impossible (inconsistent dimensions, `x <= 0`, missing values) already stop
#' [declare_io()]; this report holds the warnings and information:
#'
#' * column sums of `A` (should be below 1) and invertibility of `I - A`;
#' * signs of `A` and of the account coefficients `D`;
#' * the corridor mode (free, two-sided, floor, ceiling) and its range;
#' * the balance `(I - A) x` against `f`, whatever the declaration (`Z`, `A`
#'   or `B`): by default `f` is the goal of the economic block, so a
#'   difference means that the base output `x` does not meet it exactly.
#'
#' @param io Object of class `lexio_io`.
#' @return Data frame with `check`, `level` (`"ok"`, `"warning"` or `"info"`)
#'   and `detail`.
#' @export
validate_io <- function(io) {
  out <- list()
  add <- function(check, level, detail) {
    out[[length(out) + 1]] <<- data.frame(check = check, level = level, detail = detail, stringsAsFactors = FALSE)
  }
  n <- length(io$x)
  add("dimensions", "info", sprintf("%d sectors, %d satellite account(s) (%s)", n, length(io$accounts),
                                    paste(io$accounts, collapse = ", ")))
  A <- diag(1, n) - io$B
  colsum <- colSums(A)
  if (any(colsum >= 1)) {
    add("columns of A", "warning", paste0("sum >= 1 in ", sum(colsum >= 1), " sector(s): ",
                                          paste(io$sectors$code[colsum >= 1], collapse = ", ")))
  } else {
    add("columns of A", "ok", sprintf("largest sum %.4g", max(colsum)))
  }
  rc <- tryCatch(rcond(io$B), error = function(e) 0)
  if (rc < 1e-12) add("I - A", "warning", sprintf("nearly singular (rcond = %.3g)", rc))
  else add("I - A", "ok", sprintf("invertible (rcond = %.3g)", rc))
  if (any(A < 0)) add("sign of A", "warning", sprintf("%d negative coefficient(s)", sum(A < 0)))
  if (any(io$D < 0)) add("sign of D", "warning", sprintf("%d negative account coefficient(s)", sum(io$D < 0)))
  sides <- Filter(Negate(is.null), list(floor = io$floor, ceiling = io$ceiling))
  if (!length(sides)) {
    add("corridor", "info", "free: no corridor declared")
  } else {
    vals <- unlist(sides)
    vals <- vals[!is.na(vals)]
    n_na <- sum(vapply(sides, function(s) sum(is.na(s)), numeric(1)))
    detail <- sprintf("%s; alpha between %.4g and %.4g%s", io$corridor_mode,
                      if (length(vals)) min(vals) else NA, if (length(vals)) max(vals) else NA,
                      if (n_na) sprintf("; %d sector side(s) without bound (NA)", n_na) else "")
    add("corridor", "ok", detail)
    if (any(io$f < 0)) add("final demand", "info", sprintf("f < 0 in %d sector(s): the corridor uses |f|", sum(io$f < 0)))
  }
  gap <- as.numeric(io$B %*% io$x) - io$f
  add("balance (I - A) x = f", "info", sprintf("largest |(I - A) x - f| %.4g (relative to x %.3g); sum %.4g",
                                               max(abs(gap)), max(abs(gap) / io$x), sum(gap)))
  do.call(rbind, out)
}

#' Example database
#'
#' A toy database with 3 sectors and 3 satellite accounts (`E`, entrant
#' energy; `I`, incumbent energy; `LAB`, labour), consistent
#' (`f = (I - A) x`), with a two-sided corridor. Used in the examples, in the
#' tests and in the model written by [lexio_template()].
#'
#' @return Object of class `lexio_io`.
#' @examples
#' example_io()
#' @export
example_io <- function() {
  read_io(system.file("examples", "toy", "base", package = "lexio"))
}

#' Write a template database and model
#'
#' Copies to `dir` the 3-sector example database, in the format read by
#' [read_io()], and a commented `model.yml`. Replace the values with those of
#' your own database: the number of sectors and of satellite accounts comes
#' from the files.
#'
#' @param dir Destination folder (must not exist).
#' @param format `"csv"` (a folder of CSV files) or `"xlsx"` (one workbook
#'   with the sheets `sectors`, `Z`, `x`, `f`, `E` and `corridor`).
#' @return `dir`, invisibly.
#' @export
lexio_template <- function(dir, format = c("csv", "xlsx")) {
  format <- match.arg(format)
  if (file.exists(dir)) stop("the folder already exists: ", dir, call. = FALSE)
  src <- system.file("examples", "toy", package = "lexio")
  dir.create(dir, recursive = TRUE)
  file.copy(file.path(src, "model.yml"), dir)
  if (format == "csv") {
    dir.create(file.path(dir, "base"))
    file.copy(list.files(file.path(src, "base"), full.names = TRUE), file.path(dir, "base"))
  } else {
    file.copy(file.path(src, "base.xlsx"), dir)
    yml <- readLines(file.path(dir, "model.yml"), encoding = "UTF-8")
    writeLines(sub("^data: base$", "data: base.xlsx", yml), file.path(dir, "model.yml"), useBytes = TRUE)
  }
  invisible(dir)
}

#' @export
print.lexio_io <- function(x, ...) {
  cat("<lexio_io>", length(x$x), "sectors,", length(x$accounts), "satellite account(s):",
      paste(x$accounts, collapse = ", "), "| declared as", x$declared$structure, "+", x$declared$accounts,
      "| corridor:", x$corridor_mode, "\n")
  base <- as.numeric(x$D %*% x$x)
  cat(paste0("  base ", x$accounts, " = D x = ", format(base, big.mark = ",", nsmall = 2), "\n"), sep = "")
  v <- x$validation
  alerts <- v[v$level == "warning", ]
  if (nrow(alerts)) cat(paste0("  warning: ", alerts$check, ": ", alerts$detail, "\n"), sep = "")
  invisible(x)
}

# ------------------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------------------
new_io <- function(sectors, accounts, x, f, B, D, floor, ceiling, corridor_mode, declared) {
  io <- structure(list(
    sectors = sectors, accounts = accounts, n = length(x), k = length(accounts),
    x = x, f = f, B = B, D = D, floor = floor, ceiling = ceiling, corridor_mode = corridor_mode,
    declared = declared
  ), class = "lexio_io")
  io$validation <- validate_io(io)
  io
}

# Corridor sides from corridor / floor / ceiling. Each side is NULL (no bound)
# or a vector of n proportions, NA = no bound in that sector.
resolve_corridor <- function(corridor, floor, ceiling, n) {
  if (!is.null(corridor) && (!is.null(floor) || !is.null(ceiling))) {
    stop("give either corridor (both sides) or floor and/or ceiling, not both", call. = FALSE)
  }
  vec <- function(v, what) {
    if (is.null(v)) return(NULL)
    if (is.data.frame(v)) v <- if ("alpha" %in% names(v)) v$alpha else v[[ncol(v)]]
    v <- suppressWarnings(as.numeric(v))
    if (length(v) != n) stop(what, " must have ", n, " values; it has ", length(v), call. = FALSE)
    if (any(is.nan(v) | is.infinite(v))) stop(what, " has non-finite values (use NA for no bound)", call. = FALSE)
    if (any(v < 0, na.rm = TRUE)) {
      stop(what, " must be proportions >= 0; negative in ", sum(v < 0, na.rm = TRUE), " sector(s)", call. = FALSE)
    }
    v
  }
  if (!is.null(corridor)) {
    a <- vec(corridor, "corridor")
    return(list(floor = a, ceiling = a, mode = "two-sided corridor", declared = list(corridor = a)))
  }
  lo <- vec(floor, "floor")
  hi <- vec(ceiling, "ceiling")
  mode <- if (is.null(lo) && is.null(hi)) "free" else if (is.null(hi)) "floor only" else if (is.null(lo)) {
    "ceiling only"
  } else {
    "floor and ceiling"
  }
  list(floor = lo, ceiling = hi, mode = mode, declared = Filter(Negate(is.null), list(floor = lo, ceiling = hi)))
}

# Satellite accounts as an n x k matrix (sectors x accounts), from a named
# list of vectors, a data frame (one column per account, optional `code`) or
# a matrix (E: sectors x accounts; D: accounts x sectors).
as_account_matrix <- function(v, what, n, codes) {
  if (is.data.frame(v)) {
    if ("code" %in% names(v)) {
      idx <- match(codes, as.character(v$code))
      if (anyNA(idx)) stop(what, ": the codes do not match the sectors", call. = FALSE)
      v <- v[idx, setdiff(names(v), "code"), drop = FALSE]
    }
    if (nrow(v) != n) stop(what, " must have one row per sector (", n, "); it has ", nrow(v), call. = FALSE)
    S <- as.matrix(v)
  } else if (is.list(v)) {
    if (is.null(names(v)) || any(!nzchar(names(v)))) stop(what, ": the list of accounts needs names", call. = FALSE)
    S <- vapply(names(v), function(a) {
      vv <- as.numeric(v[[a]])
      if (length(vv) != n) stop(what, ": account ", a, " must have ", n, " values; it has ", length(vv), call. = FALSE)
      vv
    }, numeric(n))
    S <- matrix(S, nrow = n, dimnames = list(NULL, names(v)))
  } else if (is.matrix(v)) {
    if (nrow(v) == n && ncol(v) == n) {
      stop(what, " is a square matrix and its orientation is ambiguous; pass a named list of vectors", call. = FALSE)
    }
    if (what == "D") {
      if (ncol(v) == n) S <- t(v) else if (nrow(v) == n) S <- v else {
        stop("D must have one column per sector (", n, ")", call. = FALSE)
      }
    } else {
      if (nrow(v) == n) S <- v else if (ncol(v) == n) S <- t(v) else {
        stop("E must have one row per sector (", n, ")", call. = FALSE)
      }
    }
  } else if (is.numeric(v)) {
    stop(what, ": give the accounts as a named list of vectors, e.g. ", what, " = list(LAB = my_vector)",
         call. = FALSE)
  } else {
    stop(what, " must be a named list of vectors, a data frame or a matrix", call. = FALSE)
  }
  if (!is.numeric(S)) storage.mode(S) <- "double"
  acc <- colnames(S)
  if (is.null(acc) || any(!nzchar(acc)) || anyDuplicated(acc)) {
    stop(what, ": the satellite accounts need unique names", call. = FALSE)
  }
  S
}

as_numeric_matrix <- function(m, what) {
  if (is.data.frame(m)) m <- as.matrix(m)
  if (!is.matrix(m)) stop(what, " must be a matrix", call. = FALSE)
  if (!is.numeric(m)) storage.mode(m) <- "double"
  m
}

as_numeric_vector <- function(v, what, n) {
  if (is.data.frame(v)) v <- v[[ncol(v)]]
  v <- as.numeric(v)
  if (length(v) != n) stop(what, " must have ", n, " values; it has ", length(v), call. = FALSE)
  v
}

check_finite <- function(objs) {
  for (nm in names(objs)) {
    if (any(!is.finite(objs[[nm]]))) stop(nm, " has missing or non-finite values", call. = FALSE)
  }
}

resolve_sectors <- function(sectors, n, x, Z) {
  if (!is.null(sectors)) {
    sectors <- as.data.frame(sectors, stringsAsFactors = FALSE)
    if (!all(c("code", "name") %in% names(sectors))) stop("sectors needs the columns code and name", call. = FALSE)
    if (nrow(sectors) != n) stop("sectors must have ", n, " rows; it has ", nrow(sectors), call. = FALSE)
    sectors <- sectors[, c("code", "name")]
    sectors$code <- as.character(sectors$code)
    sectors$name <- as.character(sectors$name)
  } else {
    code <- names(x)
    if (is.null(code) && !is.null(Z)) code <- colnames(Z)
    if (is.null(code)) code <- sprintf("S%02d", seq_len(n))
    sectors <- data.frame(code = code, name = code, stringsAsFactors = FALSE)
  }
  if (anyDuplicated(sectors$code)) stop("repeated sector codes", call. = FALSE)
  rownames(sectors) <- NULL
  sectors
}

# Reads one CSV of the database, detecting the format ("," and "." or ";" and ",").
read_io_csv <- function(dir, table) {
  path <- file.path(dir, paste0(table, ".csv"))
  if (!file.exists(path)) stop("file not found: ", path, call. = FALSE)
  file <- without_bom(path)
  if (!identical(file, path)) on.exit(unlink(file))
  first <- readLines(file, n = 1, encoding = "UTF-8", warn = FALSE)
  semicolon <- grepl(";", first, fixed = TRUE)
  utils::read.table(file, header = TRUE, sep = if (semicolon) ";" else ",", dec = if (semicolon) "," else ".",
                    quote = "\"", check.names = FALSE, stringsAsFactors = FALSE, strip.white = TRUE,
                    colClasses = c(code = "character"), encoding = "UTF-8", comment.char = "",
                    na.strings = c("NA", ""))
}

# TRUE when the file starts with the byte order mark that Excel writes in
# "CSV UTF-8" files.
has_bom <- function(path) {
  identical(readBin(path, "raw", 3L), as.raw(c(0xef, 0xbb, 0xbf)))
}

# The file itself when it has no byte order mark; otherwise a temporary copy
# without the mark (the caller deletes it). The copy is then read exactly as a
# file without the mark, as UTF-8 text: the first column keeps its name and
# accented names survive in any locale (reading with fileEncoding "UTF-8-BOM"
# would recode them to the native encoding, which loses them in the C locale).
without_bom <- function(path) {
  if (!has_bom(path)) return(path)
  tmp <- tempfile(fileext = ".csv")
  writeBin(readBin(path, "raw", file.size(path))[-(1:3)], tmp)
  tmp
}

# Shortest decimal that preserves the double (15 to 17 digits); NA stays NA.
exact_decimal <- function(v) {
  vapply(v, function(x) {
    if (is.na(x)) return(NA_character_)
    for (d in 15:17) {
      s <- trimws(formatC(x, digits = d, format = "g"))
      if (as.numeric(s) == x) return(s)
    }
    s
  }, character(1), USE.NAMES = FALSE)
}
