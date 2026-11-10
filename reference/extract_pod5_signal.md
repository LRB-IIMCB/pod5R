# Extract selected POD5 signal vectors

This is a convenience wrapper around
[`read_pod5`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md)
that requests signal data and returns only the `signal` component of the
result. Signals can be returned either as raw ADC counts or as
calibrated current values.

## Usage

``` r
extract_pod5_signal(
  file,
  read_ids = NULL,
  calibrated = FALSE,
  start_sample = 1,
  end_sample = Inf
)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer: POD5 path or open native reader

- read_ids:

  [character](https://rdrr.io/r/base/character.html) (default: `NULL`).
  Unique read UUIDs. NULL selects by row range.

- calibrated:

  [logical](https://rdrr.io/r/base/logical.html) (default: `FALSE`).
  Return signal in picoampers instead of ADC counts.

- start_sample:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `1`). First
  signal sample, one-based and inclusive.

- end_sample:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `Inf`). Last
  signal sample, one-based and inclusive.

## Value

list of signal vectors named by read UUID in requested order.

## See also

[`read_pod5`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md)
for coordinate and calibration details.

## Examples

``` r
if (FALSE) { # \dontrun{
read_ids <- pod5R::read_pod5_ids("reads.pod5")
signals <- pod5R::extract_pod5_signal("reads.pod5", read_ids[1],
start_sample = 101, end_sample = 500)
} # }
```
