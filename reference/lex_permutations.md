# Permutations in lexicographic order

All `k!` orders of `1..k`, in lexicographic order (one per row). With
`k = 3`, the rows are the orderings P01 to P06 of `priorities = "all"`.

## Usage

``` r
lex_permutations(k)
```

## Arguments

- k:

  Number of items (satellite accounts or groups).

## Value

Integer matrix `k! x k`.

## Examples

``` r
lex_permutations(3)
#>      [,1] [,2] [,3]
#> [1,]    1    2    3
#> [2,]    1    3    2
#> [3,]    2    1    3
#> [4,]    2    3    1
#> [5,]    3    1    2
#> [6,]    3    2    1
```
