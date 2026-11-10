# Get started with pod5R

**pod5R** reads POD5 files produced by Oxford Nanopore sequencing
devices, using the native POD5 C API. Read metadata, sequencing run
information, and raw or calibrated signals are returned as ordinary R
data frames, lists, and vectors. Python, reticulate, and the R Arrow
package are not needed.

This vignette gives a short overview of the main functions. Signal
extraction and plotting are covered in
[`vignette("signal_extraction")`](https://lrb-iimcb.github.io/pod5R/articles/signal_extraction.md),
and plotting of many reads in
[`vignette("batch_plotting")`](https://lrb-iimcb.github.io/pod5R/articles/batch_plotting.md).
Installation instructions can be found in the
[README](https://github.com/LRB-IIMCB/pod5R#installation).

> **Note:** pod5R provides read-only access. It does not write POD5
> files, segment the signal, or perform basecalling.

## Example data

All examples use a small toy direct RNA sequencing (DRS) file provided
with the package. The same calls work for any POD5 file.

``` r
pod5_file <- system.file("extdata", "drs-filtered.pod5",
                         package = "pod5R", mustWork = TRUE)
```

## File information

[`read_pod5_info()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_info.md)
returns file-level information: the file identifier, the format version,
and the number of reads, batches, and runs.

``` r
pod5R::read_pod5_info(pod5_file)
## $file_identifier
## [1] "226b4f4e-e309-4e72-9320-6e9877e20700"
## 
## $file_version
## [1] "0.3.46"
## 
## $num_reads
## [1] 42
## 
## $num_batches
## [1] 1
## 
## $num_runs
## [1] 1
```

## Read identifiers

[`read_pod5_ids()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_ids.md)
returns read identifiers (UUIDs) in file order. No signal data are
decompressed at this step.

``` r
read_ids <- pod5R::read_pod5_ids(pod5_file)

length(read_ids)
## [1] 42
head(read_ids, 3)
## [1] "0e8e52dc-3a71-4c33-9a00-e1209ba4d2e9"
## [2] "e6508401-c6a5-44be-ae64-455e982022ba"
## [3] "a7352eb3-9f1f-41e5-a63c-23cf76565a21"
```

## Read metadata

[`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md)
returns one row of metadata per read. Unless `signal = TRUE` is set, the
signal data are not decompressed, so even large files are scanned
quickly.

``` r
reads <- pod5R::read_pod5(pod5_file)

head(reads[, c("read_id", "num_samples", "sample_rate", "end_reason")], 3)
##                                read_id num_samples sample_rate      end_reason
## 1 0e8e52dc-3a71-4c33-9a00-e1209ba4d2e9       21908        4000 signal_positive
## 2 e6508401-c6a5-44be-ae64-455e982022ba       23300        4000 signal_positive
## 3 a7352eb3-9f1f-41e5-a63c-23cf76565a21       20462        4000 signal_positive
```

Run-level information, such as the flow cell, kit, and sample rate, are
available through
[`read_pod5_runs()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_runs.md):

``` r
runs <- pod5R::read_pod5_runs(pod5_file)

names(runs)
## [1] "391b92d03250a11489e23f5087d0e7660b791a95"
```

## Signal

[`extract_pod5_signal()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md)
returns a list of signal vectors named by read UUID. Raw signals are
integer ADC counts. With `calibrated = TRUE`, the signals are returned
in picoamperes (pA) instead.

``` r
signal_list <- pod5R::extract_pod5_signal(pod5_file,
                                          read_ids = read_ids[1],
                                          calibrated = TRUE)

str(signal_list)
## List of 1
##  $ 0e8e52dc-3a71-4c33-9a00-e1209ba4d2e9: num [1:21908] 48.3 51.3 51.1 53.9 51.5 ...
```

## Reusing a reader

Every call with a file path opens and closes the file. Since opening
visits every read batch, it is recommended to open a reader once with
[`open_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/open_pod5.md)
when several calls are made on the same file, reusing it, and closing it
with
[`close_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/close_pod5.md)
at the end. Be aware that readers cannot be shared between parallel R
workers, each worker should open its own reader.

``` r
reader <- pod5R::open_pod5(pod5_file)

n_reads <- pod5R::read_pod5_info(reader)$num_reads
first_signal <- pod5R::extract_pod5_signal(reader, read_ids = read_ids[1])

pod5R::close_pod5(reader)

n_reads
## [1] 42
length(first_signal[[1]])
## [1] 21908
```

## Next steps

| Topic | Vignette |
|----|----|
| Signal extraction, intervals, calibration, and plotting of single reads | [`vignette("signal_extraction")`](https://lrb-iimcb.github.io/pod5R/articles/signal_extraction.md) |
| Plotting many reads in one figure or one file per read | [`vignette("batch_plotting")`](https://lrb-iimcb.github.io/pod5R/articles/batch_plotting.md) |

| Function | Description |
|----|----|
| [`read_pod5_info()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_info.md) | File-level information |
| [`read_pod5_ids()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_ids.md) | Read identifiers in file order |
| [`read_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5.md) | Read metadata; signal with `signal = TRUE` |
| [`read_pod5_runs()`](https://lrb-iimcb.github.io/pod5R/reference/read_pod5_runs.md) | Sequencing run information |
| [`extract_pod5_signal()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal.md) | Raw or calibrated signal vectors |
| [`extract_pod5_signal_dorado()`](https://lrb-iimcb.github.io/pod5R/reference/extract_pod5_signal_dorado.md) | Signal intervals of Dorado split reads |
| [`process_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/process_pod5.md) | Processing of reads in groups |
| [`open_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/open_pod5.md) / [`close_pod5()`](https://lrb-iimcb.github.io/pod5R/reference/close_pod5.md) | Opening and closing of a reusable reader |
