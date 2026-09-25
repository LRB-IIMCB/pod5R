#!/usr/bin/env bash

set -euo pipefail

cd "${POD5R_PROJECT:?Set POD5R_PROJECT first}"
: "${POD5_ROOT:?Set POD5_ROOT first}"
: "${R_LIBS_USER:?Activate the project environment first}"

Rscript - <<'RSCRIPT'
project <- Sys.getenv("POD5R_PROJECT")
Rcpp::compileAttributes(project)
roxygen2::roxygenize(
  package.dir = project,
  roclets = c("rd", "namespace"),
  load_code = roxygen2::load_source
)
RSCRIPT

R CMD INSTALL --preclean --library="$R_LIBS_USER" "$POD5R_PROJECT"
