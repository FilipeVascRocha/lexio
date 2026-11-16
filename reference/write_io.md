# Write a declared database as CSV files

Writes the database in the format read by
[`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md),
with the shortest decimal representation that preserves each number
exactly (up to 17 significant digits). The objects are written as they
were declared: `Z`, `A` or `B`; `E` or `D`; and the corridor files, if
any.

## Usage

``` r
write_io(io, dir)
```

## Arguments

- io:

  Object of class `lexio_io`.

- dir:

  Destination folder (created if needed).

## Value

`dir`, invisibly.
