#!/usr/bin/env bash

# do not execute this file as child process!!!
# shell must support conda activate

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file from Bash: source tools/activate.sh" >&2
  exit 1
fi

if ! declare -F conda >/dev/null; then
  echo "Open bash shell where conda is initialized, then source this file.">&2
  return 1
fi


export POD5R_PROJECT="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd
)"

export CONDA_PKGS_DIRS="$POD5R_PROJECT/.local/conda-pkgs"
export CONDA_ENVS_PATH="$POD5R_PROJECT/.local/conda-envs"
export CONDA_REGISTER_ENVS=false
export CONDARC="$POD5R_PROJECT/tools/condarc"
export CONAN_HOME="$POD5R_PROJECT/.local/conan"
export XDG_CACHE_HOME="$POD5R_PROJECT/.local/cache"
export PIP_CACHE_DIR="$POD5R_PROJECT/.local/cache/pip"
export TMPDIR="$POD5R_PROJECT/.local/tmp"
export PYTHONNOUSERSITE=1
export R_LIBS_USER="$POD5R_PROJECT/.local/r-library"
export POD5_ROOT="$POD5R_PROJECT/native"
export CMAKE_BUILD_PARALLEL_LEVEL=2


mkdir -p "$TMPDIR" "$R_LIBS_USER"

conda activate "$POD5R_PROJECT/.local/toolchain" || return 1

export CC="$(command -v x86_64-conda-linux-gnu-cc)"
export CXX="$(command -v x86_64-conda-linux-gnu-c++)"
export FC="$(command -v x86_64-conda-linux-gnu-gfortran)"

export R_MAKEVARS_USER="$POD5R_PROJECT/.local/Makevars.user"

cat > "$R_MAKEVARS_USER" <<EOF
CC = $CC
CXX = $CXX
CXX17 = $CXX
CXX20 = $CXX
FC = $FC
F77 = $FC
EOF
