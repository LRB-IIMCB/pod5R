<img src="https://img.shields.io/badge/maintained-yes-612a78" alt="maintained - yes">


# pod5R

**An R interface to POD5 file format by Oxford Nanopore Technologies**

## Introduction

**pod5R** reads POD5 files through Oxford Nanopore's native C API, using a small
Rcpp interface. It returns ordinary R data frames, named lists, and signal vectors.
Reading files does not require Python, reticulate, or the R Arrow package.

The native implementation handles the Arrow-based file structure, compressed
signals, indexed UUID lookup, and format migration. Reusing this implementation
avoids maintaining a separate parser and decompressor entirely in R. The R layer
provides argument validation, read selection, calibration, and signal extraction.

The package provides read access. It does not write POD5 files or perform
basecalling.

The software is still under active development. All suggestions for improvement
are welcome. Please note that the code may change frequently, so use it with caution.


## Troubleshooting

If you encounter a bug, please open an issue on GitHub. To help diagnose the problem, provide a minimal reproducible example, so the error can be reproduced and fixed.


## Maintainer

Any issues regarding **pod5R** should be addressed to Natalia Gumińska (nguminska (at) iimcb.gov.pl).

**pod5R** was developed in the <a href="https://www.iimcb.gov.pl/en/research/41-laboratory-of-rna-biology-era-chairs-group">Laboratory of RNA Biology</a> (Dziembowski Lab) at the <a href="https://www.iimcb.gov.pl/en/">International Institute of Molecular and Cell Biology</a> in Warsaw.
