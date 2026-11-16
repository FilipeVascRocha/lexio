#' Run the model
#'
#' Runs every priority ordering of every scenario of the model. With the
#' default `priorities = "all"` and k satellite accounts, there are `k!`
#' orderings per scenario, with ECO last. The number of sectors and of
#' accounts comes from the database.
#'
#' The simplest call passes the path of a `model.yml`: the model says where
#' the database is (`data`). The database and the model can also be passed
#' as objects ([declare_io()], [define_model()]).
#'
#' @param io Path of a `model.yml`, or a `lexio_io` object.
#' @param model A `lexio_model` object (when `io` is the database).
#' @param scenarios Scenarios to run (names; default: all).
#' @param orderings Orderings to run (numbers or labels; default: all of the
#'   model).
#' @param strict If `TRUE`, stops at the first non-optimal level. With
#'   `FALSE` (default), runs everything and records the status of each
#'   level, shown in the summary and in the report.
#' @param verbose Show progress.
#' @param lock_tolerance Replaces the `lock_tolerance` of the model (see
#'   [define_model()]); `NULL` (default) uses the one of the model.
#'
#' @return Object of class `lexio_results`: the model, the database, the
#'   runs (`runs`, one per scenario x ordering), the summary
#'   ([summarize_runs()]) and metadata. Use [write_outputs()] to write
#'   everything to a folder.
#' @examples
#' res <- run_model(system.file("examples", "toy", "model.yml", package = "lexio"), verbose = FALSE)
#' res
#' head(res$summary$runs)
#' @export
run_model <- function(io, model = NULL, scenarios = NULL, orderings = NULL, strict = FALSE,
                      verbose = interactive(), lock_tolerance = NULL) {
  if (is.character(io) && length(io) == 1) {
    if (!grepl("\\.ya?ml$", io, ignore.case = TRUE)) {
      stop("give the path of a model.yml, or the database (lexio_io) and the model (lexio_model)", call. = FALSE)
    }
    model <- read_model(io)
    if (is.null(model$data)) stop("the model does not say where the database is (data)", call. = FALSE)
    io <- read_io(model$data)
  }
  if (!inherits(io, "lexio_io")) stop("`io` must be a lexio_io object or the path of a model.yml", call. = FALSE)
  if (!inherits(model, "lexio_model")) stop("`model` must be a lexio_model object", call. = FALSE)
  account_rows(io, names(model$accounts))
  if (!is.null(lock_tolerance)) model$lock_tolerance <- check_lock_tolerance(lock_tolerance)
  scs <- if (is.null(scenarios)) names(model$scenarios) else vapply(scenarios, function(s) get_scenario(model, s)$name,
                                                                    character(1))
  ords <- if (is.null(orderings)) seq_along(model$orderings) else {
    labels <- vapply(model$orderings, `[[`, character(1), "label")
    vapply(orderings, function(o) {
      i <- if (is.numeric(o)) as.integer(o) else match(o, labels)
      if (is.na(i) || i < 1 || i > length(labels)) stop("ordering does not exist: ", o, call. = FALSE)
      i
    }, integer(1))
  }
  total <- length(scs) * length(ords)
  runs <- vector("list", total)
  t0 <- proc.time()[["elapsed"]]
  i <- 0L
  for (s in scs) {
    for (p in ords) {
      i <- i + 1L
      runs[[i]] <- run_experiment(io, model, scenario = s, ordering = p, strict = strict)
      if (verbose) {
        r <- runs[[i]]
        message(sprintf("[%d/%d] %s %s %s: %s%s", i, total, s, r$label, paste(r$order, collapse = " > "),
                        if (r$optimal) "optimal" else paste(r$status_symbol, collapse = ","),
                        if (r$lock_tolerance > 0) paste0(" (relaxed lock ", format(r$lock_tolerance), ")") else ""))
      }
    }
  }
  res <- structure(list(
    model = model, io = io, runs = runs, summary = summarize_runs(runs),
    meta = c(run_metadata(), list(elapsed = proc.time()[["elapsed"]] - t0))
  ), class = "lexio_results")
  n_bad <- sum(!res$summary$runs$optimal)
  n_none <- sum(!is.na(res$summary$runs$infeasible_level))
  n_relaxed <- sum(res$summary$runs$lock_tolerance > 0)
  if (n_bad) {
    warning(n_bad, " run(s) with a non-optimal level (see summary$runs$status and the report of write_outputs)",
            if (n_none) paste0("; in ", n_none, " of them a level has no solution and is left blank") else "",
            call. = FALSE)
  }
  if (n_relaxed) {
    warning(n_relaxed, " run(s) solved only with the relaxed lock (lock_tolerance); later levels may differ by up ",
            "to about 2e-4 (relative) from an exact solution. ",
            "See vignette(\"model-specification\", package = \"lexio\").", call. = FALSE)
  }
  res
}

#' @export
print.lexio_results <- function(x, ...) {
  s <- x$summary$runs
  cat("<lexio_results>", x$model$name, "|", x$io$n, "sectors |", length(x$model$accounts), "account(s):",
      paste(names(x$model$accounts), collapse = ", "), "| corridor:", unique(s$corridor)[1], "\n")
  for (sc in unique(s$scenario)) {
    d <- s[s$scenario == sc, ]
    n_none <- sum(!is.na(d$infeasible_level))
    cat(sprintf("  scenario %-12s %3d ordering(s) | %s | %d distinct state(s)\n", sc, nrow(d),
                if (all(d$optimal)) "all optimal"
                else paste0(sum(!d$optimal), " with a non-optimal level",
                            if (n_none) paste0(" (", n_none, " without solution)") else ""),
                length(unique(d$state[!is.na(d$state)]))))
  }
  n_relaxed <- sum(s$lock_tolerance > 0)
  if (n_relaxed) {
    cat("  WARNING:", n_relaxed, "run(s) solved only with the relaxed lock (lock_tolerance):",
        "later levels may differ by up to about 2e-4 (relative); see the report\n")
  }
  cat("  distinct states in total:", nrow(x$summary$states), "\n")
  cat("  write everything with write_outputs(res, \"folder\")\n")
  invisible(x)
}

#' @export
summary.lexio_results <- function(object, ...) {
  object$summary
}
