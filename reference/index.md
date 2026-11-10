# Package index

## Package overview

- [`pod5R`](https://lrb-iimcb.github.io/pod5R/reference/pod5R-package.md)
  [`pod5R-package`](https://lrb-iimcb.github.io/pod5R/reference/pod5R-package.md)
  : An R interface to pod5 file format by Oxford Nanopore

## File access

Open and close POD5 readers and inspect file-level information.

- [`open_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/open_pod5.md)
  : Opens POD5 file through the native C API and stores read batch
  boundaries.
- [`close_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/close_pod5.md)
  : Close a native POD5 reader
- [`read_pod5_info()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_info.md)
  : Read POD5 file information

## Reads and sequencing runs

Retrieve read identifiers, read metadata, sequencing run information,
and optional signal data.

- [`read_pod5_ids()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_ids.md)
  : Read POD5 read identifiers
- [`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md)
  : Read POD5 metadata and signals (optionally)
- [`read_pod5_runs()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_runs.md)
  : Read POD5 sequencing run information

## Signal extraction

Extract raw or calibrated signal and map Dorado split reads to intervals
in their parent POD5 signals.

- [`extract_pod5_signal()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md)
  : Extract selected POD5 signal vectors
- [`extract_pod5_signal_dorado()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal_dorado.md)
  : Maps Dorado split-read identifiers back to their original POD5
  parents using explicitly provided SAM/BAM tags. Returns the signal for
  the corresponding basecalled interval in acquisition order.

## Batch processing

Process reads in batches using a supplied function.

- [`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md)
  : Process POD5 reads in groups
