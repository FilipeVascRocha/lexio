# Contributing to lexio

Thank you for your interest in `lexio`. Questions, bug reports and
suggestions are welcome as issues at
<https://github.com/FilipeVascRocha/lexio/issues>.

## Reporting a problem

Please include:

- a short example that reproduces it, preferably with
  [`example_io()`](https://filipevascrocha.github.io/lexio/reference/example_io.md)
  or a small database declared with
  [`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md);
- the output of
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html);
- what you expected and what you got. For a run reported as not optimal,
  include the `status` and `lock_tolerance` columns of
  `res$summary$runs`.

## Proposing a change

1.  Open an issue first to discuss the change.
2.  Fork the repository and create a branch.
3.  Restore the versions used in development with `renv::restore()`.
4.  Make the change, with tests in `tests/testthat/` and documentation
    in the roxygen comments (run `roxygen2::roxygenise()`).
5.  Check that `R CMD check` passes, for instance with
    `devtools::check()`.
6.  Open a pull request that describes the change and links to the
    issue.

Changes to the solution method must keep the results of the existing
tests, including the Miller and Blair example
(`tests/testthat/test-miller-blair.R`), and the results of the
replication in `replication/`.

## Style

The code follows the tidyverse style guide, with lines of up to 120
characters (`.lintr`). Messages, documentation and output names are in
English.

## Code of conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://filipevascrocha.github.io/lexio/CODE_OF_CONDUCT.md). By
contributing to this project, you agree to abide by its terms.
