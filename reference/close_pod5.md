# Close a native POD5 reader

Closes an open POD5 reader and releases the resources. Closing the same
reader repeatedly is safe. An error is raised when 'reader' is missing.

## Usage

``` r
close_pod5(reader)
```

## Arguments

- reader:

  A pod5 reader to close - external pointer returned by
  [`open_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/open_pod5.md)

## Value

invisibly returns `NULL`

## Examples

``` r
if (FALSE) { # \dontrun{
reader <- pod5R::open_pod5("example_reads.pod5")
pod5R::close_pod5(reader)
} # }
```
