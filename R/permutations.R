# Priority levels of a run, for one ordering of the model.
#
# Rows of G: account i (in declaration order) is row i (a double); the
# economic block ECO takes rows (k + 1):(k + n). Each level
# is a list of terms, one per goal (rows, penalized deviation type, weight);
# `rows` and `type` summarize the level (`type` is "mixed" when the goals of a
# level penalize different deviations).
#
# With economy: deviation: relative, the ECO term has one weight per sector,
# 1 / |g_h|, so it needs the goals `g` of the run; with "absolute" (the
# default) its weight is 1 and `g` is not used.
priority_levels <- function(model, scenario, ordering, n, g = NULL) {
  sc <- get_scenario(model, scenario)
  acc <- names(model$accounts)
  k <- length(acc)
  ord <- resolve_ordering(model, ordering)
  eco_weight <- 1
  if (identical(model$economy$deviation, "relative")) {
    if (is.null(g)) stop("relative economic deviations need the goals g of the run", call. = FALSE)
    ge <- abs(as.numeric(g[(k + 1):(k + n)]))
    if (any(ge == 0)) {
      stop("economy: deviation: relative needs a nonzero economic goal in every sector (g_h = 0 in sector(s) ",
           paste(which(ge == 0), collapse = ", "), ")", call. = FALSE)
    }
    eco_weight <- 1 / ge
  }
  term_of <- function(goal) {
    if (identical(goal, "ECO")) {
      list(goal = "ECO", rows = (k + 1):(k + n), type = direction_type(sc$directions[["economy"]]),
           weight = eco_weight)
    } else {
      list(goal = goal, rows = as.double(match(goal, acc)), type = direction_type(sc$directions[[goal]]),
           weight = model$accounts[[goal]]$weight)
    }
  }
  levels <- lapply(ord$levels, function(goals) {
    terms <- lapply(goals, term_of)
    types <- unique(vapply(terms, `[[`, character(1), "type"))
    # one goal: its rows as they are (the ECO rows stay the compact integer
    # sequence (k + 1):(k + n)); several goals: the rows in level order
    rows <- if (length(terms) == 1) terms[[1]]$rows else unlist(lapply(terms, `[[`, "rows"))
    list(name = paste(goals, collapse = "+"), goals = goals, rows = rows,
         type = if (length(types) == 1) types else "mixed", terms = terms)
  })
  list(levels = levels, index = ord$index, label = ord$label,
       level_names = vapply(levels, `[[`, character(1), "name"))
}

# An ordering: its number in the model (position in model$orderings), its
# label, or an ad hoc ordering (a character vector with one goal per level, or
# a list of levels), resolved like the explicit orderings of define_model().
resolve_ordering <- function(model, ordering) {
  if (is.numeric(ordering) && length(ordering) == 1) {
    if (ordering < 1 || ordering > length(model$orderings)) {
      stop("ordering does not exist: ", ordering, " (the model has ", length(model$orderings), ")", call. = FALSE)
    }
    return(model$orderings[[ordering]])
  }
  labels <- vapply(model$orderings, `[[`, character(1), "label")
  if (is.character(ordering) && length(ordering) == 1 && ordering %in% labels) {
    return(model$orderings[[match(ordering, labels)]])
  }
  resolve_orderings(model, list(ordering))[[1]]
}
