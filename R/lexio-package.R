#' lexio: generalized input-output model with preemptive goal programming
#'
#' The model chooses the sectoral output `x` that best meets, in
#' lexicographic order, a set of goals: k satellite accounts declared by the
#' user (for instance, energy sources and labour) and the economic block ECO
#' (the final demand of every sector). The goals are written as
#'
#' \deqn{G x + d^- - d^+ = g, \qquad G = \begin{bmatrix} D \ I - A \end{bmatrix},}
#'
#' with deviations `d^-, d^+ >= 0` and, optionally, a corridor on the
#' economic deviations, `d_h^-, d_h^+ <= alpha_h |g_h|`. Each priority level
#' is an LP that minimizes the weighted sum of the penalized deviations of
#' its goals, with the earlier levels locked at their optima (`d_j == Z_j`).
#' By default the package runs the `k!` orders of the satellite accounts,
#' with ECO fixed at the last level; the operator may list the orderings to
#' run (with several goals per level) and, only by an explicit declaration
#' (`economy = list(position = "free")`), move ECO to another level.
#'
#' Typical workflow:
#' 1. declare the database you already have: technical structure (`Z`, `A`
#'    or `B`), gross output `x`, final demand `f`, the satellite accounts
#'    (`E` levels or `D` coefficients) and, optionally, the corridor
#'    ([declare_io()], or [read_io()] for a folder of CSV files);
#' 2. declare the model: accounts, directions, goals, priorities, scenarios
#'    ([define_model()] or [read_model()]);
#' 3. run every ordering ([run_model()]) and write the results: a folder
#'    of tables, a report and an Excel workbook ([write_outputs()]), or only
#'    the workbook ([write_excel()]).
#'
#' The solver is GLPK, through ROI (`ROI.plugin.glpk`), with the default
#' options.
#'
#' @references Rocha, F. V. (2026). Modelo generalizado de insumo-produto com
#'   Goal Programming preemptivo aplicado à transição energética brasileira:
#'   eletricidade e combustíveis na estrutura produtiva de 2018. Doctoral
#'   thesis, Programa de Pós-graduação em Economia, Universidade Federal de
#'   Juiz de Fora. Miller, R. E. and Blair, P. D. (2022). Input-Output
#'   Analysis: Foundations and Extensions, 3rd ed., section 13.8 (2nd ed.,
#'   2009, section 10.4).
#'   EPE and FIPE (2023). Metodologia para construção de uma Matriz
#'   Insumo-Produto com detalhamento dos setores energéticos.
#' @keywords internal
#' @import ROI.plugin.glpk
"_PACKAGE"
