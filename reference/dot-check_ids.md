# Validate POD5 read IDs

Validates a vector of POD5 read identifiers and converts them to
lowercase UUID strings.

## Usage

``` r
.check_ids(read_ids)
```

## Arguments

- read_ids:

  [character](https://rdrr.io/r/base/character.html) vector of read IDs
  in UUID format or 'NULL'

## Value

a vector of validated 'read_ids' converted to lowercase or 'NULL'

## Details

Each read ID must be a non-missing character string containing a valid
UUID. Duplicate read IDs are not allowed.
