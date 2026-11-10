# Validate a non-negative whole number

Checks if the value is a single numeric whole number greater than or
equal to defined minimum. A positive infinity is also accepted.

## Usage

``` r
.check_number(x, name, minimum = 0, allow_infinite = FALSE)
```

## Arguments

- x:

  [numeric](https://rdrr.io/r/base/numeric.html) value to validate

- name:

  [character](https://rdrr.io/r/base/character.html) string which
  provides a name for 'x' used in the error message if validation fails

- minimum:

  [numeric](https://rdrr.io/r/base/numeric.html) the minimum allowed
  value. Default is 0.

- allow_infinite:

  [logical](https://rdrr.io/r/base/logical.html) decides whether 'Inf'
  is accepted. Defaults to "FALSE".

## Value

Invisibly returns "TRUE" if validation passes.

## Details

Finite values must be a whole numbers and must not exceed 2^53 -1 (R
precision ceiling).
