# Read the model from a YAML file

Reads a `model.yml` (see the example written by
[`lexio_template()`](https://filipevascrocha.github.io/lexio/reference/lexio_template.md)).
The paths `data` and `economy: target` (when it is a file) are relative
to the folder of the file.

## Usage

``` r
read_model(path)
```

## Arguments

- path:

  A `.yml` file.

## Value

Object of class `lexio_model`.
