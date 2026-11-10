# Maps Dorado split-read identifiers back to their original POD5 parents using explicitly provided SAM/BAM tags. Returns the signal for the corresponding basecalled interval in acquisition order.

Dorado assigns new UUIDs to split-read children, which are generally not
present in the original POD5 file. The parent read is identified by
`pi`. Using zero-based coordinates, the requested interval starts at
`sp + ts` and ends immediately before `sp + ns`. Its length is therefore
`ns - ts`, rather than `ns`.

## Usage

``` r
extract_pod5_signal_dorado(file, reads, calibrated = FALSE)
```

## Arguments

- file:

  [character](https://rdrr.io/r/base/character.html) or external
  pointer. Path to the original POD5 file, or an open reader.

- reads:

  Data frame. Columns `read_id`, `pi`, `sp`, `ts`, and `ns` are
  required. `read_id` contains unique Dorado query-name UUIDs, while
  `pi` contains parent UUIDs or missing values for unsplit reads.
  Numeric `sp`, `ts`, and `ns` contain the corresponding Dorado SAM/BAM
  tag values. Missing `sp` is permitted only when no parent is
  specified; `ts` and `ns` must always be present.

- calibrated:

  [logical](https://rdrr.io/r/base/logical.html) Defaults to FALSE.
  Return picoamperes instead of ADC counts.

## Value

A list named by canonical lowercase Dorado read UUIDs, preserving input
row order. Raw signal vectors are integer; calibrated vectors are
numeric. Empty intervals return empty vectors of the corresponding type.

## Details

Under the current Dorado SAM specification, `ns` is the end coordinate
after any rear trimming and does not necessarily represent the full
untrimmed child. Do not add the acquisition-level POD5 `start_sample` to
these offsets.

For unsplit reads, set `pi` to `NA_character_` or an empty string, and
`sp` to `NA_real_` or zero. In that case, the POD5 identifier is
`read_id`; the interval starts at `ts` and ends immediately before `ns`.
A `pi` value equal to `read_id` with `sp = 0` is also accepted.

It does not parse BAM files, infer missing tags, reverse RNA or
reverse-strand signals, or support duplex consensus reads. If present,
`dx` must contain only -1 or 0; duplex records with value 1 are
rejected. Supply one row per read rather than repeated alignment
records. A child UUID alone, or a parent identifier without sample
offsets, is insufficient to recover a split-read interval.

## See also

[`extract_pod5_signal`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md),
[`read_pod5`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md),
and
<https://software-docs.nanoporetech.com/dorado/latest/basecaller/sam_spec/>

## Examples

``` r
if (FALSE) { # \dontrun{
# reads contains read_id plus pi, sp, ts, and ns tags obtained from Dorado BAM
signals <- pod5R::extract_pod5_signal_dorado("reads.pod5", reads)
} # }
```
