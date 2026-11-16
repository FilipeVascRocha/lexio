# Direction of a goal and the deviation it penalizes

`">="` (the goal is a floor) penalizes `d-`; `"<="` (a ceiling)
penalizes `d+`; `"="` penalizes both.

## Usage

``` r
direction_type(direction)
```

## Arguments

- direction:

  `">="`, `"<="` or `"="`.

## Value

`"minus"`, `"plus"` or `"both"`.

## Examples

``` r
direction_type(c(">=", "<=", "="))
#> [1] "minus" "plus"  "both" 
```
