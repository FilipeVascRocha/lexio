#' Define the model
#'
#' Declares the goals of the preemptive goal program (Rocha, 2026, section 4.4):
#' the satellite accounts (in declaration order), the direction and the goal
#' of each one, the economic block (ECO), the priority orderings, the
#' scenarios and the use of the corridor declared with the data.
#'
#' **Directions.** `">="` (a floor: the goal should be reached or exceeded)
#' penalizes `d-`; `"<="` (a ceiling: the goal should not be exceeded)
#' penalizes `d+`; `"="` penalizes both. The direction is declared for each
#' account; in Rocha (2026), the entrant energy is `">="`, the incumbent
#' energy `"<="` and labour `">="`.
#'
#' **Goals of the satellite accounts** (`b` = base of the account, `D x`):
#' * `list(type = "base")`: keep the base, `g = b`;
#' * `list(type = "growth", rate = r)`: `g = b + b * r`;
#' * `list(type = "pooled_share", share = s, pool = c("A", "B"))`:
#'   `g = b + (b_A + b_B) * s`, a shock equal to a share of the sum of the
#'   bases of a set of accounts;
#' * `list(type = "delta", value = v)`: `g = b + v`;
#' * `list(type = "level", value = v)`: `g = v`.
#'
#' **Priorities.** Each priority level minimizes the weighted sum of the
#' penalized deviations of its goals; the levels are solved in order, each
#' one locked at its optimum (preemptive priorities). Without a declaration,
#' every ordering is run; to run only some orderings, declare them.
#' * `"all"` (default): one level per account, all `k!`
#'   orders of the accounts in lexicographic order of declaration (with 3
#'   accounts, P1 = 1-2-3, P2 = 1-3-2, P3 = 2-1-3, P4 = 2-3-1, P5 = 3-1-2,
#'   P6 = 3-2-1).
#' * `list(permute = list(c("OIL", "COAL"), c("SO2", "HC"), "EMP"))`: all
#'   orders of the declared groups (a group is one level with several
#'   goals).
#' * A list of explicit orderings, each a list of levels, for instance
#'   `list(first = c("GC", "GD", "LAB"), second = list(c("GD", "GC"), "LAB"))`.
#'   Only these orderings are run. Each account appears exactly once; an
#'   ordering given as a character vector has one level per element.
#'
#' **ECO is fixed at the last level** (the benchmark of the model: it
#' absorbs the final impact). To place it elsewhere, the operator must say
#' so explicitly with `economy = list(position = "free")`: then `"ECO"` can
#' be written at any level of an explicit ordering, and with `"all"` or
#' `permute` ECO enters the permutations (`(k + 1)!` orderings with `"all"`).
#' With `position = "last"` (default), `"ECO"` may be written only as the
#' last level, and it is added there when omitted.
#'
#' **Economic deviations.** With `economy = list(deviation = "absolute")`
#' (default), the ECO level minimizes the sum of the
#' deviations of the sectors in currency units, so large sectors weigh more.
#' With `deviation = "relative"`, each sector's deviation is divided by its
#' goal, `d_h / |g_h|`: the level minimizes the sum of the proportional
#' deviations, and a shortfall of 1% weighs the same in every sector. It
#' needs `g_h != 0` in every sector.
#'
#' **Weights.** `weight` (default 1) multiplies the deviation of an account
#' inside its level; it only matters when several goals share a level.
#'
#' **Corridor.** The corridor itself is declared with the data
#' ([declare_io()]). `corridor = list(use = FALSE)` ignores it (free model);
#' `multiplier` scales `alpha`.
#'
#' **Scenarios.** Each scenario replaces the goals of some accounts and,
#' optionally, the directions (`directions`) and the corridor (`corridor`).
#' Without scenarios, the model has one scenario, `main`.
#'
#' @param accounts Named list, one entry per satellite account, in
#'   declaration order. Each entry: `direction`, `target` and, optionally,
#'   `weight`, `unit` and `label`.
#' @param economy List with `direction` (default `">="`), `target`
#'   (`"final_demand"`, the default, the declared `f`; a numeric vector with
#'   one goal per sector; or a CSV file with `code` and `value`), `position`
#'   (`"last"`, the default, or `"free"`) and `deviation` (`"absolute"`, the
#'   default, or `"relative"`).
#' @param priorities `"all"`, a `permute` specification or a list of explicit
#'   orderings (see above).
#' @param scenarios Named list of scenarios (optional).
#' @param corridor List with `use` (default `TRUE`) and `multiplier` (default
#'   1).
#' @param lock_tolerance Lock of the levels already solved. `"auto"`
#'   (default): the exact lock `d_l == Z_l` and,
#'   only if a level of the run ends non-optimal (a false infeasibility of
#'   GLPK), the run is solved again with relaxed locks
#'   `d_l <= Z_l + t * max(1, |Z_l|)`, with the smallest `t` among 1e-12,
#'   1e-11, 1e-10 and 1e-9 that makes every level optimal. Runs that are
#'   optimal with the exact lock do not change; each run records the
#'   tolerance used, and the outputs flag the relaxed runs. `"exact"` (or
#'   `0`): only the exact lock. A number `t` (up to 1e-6): the exact lock
#'   and, if it fails, the relaxed one with `t`.
#' @param name Name of the model (used in the outputs).
#' @param data Path of the database (optional; used by [run_model()] when
#'   the model comes from a file).
#' @param max_orderings Safety limit for the number of orderings.
#'
#' @return Object of class `lexio_model`.
#' @seealso [read_model()], [run_model()].
#' @examples
#' shock <- list(type = "pooled_share", share = 0.05, pool = c("E", "I"))
#' m <- define_model(list(
#'   E = list(direction = ">=", target = shock),
#'   I = list(direction = "<=", target = "base"),
#'   LAB = list(direction = ">=", target = list(type = "growth", rate = 0.05))
#' ))
#' m
#' @export
define_model <- function(accounts, economy = list(direction = ">=", target = "final_demand"),
                         priorities = "all", scenarios = NULL, corridor = list(use = TRUE, multiplier = 1),
                         lock_tolerance = "auto", name = "model", data = NULL, max_orderings = 720) {
  if (!is.list(accounts) || is.null(names(accounts)) || any(!nzchar(names(accounts))) || !length(accounts)) {
    stop("accounts must be a named list (one entry per satellite account)", call. = FALSE)
  }
  acc <- names(accounts)
  if (anyDuplicated(acc)) stop("repeated accounts: ", paste(acc[duplicated(acc)], collapse = ", "), call. = FALSE)
  reserved <- c("economy", "ECO", "corridor", "directions", "priorities")
  if (any(acc %in% reserved)) {
    stop("reserved names cannot be accounts: ", paste(reserved, collapse = ", "), call. = FALSE)
  }
  accounts <- lapply(stats::setNames(acc, acc), function(a) {
    spec <- accounts[[a]]
    if (is.null(spec$direction)) stop("account ", a, ": direction is missing", call. = FALSE)
    check_direction(spec$direction, paste("account", a))
    weight <- if (is.null(spec$weight)) 1 else spec$weight
    if (!is.numeric(weight) || length(weight) != 1 || !is.finite(weight) || weight <= 0) {
      stop("account ", a, ": weight must be a positive number", call. = FALSE)
    }
    list(direction = spec$direction,
         target = normalize_target(if (is.null(spec$target)) "base" else spec$target, acc, paste("account", a)),
         weight = as.numeric(weight),
         unit = if (is.null(spec$unit)) "" else as.character(spec$unit),
         label = if (is.null(spec$label)) a else as.character(spec$label))
  })
  economy <- check_economy(economy)
  corridor <- check_corridor_spec(utils::modifyList(list(use = TRUE, multiplier = 1), as.list(corridor)), "corridor")
  model <- structure(list(
    name = name, data = data, accounts = accounts, economy = economy, corridor = corridor,
    max_orderings = max_orderings, lock_tolerance = check_lock_tolerance(lock_tolerance)
  ), class = "lexio_model")
  model$scenarios <- resolve_scenarios(model, scenarios)
  model$orderings <- resolve_orderings(model, priorities)
  model
}

#' Read the model from a YAML file
#'
#' Reads a `model.yml` (see the example written by [lexio_template()]). The
#' paths `data` and `economy: target` (when it is a file) are relative to the
#' folder of the file.
#'
#' @param path A `.yml` file.
#' @return Object of class `lexio_model`.
#' @export
read_model <- function(path) {
  if (!file.exists(path)) stop("model not found: ", path, call. = FALSE)
  y <- yaml::read_yaml(path)
  base_dir <- dirname(normalizePath(path, winslash = "/"))
  resolve <- function(p) {
    if (is.null(p)) return(NULL)
    if (grepl("^([A-Za-z]:)?[/\\\\]", p)) p else file.path(base_dir, p)
  }
  economy <- if (is.null(y$economy)) list() else y$economy
  if (is.character(economy$target) && !identical(economy$target, "final_demand")) {
    economy$target <- resolve(economy$target)
  }
  if (is.null(y$accounts)) stop(path, ": the section accounts is missing", call. = FALSE)
  unknown <- setdiff(names(y), c("name", "data", "accounts", "economy", "priorities", "scenarios", "corridor",
                                 "lock_tolerance", "max_orderings"))
  if (length(unknown)) stop(path, ": unknown keys: ", paste(unknown, collapse = ", "), call. = FALSE)
  m <- define_model(
    accounts = y$accounts,
    economy = economy,
    priorities = if (is.null(y$priorities)) "all" else y$priorities,
    scenarios = y$scenarios,
    corridor = if (is.null(y$corridor)) list() else y$corridor,
    lock_tolerance = if (is.null(y$lock_tolerance)) "auto" else y$lock_tolerance,
    name = if (is.null(y$name)) tools::file_path_sans_ext(basename(path)) else y$name,
    data = resolve(y$data),
    max_orderings = if (is.null(y$max_orderings)) 720 else y$max_orderings
  )
  m$source <- normalizePath(path, winslash = "/")
  m
}

#' Permutations in lexicographic order
#'
#' All `k!` orders of `1..k`, in lexicographic order (one per row). With
#' `k = 3`, the rows are the orderings P01 to P06 of `priorities = "all"`.
#'
#' @param k Number of items (satellite accounts or groups).
#' @return Integer matrix `k! x k`.
#' @examples
#' lex_permutations(3)
#' @export
lex_permutations <- function(k) {
  k <- as.integer(k)
  if (k < 1) stop("k must be at least 1", call. = FALSE)
  if (k == 1L) return(matrix(1L, 1, 1))
  rest <- lex_permutations(k - 1L)
  out <- lapply(seq_len(k), function(i) {
    others <- setdiff(seq_len(k), i)
    cbind(i, matrix(others[rest], ncol = k - 1L))
  })
  unname(do.call(rbind, out))
}

#' @export
print.lexio_model <- function(x, ...) {
  cat("<lexio_model>", x$name, "|", length(x$accounts), "satellite account(s),", length(x$scenarios),
      "scenario(s),", length(x$orderings), "priority ordering(s) | lock:", describe_lock(x$lock_tolerance), "\n")
  for (a in names(x$accounts)) {
    s <- x$accounts[[a]]
    cat(sprintf("  %-8s %-2s %s%s\n", a, s$direction, describe_target(s$target),
                if (s$weight != 1) sprintf(" (weight %g)", s$weight) else ""))
  }
  cat(sprintf("  %-8s %-2s %s | %s deviations | %s\n", "ECO", x$economy$direction,
              if (identical(x$economy$target, "final_demand")) "final demand f" else "declared goals",
              if (is.null(x$economy$deviation)) "absolute" else x$economy$deviation,
              if (identical(x$economy$position, "free")) "position free (declared by the operator)"
              else "fixed at the last level"))
  cat("  corridor:", if (isTRUE(x$corridor$use)) sprintf("as declared in the data (multiplier %g)", x$corridor$multiplier)
                     else "not used (free)", "\n")
  shown <- utils::head(x$orderings, 6)
  for (o in shown) cat("  ", o$label, ": ", describe_levels(o$levels), "\n", sep = "")
  if (length(x$orderings) > 6) cat("  ... and", length(x$orderings) - 6, "more orderings\n")
  for (sc in x$scenarios) {
    changed <- names(sc$targets)[!mapply(identical, sc$targets, lapply(x$accounts, `[[`, "target"))]
    cat("  scenario", sc$name, if (length(changed)) paste0("(changes: ", paste(changed, collapse = ", "), ")") else "",
        "\n")
  }
  invisible(x)
}

# ------------------------------------------------------------------------------
# Internals
# ------------------------------------------------------------------------------
# lock_tolerance: "auto", "exact" (= 0), 0 or a number in (0, 1e-6]. In YAML,
# 1e-9 may arrive as text.
check_lock_tolerance <- function(x) {
  if (identical(x, "auto")) return("auto")
  if (identical(x, "exact")) return(0)
  v <- suppressWarnings(as.numeric(x))
  if (length(v) != 1 || is.na(v) || v < 0 || v > 1e-6) {
    stop("lock_tolerance must be \"auto\", \"exact\" (0) or a number between 0 and 1e-6", call. = FALSE)
  }
  v
}

# Tolerances tried in a run: always the exact lock first.
lock_tolerances <- function(x) {
  x <- check_lock_tolerance(x)
  if (identical(x, "auto")) return(c(0, 1e-12, 1e-11, 1e-10, 1e-9))
  if (x == 0) 0 else c(0, x)
}

describe_lock <- function(x) {
  if (identical(x, "auto")) "auto (exact; relaxed only where GLPK fails)" else if (identical(x, 0)) "exact" else {
    paste0("exact, then relaxed ", format(x))
  }
}

check_direction <- function(d, where) {
  if (!(is.character(d) && length(d) == 1 && d %in% c(">=", "<=", "="))) {
    stop(where, ": invalid direction (use \">=\", \"<=\" or \"=\")", call. = FALSE)
  }
}

check_economy <- function(economy) {
  defaults <- list(direction = ">=", target = "final_demand", position = "last", deviation = "absolute")
  economy <- as.list(economy)
  unknown <- setdiff(names(economy), names(defaults))
  if (length(unknown)) {
    stop("economy: unknown keys (", paste(unknown, collapse = ", "), "); the keys are direction, target, position ",
         "and deviation", call. = FALSE)
  }
  economy <- utils::modifyList(defaults, economy)
  check_direction(economy$direction, "economy")
  if (!(identical(economy$target, "final_demand") || is.numeric(economy$target) ||
        (is.character(economy$target) && length(economy$target) == 1))) {
    stop("economy$target must be \"final_demand\", a numeric vector or a CSV file (code, value)", call. = FALSE)
  }
  if (!(is.character(economy$position) && length(economy$position) == 1 && economy$position %in% c("last", "free"))) {
    stop("economy$position must be \"last\" (ECO fixed at the last level, the default) or \"free\"", call. = FALSE)
  }
  if (!(is.character(economy$deviation) && length(economy$deviation) == 1 &&
        economy$deviation %in% c("absolute", "relative"))) {
    stop("economy$deviation must be \"absolute\" (the default) or \"relative\"", call. = FALSE)
  }
  economy
}

check_corridor_spec <- function(cs, where) {
  unknown <- setdiff(names(cs), c("use", "multiplier"))
  if (length(unknown)) stop(where, ": unknown corridor keys (", paste(unknown, collapse = ", "), ")", call. = FALSE)
  if (!is.logical(cs$use) || length(cs$use) != 1 || is.na(cs$use)) stop(where, ": use must be TRUE or FALSE",
                                                                       call. = FALSE)
  if (!is.numeric(cs$multiplier) || length(cs$multiplier) != 1 || !is.finite(cs$multiplier) || cs$multiplier < 0) {
    stop(where, ": multiplier must be a number >= 0", call. = FALSE)
  }
  list(use = cs$use, multiplier = as.numeric(cs$multiplier))
}

normalize_target <- function(t, accounts, where) {
  if (is.character(t) && length(t) == 1) t <- list(type = t)
  if (!is.list(t) || is.null(t$type)) stop(where, ": invalid goal (type is missing)", call. = FALSE)
  num1 <- function(v, nm) {
    if (!is.numeric(v) || length(v) != 1 || !is.finite(v)) stop(where, ": ", nm, " must be a number", call. = FALSE)
    as.numeric(v)
  }
  switch(t$type,
    base = list(type = "base"),
    growth = list(type = "growth", rate = num1(t$rate, "rate")),
    pooled_share = {
      pool <- as.character(unlist(t$pool))
      if (!length(pool) || any(!pool %in% accounts)) {
        stop(where, ": pool must list declared accounts (", paste(accounts, collapse = ", "), ")", call. = FALSE)
      }
      list(type = "pooled_share", share = num1(t$share, "share"), pool = pool)
    },
    delta = list(type = "delta", value = num1(t$value, "value")),
    level = list(type = "level", value = num1(t$value, "value")),
    stop(where, ": unknown goal type '", t$type, "' (use base, growth, pooled_share, delta or level)", call. = FALSE)
  )
}

# Position (1, 2, ...) of a permutation of 1..k in lexicographic order.
lex_rank <- function(p) {
  k <- length(p)
  rank <- 1
  for (i in seq_len(k - 1)) {
    smaller <- sum(p[(i + 1):k] < p[i])
    rank <- rank + smaller * factorial(k - i)
  }
  rank
}

describe_target <- function(t) {
  switch(t$type,
    base = "base",
    growth = sprintf("base x (1 + %g)", t$rate),
    pooled_share = sprintf("base + %g x (%s)", t$share, paste(t$pool, collapse = " + ")),
    delta = sprintf("base + %g", t$value),
    level = sprintf("level %g", t$value)
  )
}

# "GD > GC > LAB > ECO"; a level with several goals is written "OIL + COAL".
describe_levels <- function(levels) paste(vapply(levels, paste, character(1), collapse = " + "), collapse = " > ")

resolve_scenarios <- function(model, scenarios) {
  acc <- names(model$accounts)
  default_targets <- lapply(model$accounts, `[[`, "target")
  default_dirs <- c(vapply(model$accounts, `[[`, character(1), "direction"), economy = model$economy$direction)
  make <- function(name, spec) {
    spec <- if (is.null(spec)) list() else spec
    unknown <- setdiff(names(spec), c(acc, "directions", "corridor"))
    if (length(unknown)) {
      stop("scenario ", name, ": unknown keys (", paste(unknown, collapse = ", "), ")", call. = FALSE)
    }
    targets <- default_targets
    for (a in intersect(names(spec), acc)) targets[[a]] <- normalize_target(spec[[a]], acc, paste("scenario", name, a))
    dirs <- default_dirs
    if (!is.null(spec$directions)) {
      bad <- setdiff(names(spec$directions), c(acc, "economy"))
      if (length(bad)) stop("scenario ", name, ": directions for unknown accounts", call. = FALSE)
      for (a in names(spec$directions)) {
        check_direction(spec$directions[[a]], paste("scenario", name, a))
        dirs[[a]] <- spec$directions[[a]]
      }
    }
    cor <- model$corridor
    if (!is.null(spec$corridor)) cor <- check_corridor_spec(utils::modifyList(cor, as.list(spec$corridor)),
                                                           paste("scenario", name))
    list(name = name, targets = targets, directions = dirs, corridor_use = cor$use,
         corridor_multiplier = cor$multiplier, economy_target = model$economy$target)
  }
  if (is.null(scenarios) || !length(scenarios)) return(list(main = make("main", NULL)))
  if (is.null(names(scenarios)) || any(!nzchar(names(scenarios))) || anyDuplicated(names(scenarios))) {
    stop("scenarios must be a list with unique names", call. = FALSE)
  }
  lapply(stats::setNames(names(scenarios), names(scenarios)), function(nm) make(nm, scenarios[[nm]]))
}

# Priority orderings: a list of list(index, label, levels), where levels is a
# list of character vectors (the goals of each level; "ECO" = economic block).
resolve_orderings <- function(model, priorities) {
  acc <- names(model$accounts)
  # ECO is fixed at the last level unless the model says economy: position: free
  eco_free <- identical(model$economy$position, "free")
  if (identical(priorities, "all")) priorities <- list(permute = as.list(acc))
  if (is.list(priorities) && !is.null(priorities$permute)) {
    extra <- setdiff(names(priorities), "permute")
    if (length(extra)) {
      stop("priorities: unknown keys with permute (", paste(extra, collapse = ", "), "). The position of ECO is ",
           "set by economy: position (\"last\" or \"free\")", call. = FALSE)
    }
    groups <- lapply(priorities$permute, function(gr) as.character(unlist(gr)))
    check_levels(groups, acc, allow_eco = FALSE, where = "priorities$permute")
    eco <- if (eco_free) "free" else "last"
    items <- if (eco == "free") c(groups, list("ECO")) else groups
    n_ord <- factorial(length(items))
    if (n_ord > model$max_orderings) {
      stop(sprintf("%d priority groups give %s orderings (limit %d). List the orderings explicitly or raise max_orderings.",
                   length(items), format(n_ord, big.mark = ",", scientific = FALSE), model$max_orderings),
           call. = FALSE)
    }
    p <- lex_permutations(length(items))
    return(lapply(seq_len(nrow(p)), function(i) {
      lv <- items[p[i, ]]
      if (eco == "last") lv <- c(lv, list("ECO"))
      list(index = as.double(i), label = sprintf("P%02d", i), levels = lv)
    }))
  }
  if (!is.list(priorities) || !length(priorities)) {
    stop("priorities must be \"all\", list(permute = ...) or a list of orderings", call. = FALSE)
  }
  nm <- names(priorities)
  out <- lapply(seq_along(priorities), function(i) {
    o <- priorities[[i]]
    lv <- if (is.character(o)) as.list(o) else if (is.list(o)) lapply(o, function(l) as.character(unlist(l))) else {
      stop("priorities: ordering ", i, " must be a list of levels", call. = FALSE)
    }
    where <- paste("priorities: ordering", if (!is.null(nm) && nzchar(nm[i])) nm[i] else i)
    check_levels(lv, acc, allow_eco = TRUE, where = where)
    has_eco <- vapply(lv, identical, logical(1), "ECO")
    if (!any(has_eco)) {
      lv <- c(lv, list("ECO"))
    } else if (!eco_free && which(has_eco) != length(lv)) {
      stop(where, ": ECO is fixed at the last level. To place it elsewhere, declare it explicitly with ",
           "economy: position: free (in R, economy = list(position = \"free\"))", call. = FALSE)
    }
    single <- all(lengths(lv) == 1) && identical(lv[[length(lv)]], "ECO")
    index <- if (single) lex_rank(match(unlist(lv[-length(lv)]), acc)) else i
    label <- if (!is.null(nm) && nzchar(nm[i])) nm[i] else if (single) sprintf("P%02d", index) else sprintf("O%02d", i)
    list(index = as.double(index), label = label, levels = lv)
  })
  labels <- vapply(out, `[[`, character(1), "label")
  if (anyDuplicated(labels)) stop("priorities: repeated orderings or names: ", paste(unique(labels[duplicated(labels)]),
                                                                                   collapse = ", "), call. = FALSE)
  out
}

check_levels <- function(levels, acc, allow_eco, where) {
  goals <- unlist(levels)
  unknown <- setdiff(goals, c(acc, if (allow_eco) "ECO"))
  if (length(unknown)) stop(where, ": unknown goals (", paste(unknown, collapse = ", "), "); the accounts are ",
                            paste(acc, collapse = ", "), if (allow_eco) " and ECO", call. = FALSE)
  if (any(lengths(levels) == 0)) stop(where, ": empty level", call. = FALSE)
  dup <- goals[duplicated(goals)]
  if (length(dup)) stop(where, ": each goal must appear once (repeated: ", paste(unique(dup), collapse = ", "), ")",
                        call. = FALSE)
  miss <- setdiff(acc, goals)
  if (length(miss)) stop(where, ": every account must appear once (missing: ", paste(miss, collapse = ", "), ")",
                         call. = FALSE)
  if (allow_eco) {
    with_eco <- vapply(levels, function(l) "ECO" %in% l, logical(1))
    if (any(with_eco & lengths(levels) > 1)) stop(where, ": ECO must be alone in its level", call. = FALSE)
  }
  invisible(TRUE)
}
