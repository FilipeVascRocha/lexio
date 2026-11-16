#' Goal vector g
#'
#' Builds the goal vector `g` of the problem `Gx + d- - d+ = g` for one
#' scenario of the model: first the goals of the satellite accounts, in the
#' declaration order of the model, then the economic goals (by default, the
#' declared final demand `f`).
#'
#' The goal of each account starts from its base `b = D x` (see
#' [define_model()] for the goal types). The operations are done in this
#' order, which fixes the last bit of `g`: in the `pooled_share` shock,
#' `g = b + (b_1 + b_2) * s`; in growth, `g = b + b * r`.
#'
#' @param io Object of class `lexio_io`.
#' @param model Object of class `lexio_model`.
#' @param scenario Name or number of the scenario.
#'
#' @return Numeric vector with `k + n` goals.
#' @examples
#' io <- example_io()
#' m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
#' build_goals(io, m, "E_shock")
#' @export
build_goals <- function(io, model, scenario = 1) {
  sc <- get_scenario(model, scenario)
  acc <- names(model$accounts)
  b <- satellite_base(io, acc)
  sat <- vapply(acc, function(a) goal_value(sc$targets[[a]], b, a), numeric(1), USE.NAMES = FALSE)
  c(sat, economy_goal(sc$economy_target, io))
}

#' Bases of the satellite accounts
#'
#' `D %*% x`: the value of each satellite account at the observed output.
#'
#' @param io Object of class `lexio_io`.
#' @param accounts Accounts (default: all accounts of the database).
#' @return Named numeric vector.
#' @export
satellite_base <- function(io, accounts = io$accounts) {
  stats::setNames(as.numeric(account_rows(io, accounts) %*% io$x), accounts)
}

goal_value <- function(t, b, a) {
  switch(t$type,
    base = b[[a]],
    growth = b[[a]] + b[[a]] * t$rate,
    pooled_share = b[[a]] + Reduce(`+`, unname(b[t$pool])) * t$share,
    delta = b[[a]] + t$value,
    level = t$value
  )
}

economy_goal <- function(target, io) {
  if (identical(target, "final_demand")) return(io$f)
  if (is.numeric(target)) {
    if (length(target) != io$n) stop("the economic goal must have ", io$n, " values", call. = FALSE)
    return(as.numeric(target))
  }
  path <- target
  if (!file.exists(path)) stop("file of the economic goal not found: ", path, call. = FALSE)
  file <- without_bom(path)
  if (!identical(file, path)) on.exit(unlink(file))
  first <- readLines(file, n = 1, warn = FALSE)
  semicolon <- grepl(";", first, fixed = TRUE)
  df <- utils::read.table(file, header = TRUE, sep = if (semicolon) ";" else ",", dec = if (semicolon) "," else ".",
                          stringsAsFactors = FALSE, colClasses = c(code = "character"))
  idx <- match(io$sectors$code, df$code)
  if (anyNA(idx)) stop("economic goal: sectors missing in ", path, call. = FALSE)
  as.numeric(df$value[idx])
}

# Rows of D of the requested accounts, in the requested order.
account_rows <- function(io, accounts) {
  idx <- match(accounts, io$accounts)
  if (anyNA(idx)) {
    stop("accounts of the model that are not in the database: ", paste(accounts[is.na(idx)], collapse = ", "),
         " (the database has: ", paste(io$accounts, collapse = ", "), ")", call. = FALSE)
  }
  io$D[idx, , drop = FALSE]
}

get_scenario <- function(model, scenario) {
  if (is.numeric(scenario)) {
    if (scenario < 1 || scenario > length(model$scenarios)) stop("scenario does not exist: ", scenario, call. = FALSE)
    return(model$scenarios[[scenario]])
  }
  if (!scenario %in% names(model$scenarios)) {
    stop("scenario does not exist: ", scenario, " (the model has: ", paste(names(model$scenarios), collapse = ", "), ")",
         call. = FALSE)
  }
  model$scenarios[[scenario]]
}
