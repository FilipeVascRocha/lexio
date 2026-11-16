# Write a template database and model

Copies to `dir` the 3-sector example database, in the format read by
[`read_io()`](https://filipevascrocha.github.io/lexio/reference/read_io.md),
and a commented `model.yml`. Replace the values with those of your own
database: the number of sectors and of satellite accounts comes from the
files.

## Usage

``` r
lexio_template(dir, format = c("csv", "xlsx"))
```

## Arguments

- dir:

  Destination folder (must not exist).

- format:

  `"csv"` (a folder of CSV files) or `"xlsx"` (one workbook with the
  sheets `sectors`, `Z`, `x`, `f`, `E` and `corridor`).

## Value

`dir`, invisibly.
