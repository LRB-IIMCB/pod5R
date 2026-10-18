#!/usr/bin/env bash

set -euo pipefail

POD5R_VERSION="0.2.0"
POD5R_ARCHIVE_NAME="pod5R-0.2.0-linux-64-r44-channel.tar.gz"
POD5R_ARCHIVE_SHA256="fae7c19422d8ee7f264a50bd91e38dcbaa87a654cfa41b8e02356fcf0f0c6734"
POD5R_BINARY_NAME="r-pod5r-0.2.0-r44h36d892c_0.conda"
POD5R_BINARY_SHA256="b20c4d58799df9a4ab6f78ff779a1734c4ec200b335b59c8e4905711ae649236"
POD5R_URL="https://github.com/LRB-IIMCB/pod5R/releases/download/v0.2.0/$POD5R_ARCHIVE_NAME"
POD5R_PREFIX="$HOME/.local/share/pod5R/0.2.0-r44"
POD5R_ARCHIVE=""

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            [[ $# -ge 2 ]] || fail "--prefix requires a directory."
            POD5R_PREFIX="$2"
            shift 2
            ;;
        --archive)
            [[ $# -ge 2 ]] || fail "--archive requires a file."
            POD5R_ARCHIVE="$2"
            shift 2
            ;;
        --help|-h)
            printf '%s\n' \
                "Usage: bash install-pod5R.sh [--prefix /absolute/path] [--archive FILE]" \
                "Requires Conda and Linux x86_64." \
                "Without --archive, downloads the versioned GitHub release asset."
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

[[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]] ||
    fail "This installer supports Linux x86_64."

POD5R_PREFIX="${POD5R_PREFIX%/}"
[[ "$POD5R_PREFIX" == /* ]] ||
    fail "Please provide an absolute installation path."

if [[ -e "$POD5R_PREFIX" || -L "$POD5R_PREFIX" ]]; then
    fail "Destination already exists: $POD5R_PREFIX. Choose a new --prefix."
fi

POD5R_CONDA="${CONDA_EXE:-}"
if [[ ! -x "$POD5R_CONDA" ]]; then
    POD5R_CONDA="$(type -P conda || true)"
fi
[[ -x "$POD5R_CONDA" ]] ||
    fail "Conda was not found. Make Conda available in this terminal first."

for tool in tar gzip sha256sum; do
    command -v "$tool" >/dev/null 2>&1 ||
        fail "Required command is missing: $tool"
done

POD5R_CACHE="$POD5R_PREFIX.cache"
POD5R_CHANNEL="$POD5R_CACHE/channel"
mkdir -p "$POD5R_CACHE"

if [[ -z "$POD5R_ARCHIVE" ]]; then
    command -v curl >/dev/null 2>&1 ||
        fail "curl is required to download the release archive."

    POD5R_ARCHIVE="$POD5R_CACHE/$POD5R_ARCHIVE_NAME"

    curl \
        --fail \
        --location \
        --retry 3 \
        --connect-timeout 30 \
        --proto '=https' \
        --proto-redir '=https' \
        --output "$POD5R_ARCHIVE" \
        "$POD5R_URL"
fi

[[ -f "$POD5R_ARCHIVE" ]] ||
    fail "Archive does not exist: $POD5R_ARCHIVE"

printf '%s  %s\n' "$POD5R_ARCHIVE_SHA256" "$POD5R_ARCHIVE" |
    sha256sum --check --status ||
    fail "Archive checksum does not match this release."

printf 'Archive checksum verified.\n'

mkdir -p "$POD5R_CHANNEL"
tar \
    --extract \
    --gzip \
    --file="$POD5R_ARCHIVE" \
    --directory="$POD5R_CHANNEL" \
    --no-same-owner \
    --no-same-permissions

test -s "$POD5R_CHANNEL/linux-64/repodata.json"
test -s "$POD5R_CHANNEL/noarch/repodata.json"

printf '%s  %s\n' \
    "$POD5R_BINARY_SHA256" \
    "$POD5R_CHANNEL/linux-64/$POD5R_BINARY_NAME" |
    sha256sum --check --status ||
    fail "Compiled package checksum does not match this release."

export CONDA_PKGS_DIRS="$POD5R_CACHE/conda-pkgs"
export CONDA_REGISTER_ENVS=false
export CONDA_SUBDIR=linux-64

"$POD5R_CONDA" create \
    --prefix "$POD5R_PREFIX" \
    --override-channels \
    --channel "file://$POD5R_CHANNEL" \
    --channel conda-forge \
    --strict-channel-priority \
    --no-default-packages \
    --yes \
    "r-pod5r=0.2.0=r44h36d892c_0"

"$POD5R_CONDA" run \
    --prefix "$POD5R_PREFIX" \
    --no-capture-output \
    env -u R_HOME -u R_LIBS -u R_LIBS_SITE \
    R_LIBS_USER="$POD5R_PREFIX/lib/R/library" \
    Rscript --vanilla -e '
library(pod5R)

file <- system.file(
  "extdata", "drs-filtered.pod5",
  package = "pod5R", mustWork = TRUE
)

result <- pod5R::read_pod5(file, num_reads = 1, signal = TRUE)
signal <- result$signal[[1]]

if (as.character(utils::packageVersion("pod5R")) != "0.2.0" ||
    !is.integer(signal) ||
    length(signal) == 0L ||
    length(signal) != result$reads$num_samples[1]) {
  stop("Installed package verification failed.", call. = FALSE)
}

cat("Package directory:", find.package("pod5R"), "\n")
cat("Signal samples extracted:", length(signal), "\n")
cat("Installer verification passed.\n")
'

printf '\nInstalled pod5R %s in %s\n' "$POD5R_VERSION" "$POD5R_PREFIX"
printf 'To start R:\n  conda activate %q\n  R\n' "$POD5R_PREFIX"
