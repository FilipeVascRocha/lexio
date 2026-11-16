# Example database

A toy database with 3 sectors and 3 satellite accounts (`E`, entrant
energy; `I`, incumbent energy; `LAB`, labour), consistent
(`f = (I - A) x`), with a two-sided corridor. Used in the examples, in
the tests and in the model written by
[`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md).

## Usage

``` r
example_io()
```

## Value

Object of class `lexio_io`.

## Examples

``` r
example_io()
#> <lexio_io> 3 sectors, 3 satellite account(s): E, I, LAB | declared as Z + E | corridor: two-sided corridor 
#>   base E = D x =   6.60
#>   base I = D x =  29.00
#>   base LAB = D x = 260.00
```
