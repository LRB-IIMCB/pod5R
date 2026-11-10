# Process POD5 reads in groups

Calls an R function for consecutive groups of reads from a POD5 file or
an existing POD5 reader. Each group is read independently, passed to
`FUN`, and then discarded, allowing large files to be processed
incrementally without retaining all reads in memory at once.

## Usage

``` r
process_pod5(
  file,
  FUN,
  part_size = 1000,
  signal = FALSE,
  calibrated = FALSE,
  verbose = TRUE,
  ...
)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) A path to a POD5
  file or an existing POD5 reader object. Character paths are opened
  internally and automatically closed when the function exits, including
  when `FUN` raises an error. Existing reader objects are used directly
  and are not closed by this function.

- FUN:

  is the R function to run on each group. Receives one metadata data
  frame, or one named list when signal is TRUE. Additional arguments are
  passed through `...`

- part_size:

  [numeric](https://rdrr.io/r/base/numeric.html) A positive whole number
  giving the maximum number of reads processed in each group. The final
  group may contain fewer reads. Defaults to `1000`.

- signal:

  [logical](https://rdrr.io/r/base/logical.html) whether signal data
  should be read for each group. If `FALSE`, only read metadata are
  obtained. If `TRUE`, signal vectors are included in the object passed
  to `FUN`. Defaults to `FALSE`.

- calibrated:

  [logical](https://rdrr.io/r/base/logical.html) whether signal values
  should be returned as calibrated values rather than raw ADC counts.
  This argument is only relevant when `signal = TRUE`. Defaults to
  `FALSE`.

- verbose:

  Logical; whether progress messages should be printed at the start and
  end of processing. Defaults to `TRUE`.

- ...:

  Additional arguments passed to FUN.

## Value

Invisibly returns the number of processed reads. Callback results are
not retained. Callback errors propagate after closing internally opened
files.

## Examples

``` r
if (FALSE) { # \dontrun{
pod5R::process_pod5("reads.pod5", function(reads) {
print(sum(reads$num_samples))
}, part_size = 1000)
} # }
```
