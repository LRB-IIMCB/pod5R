# Read POD5 metadata and signals (optionally)

Captures read metadata with raw or calibrated signal (if requested),
using native indexed selection for given read ids (UUIDs).

## Usage

``` r
read_pod5(
  file,
  read_ids = NULL,
  signal = FALSE,
  calibrated = FALSE,
  start_sample = 1,
  end_sample = Inf,
  first_read = 1,
  num_reads = Inf
)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer: POD5 path or open native reader

- read_ids:

  [character](https://rdrr.io/r/base/character.html) (default: `NULL`).
  Unique read UUIDs. NULL selects by row range.

- signal:

  [logical](https://rdrr.io/r/base/logical.html) (default: `FALSE`).
  Include signal vectors in the returned list.

- calibrated:

  [logical](https://rdrr.io/r/base/logical.html) (default: `FALSE`).
  Return signal in picoampers instead of ADC counts.

- start_sample:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `1`). First
  signal sample, one-based and inclusive.

- end_sample:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `Inf`). Last
  signal sample, one-based and inclusive.

- first_read:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `1`). First
  read in file order, one-based.

- num_reads:

  [numeric](https://rdrr.io/r/base/numeric.html) (default: `Inf`).
  Maximum number of reads. Cannot be combined with read_ids unless
  first_read and num_reads retain their defaults.

## Value

If signal is FALSE, a plain metadata data frame. Otherwise, a named list
with `reads` (metadata) and `signal` (vectors named by UUID). Raw
signals are integer vectors. Calibrated signals are numeric vectors.

## Details

Read identifiers are returned in requested order. Missing identifiers
and duplicate selections throw errors. Without identifiers, reads follow
file order. Metadata access alone never decompresses signal data. Sample
intervals use R coordinates: one-based and inclusive. Bounds beyond a
read are clipped; a start beyond the read yields an empty vector. Only
overlapping compressed chunks are decoded. Universal interval applies to
all selected reads. When a file contains repeated UUIDs, indexed
selection returns one occurrence chosen by the native library. Use row
ranges or
[`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md)
to get every occurrence.

Read `start_sample` retains its original zero-based acquisition
coordinate. Signal orientation remains acquisition order. Calibration is
`(raw_signal + calibration_offset) * calibration_scale` in picoamperes.

Output memory grows with selected reads and samples. Use
[`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md)
for bounded read groups. Native file mapping and the POD5 chunk cache
also consume memory. Opening a reader caches batch boundaries, not
signal vectors.

Dorado split children have new UUIDs that are not stored in original
POD5 file. Use
[`extract_pod5_signal_dorado()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal_dorado.md)
with parent and sample tags from Dorado SAM/BAM to extract their signal
intervals.

## See also

[`extract_pod5_signal`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md)

## Examples

``` r
if (FALSE) { # \dontrun{
reads <- pod5R::read_pod5("reads.pod5")
out <- pod5R::read_pod5("reads.pod5", read_ids = reads$read_id[1:5],
signal = TRUE, calibrated = TRUE)
} # }
```
