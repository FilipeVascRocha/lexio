# Read a declared database

Reads the database from a folder of CSV files or from an `.xlsx`
workbook with sheets of the same names (see
[`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md)):

## Usage

``` r
read_io(path)
```

## Arguments

- path:

  Folder with the CSV files, or an `.xlsx` file.

## Value

Object of class `lexio_io`.

## Details

|  |  |
|----|----|
| file / sheet | content |
| `sectors` | columns `code` and `name`: the sectors and their order |
| `Z`, `A` or `B` (one) | column `code` + one column per sector (codes) |
| `x` | columns `code` and `value`: gross output |
| `f` | columns `code` and `value`: final demand |
| `E` or `D` (one) | column `code` + one column per satellite account (levels or coefficients) |
| `corridor`, or `floor` and/or `ceiling` (optional) | columns `code` and `alpha` (proportions; empty or `NA` = no bound) |

CSV files may use `,` as separator and `.` as decimal mark, or `;` and
`,`; the format is detected from the first line of each file. Rows are
matched to sectors by code, in any order. Without a corridor file, the
model is free.
