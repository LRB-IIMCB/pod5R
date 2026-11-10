# Read POD5 sequencing run information

Fetch acquisition and protocol identifiers, sample rate, device details,
calibration limits and the context.

## Usage

``` r
read_pod5_runs(file)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer: POD5 path or open native reader

## Value

A list named by acquisition identifier. Each element contains a named
list describing one run, including named character vectors for
dictionaries.

## Details

Time stamps in milliseconds. Read metadata links to runs through
`acquisition_id`, rather than batch indices.

## Examples

``` r
if (FALSE) { # \dontrun{
runs <- pod5R::read_pod5_runs("reads.pod5")
} # }
```
