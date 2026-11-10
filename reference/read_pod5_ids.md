# Read POD5 read identifiers

Retrieves read identifiers in file order without decompressing signals.

## Usage

``` r
read_pod5_ids(file)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer: POD5 path or open native reader

## Value

A character vector of lowercase UUIDs.

## Examples

``` r
if (FALSE) { # \dontrun{
read_ids <- pod5R::read_pod5_ids("reads.pod5")
} # }
```
