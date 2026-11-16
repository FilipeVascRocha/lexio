# Goal vector g

Builds the goal vector `g` of the problem `Gx + d- - d+ = g` for one
scenario of the model: first the goals of the satellite accounts, in the
declaration order of the model, then the economic goals (by default, the
declared final demand `f`).

## Usage

``` r
build_goals(io, model, scenario = 1)
```

## Arguments

- io:

  Object of class `lexio_io`.

- model:

  Object of class `lexio_model`.

- scenario:

  Name or number of the scenario.

## Value

Numeric vector with `k + n` goals.

## Details

The goal of each account starts from its base `b = D x` (see
[`define_model()`](https://filipevascrocha.github.io/lexio/reference/define_model.md)
for the goal types). The operations are done in this order, which fixes
the last bit of `g`: in the `pooled_share` shock,
`g = b + (b_1 + b_2) * s`; in growth, `g = b + b * r`.

## Examples

``` r
io <- example_io()
m <- read_model(system.file("examples", "toy", "model.yml", package = "lexio"))
build_goals(io, m, "E_shock")
#> [1]   8.38  29.00 273.00  70.00  42.00  39.00
```
