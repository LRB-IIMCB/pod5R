# Read POD5 file information

Retrieves the metadata (file identifier, format version, read, batch and
counts). The native `file_version` refers to the opened schema and might
reflect the automatic migration and not necessarily the original source
version.

## Usage

``` r
read_pod5_info(file)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer: POD5 path or open native reader

## Value

Named list containing file information

## Details

If 'file' is a character string, the POD5 file is opened internally and
automatically close on function exit. If an existing reader is provided,
it is used directly and is not closed by this function.

An error is raised when 'file' is missing.

## Examples

``` r
if (FALSE) { # \dontrun{
pod5R::read_pod5_info("example_reads.pod5")
} # }
```
