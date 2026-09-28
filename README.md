# pod5R

**An R interface to POD5 file format by Oxford Nanopore Technologies**

## Introduction

**pod5R** reads Oxford Nanopore POD5 files and returns read metadata, run information, and signal vectors in ordinary R objects. 
Reading files does not require Python, reticulate, or the R Arrow package.

The package supports:

- Reading file information, read identifiers, and sequencing run metadata.
- Selecting reads by UUID or their position in the file.
- Extracting raw signal or calibrated current in picoamperes.
- Extracting selected signal intervals.
- Processing large files in groups of reads.
- Extracting signal for Dorado split reads using parent identifiers and sample coordinates.

The package provides read access. It does not write POD5 files or perform basecalling.

The software is still under active development. All suggestions for improvement are welcome. 
Please note that the code may change frequently, so use it with caution.

## Installation

### Requirements

The precompiled release is available for **Linux x86_64** and installs **R 4.4** in a separate Conda environment.

The installer requires:

- Conda available in the terminal.
- An internet connection to GitHub and conda-forge.
- The commands `curl`, `tar`, `gzip`, and `sha256sum`.
- A writable installation directory.

The binary targets glibc 2.28 or newer. Installation has been tested with glibc 2.39. 
Compatibility with older supported systems has not yet been verified. 
This binary is not intended for native Windows, macOS, or ARM systems.

If Conda is not installed, follow the official [Miniforge installation instructions](https://github.com/conda-forge/miniforge#install). 
An existing Conda installation can also be used.

No compiler, separate POD5 installation, or administrator privileges are required for the precompiled installation in your home directory.

### Install the package

Run the following commands in a Linux terminal, not in the R console:

```bash
curl --fail --location \
  --output install-pod5R.sh \
  https://github.com/LRB-IIMCB/pod5R/releases/download/v0.1.0/install-pod5R.sh &&
bash install-pod5R.sh
```

The installer downloads the precompiled package, verifies the archive and package checksums, 
installs the required dependencies, and checks signal extraction using a bundled POD5 file.

By default, the environment is installed in:

```text
~/.local/share/pod5R/0.1.0-r44
```

The installer creates a separate environment. It does not replace system R, modify installed environment modules, or edit shell startup files.

To use a different location, provide a new absolute path:

```bash
bash install-pod5R.sh --prefix /absolute/path/to/pod5R-environment
```

The destination must not already exist.

### Start R with pod5R

For the default installation, run:

```bash
conda activate "$HOME/.local/share/pod5R/0.1.0-r44"
R
```

If a custom installation directory was used, activate that directory instead.

In R, check that the package loads:

```r
library(pod5R)
utils::packageVersion("pod5R")
```

Activate the environment whenever starting a new terminal session to work with this installation. 
See the [Conda environment documentation](https://docs.conda.io/projects/conda/en/stable/user-guide/tasks/manage-environments.html) for further information.

The package is installed for the R version inside this environment. 
An existing RStudio or RStudio Workbench session will not automatically switch to that R installation. 
Tt must be configured to use the environment's R executable.

## General usage

### Choose a POD5 file

The following examples use a small POD5 file included with the package:

```r
file <- system.file(
  "extdata",
  "drs-filtered.pod5",
  package = "pod5R",
  mustWork = TRUE
)
```

To work with your own data, replace this with the file path:

```r
file <- "/path/to/reads.pod5"
```

### Read metadata

Read basic file information:

```r
file_info <- pod5R::read_pod5_info(file)
print(file_info)
```

Read metadata for the first five reads:

```r
reads <- pod5R::read_pod5(file, num_reads = 5)
print(reads)
```

Signal data are not loaded unless requested.

Read the UUIDs stored in the file and the sequencing run information:

```r
read_ids <- pod5R::read_pod5_ids(file)
utils::head(read_ids)

runs <- pod5R::read_pod5_runs(file)
utils::str(runs, max.level = 2)
```

### Extract and plot a signal

Read the first read with calibrated signal:

```r
result <- pod5R::read_pod5(
  file,
  num_reads = 1,
  signal = TRUE,
  calibrated = TRUE
)

signal <- result$signal[[1]]

graphics::plot(
  x = seq_along(signal),
  y = signal,
  type = "l",
  col = "#3a414d",
  xlab = "sample",
  ylab = "signal [pA]",
  main = result$reads$read_id[1]
)
```

The result contains two components:

- `reads`: a data frame containing metadata for the selected reads.
- `signal`: a list of signal vectors named by read UUID.

Use `calibrated = FALSE` to obtain raw integer ADC counts instead of current in picoamperes.

Signals are returned in acquisition order.

### Select reads by UUID

Select the first two UUIDs from the file:

```r
read_ids <- pod5R::read_pod5_ids(file)
selected_ids <- utils::head(read_ids, 2)

selected <- pod5R::read_pod5(
  file,
  read_ids = selected_ids,
  signal = TRUE
)
```

When selecting by UUID, leave `first_read` and `num_reads` at their defaults. 
Missing UUIDs and duplicate identifiers in the selection cause an error.

### Extract a signal interval

Extract samples 101 through 500 from one read:

```r
signals <- pod5R::extract_pod5_signal(
  file,
  read_ids = selected_ids[1],
  start_sample = 101,
  end_sample = 500,
  calibrated = TRUE
)

signal_interval <- signals[[1]]
```

Sample coordinates are one-based and inclusive, following R indexing. The interval above contains up to 400 samples. 
Intervals extending beyond the read are clipped.

### Process large files in groups

Use `process_pod5()` to process consecutive groups without keeping all reads in memory:

```r
pod5R::process_pod5(
  file,
  FUN = function(reads) {
    cat(
      "Reads:", nrow(reads),
      "| Signal samples:", sum(reads$num_samples),
      "\n"
    )
  },
  part_size = 1000,
  signal = FALSE
)
```

With `signal = FALSE`, the callback receives a metadata data frame. With `signal = TRUE`, it receives a list containing `reads` and `signal`.

Callback return values are not collected. Save any required results inside the callback. 
Memory use depends on the number and length of reads in each group.

### Work with Dorado split reads

Dorado split-read UUIDs generally differ from the UUIDs stored in the original POD5 file. 
Selecting a split child UUID directly with `read_pod5()` is therefore insufficient.

Use `extract_pod5_signal_dorado()` with a data frame containing one row per Dorado read and the following columns:

| column | description |
|---|---|
| `read_id` | Dorado read UUID from the SAM/BAM query name |
| `pi` | Parent POD5 read UUID |
| `sp` | Split-read start coordinate within the parent signal |
| `ts` | Number of signal samples trimmed from the start |
| `ns` | End coordinate of the signal interval used for basecalling |

The tag definitions are described in the [Dorado SAM specification](https://software-docs.nanoporetech.com/dorado/latest/basecaller/sam_spec/).

After preparing this data frame as `dorado_reads`:

```r
signals <- pod5R::extract_pod5_signal_dorado(
  file,
  reads = dorado_reads,
  calibrated = TRUE
)
```

Supply the original tag values. The function handles their conversion to R sample coordinates.

This function does not read BAM files directly or reconstruct missing tags. Duplex consensus reads are not supported.

For the full input requirements, including unsplit reads, see:

```r
help("extract_pod5_signal_dorado", package = "pod5R")
```

## Function reference

| function | purpose |
|---|---|
| `open_pod5()` | Open a reusable POD5 reader |
| `close_pod5()` | Close a reader opened explicitly |
| `read_pod5_info()` | Read file information |
| `read_pod5_ids()` | Read UUIDs stored in the file |
| `read_pod5_runs()` | Read sequencing run information |
| `read_pod5()` | Read metadata and optional signal |
| `extract_pod5_signal()` | Extract signal vectors or intervals |
| `extract_pod5_signal_dorado()` | Extract signal using Dorado read and parent metadata |
| `process_pod5()` | Process consecutive groups of reads |

Functions accepting a file path open and close the file internally. If a reader is opened explicitly with `open_pod5()`, close it with `close_pod5()` when finished.

Detailed help is available from R:

```r
help(package = "pod5R")
```

## Troubleshooting

### R reports that pod5R is not installed

Check that R was started from the Conda environment containing the package:

```bash
conda activate "$HOME/.local/share/pod5R/0.1.0-r44"
R
```

For a custom installation, use its actual environment path.

Within R, inspect the current installation and library paths:

```r
R.home()
.libPaths()
```

A package installed in the Conda environment is not automatically available to a different R installation.

### The installer reports that the destination already exists

If the earlier installation succeeded, activate the existing environment. To create another installation, provide a new directory with `--prefix`.

### A read UUID cannot be found

Check that the UUID belongs to the selected POD5 file. For Dorado split reads, use `extract_pod5_signal_dorado()` with the parent identifier and required sample tags.

### Reading signals uses too much memory

Select fewer reads, restrict the signal interval, or use `process_pod5()` with a smaller `part_size`. 
Reading metadata alone does not load signal vectors.

### Reporting a problem

Please open an [issue on GitHub](https://github.com/LRB-IIMCB/pod5R/issues). 
Include the command that failed, the complete error message, and a minimal reproducible example.

For R errors, include:

```r
utils::sessionInfo()
```

## Maintainer

Any issues regarding **pod5R** should be addressed to Natalia Gumińska (nguminska (at) iimcb.gov.pl).

**pod5R** was developed in the [Laboratory of RNA Biology](https://www.iimcb.gov.pl/en/research/41-laboratory-of-rna-biology-era-chairs-group) (Dziembowski Lab) 
at the [International Institute of Molecular and Cell Biology](https://www.iimcb.gov.pl/en/) in Warsaw.
