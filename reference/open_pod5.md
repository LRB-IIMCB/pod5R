# Opens POD5 file through the native C API and stores read batch boundaries.

The signals are decoded only on demand. Opening visits every read batch
to retrieve boundaries, so the cost grows accordingly to number of
batches. Reuse a reader for repeated queries.

## Usage

``` r
open_pod5(file)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) a path to a given
  POD5 file.

## Value

external pointer containing a native reader.

## Details

Readers own native resources. Use `on.exit(close_pod5(reader))` inside
functions. Garbage collector releases unclosed readers as well. Readers
can't be serialized or shared between R workers. Each worker must open
its own reader. Path inputs to other functions are closed by default.

## Examples

``` r
if (FALSE) { # \dontrun{
reader <- pod5R::open_pod5("example_reads.pod5")
reads <- pod5R::read_pod5(reader)
pod5R::close_pod5(reader)
} # }
```
