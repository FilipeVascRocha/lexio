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

## Details

Reading the files back gives the same numbers, bit for bit, where R
reads decimal numbers with extended precision (Windows, Linux and Intel
Macs). On Macs with Apple silicon, R itself may read a number written
with 16 or 17 significant digits with a difference in the last bit
(about 1e-16, relative); numbers with up to 15 significant digits are
read exactly everywhere.
