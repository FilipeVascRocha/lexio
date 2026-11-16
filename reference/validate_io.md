# Validate a declared database

Checks the database and returns a report. Problems that make the model
impossible (inconsistent dimensions, `x <= 0`, missing values) already
stop
[`declare_io()`](https://filipevascrocha.github.io/lexio/reference/declare_io.md);
this report holds the warnings and information:

## Usage

``` r
validate_io(io)
```

## Arguments

- io:

  Object of class `lexio_io`.

## Value

Data frame with `check`, `level` (`"ok"`, `"warning"` or `"info"`) and
`detail`.

## Details

- column sums of `A` (should be below 1) and invertibility of `I - A`;

- signs of `A` and of the account coefficients `D`;

- the corridor mode (free, two-sided, floor, ceiling) and its range;

- the balance `(I - A) x` against `f`, whatever the declaration (`Z`,
  `A` or `B`): by default `f` is the goal of the economic block, so a
  difference means that the base output `x` does not meet it exactly.
