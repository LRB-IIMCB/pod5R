#!/usr/bin/env bash
set -euo pipefail

# These variables must be supplied by conda-build.
: "${SRC_DIR:?Run this script through conda-build}"
: "${PREFIX:?Missing Conda host prefix}"
: "${BUILD_PREFIX:?Missing Conda build prefix}"
: "${RECIPE_DIR:?Missing recipe directory}"
: "${CONDA_BUILD_SYSROOT:?Missing compiler sysroot}"
: "${CC:?Missing C compiler}"
: "${CXX:?Missing C++ compiler}"

POD5R_SOURCE="$SRC_DIR/r-package"
POD5R_NATIVE_SOURCE="$SRC_DIR/pod5-format"
POD5R_NATIVE_BUILD="$SRC_DIR/native-build"
POD5R_GENERATORS="$SRC_DIR/native-generators"
POD5R_DEPLOY="$SRC_DIR/native-dependencies"
POD5R_DEPENDENCIES="$POD5R_DEPLOY/full_deploy/host"

export POD5_ROOT="$SRC_DIR/native-install"
export CONAN_HOME="$SRC_DIR/conan-cache"
export XDG_CACHE_HOME="$SRC_DIR/cache"
export TMPDIR="$SRC_DIR/tmp"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export PYTHONNOUSERSITE=1
export CMAKE_BUILD_PARALLEL_LEVEL=2
export MAKEFLAGS="-j2"

mkdir -p \
    "$CONAN_HOME" \
    "$XDG_CACHE_HOME" \
    "$TMPDIR" \
    "$POD5R_NATIVE_BUILD/pod5_conan_licenses" \
    "$SRC_DIR/native-licenses"

test -f "$POD5R_SOURCE/DESCRIPTION"
test -f "$POD5R_SOURCE/tools/locks/native.lock"
test -d "$CONDA_BUILD_SYSROOT"

printf 'C compiler: %s\n' "$CC"
printf 'C++ compiler: %s\n' "$CXX"
printf 'Compiler sysroot: %s\n' "$CONDA_BUILD_SYSROOT"

"$CC" --version
"$CXX" --version

# Verify that the POD5 checkout matches the package's recorded revision.
POD5R_EXPECTED_COMMIT="$(
    tr -d '\r\n' < "$POD5R_SOURCE/tools/locks/pod5-source-commit.txt"
)"

POD5R_ACTUAL_COMMIT="$(
    git -C "$POD5R_NATIVE_SOURCE" rev-parse HEAD
)"

if [[ "$POD5R_ACTUAL_COMMIT" != "$POD5R_EXPECTED_COMMIT" ]]; then
    printf 'POD5 source revision does not match the recorded revision.\n' >&2
    exit 1
fi

# Generate POD5's version files without building its Python package.
(
    cd "$POD5R_NATIVE_SOURCE"

    SETUPTOOLS_SCM_PRETEND_VERSION=0.3.47 \
        "$BUILD_PREFIX/bin/python" -m setuptools_scm

    "$BUILD_PREFIX/bin/python" pod5_make_version.py
)

# Build the locked native dependencies from source.
"$BUILD_PREFIX/bin/conan" install \
    "$POD5R_SOURCE/tools/native" \
    --profile:host "$RECIPE_DIR/linux-conda" \
    --profile:build "$RECIPE_DIR/linux-conda" \
    --lockfile "$POD5R_SOURCE/tools/locks/native.lock" \
    --output-folder "$POD5R_GENERATORS" \
    --deployer full_deploy \
    --deployer-folder "$POD5R_DEPLOY" \
    --build='*'

POD5R_FLATC="$POD5R_DEPENDENCIES/flatbuffers/2.0.8/Release/x86_64/bin/flatc"

test -x "$POD5R_FLATC"
"$POD5R_FLATC" --version

# Compile the static POD5 library using the deployed dependencies.
"$BUILD_PREFIX/bin/cmake" \
    -S "$POD5R_NATIVE_SOURCE" \
    -B "$POD5R_NATIVE_BUILD" \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$POD5R_GENERATORS/conan_toolchain.cmake" \
    -DCMAKE_SYSROOT="$CONDA_BUILD_SYSROOT" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$POD5_ROOT" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
    -DENABLE_CONAN=OFF \
    -DCONAN2=ON \
    -DBUILD_SHARED_LIB=OFF \
    -DBUILD_PYTHON_WHEEL=OFF \
    -DPOD5_DISABLE_TESTS=ON \
    -DPOD5_BUILD_EXAMPLES=OFF \
    -DENABLE_POD5_PACKAGING=OFF \
    -DDISABLE_CCACHE=ON \
    -DDISABLE_DEBUG_SYMBOLS=ON \
    -DFLATBUFFERS_FLATC_EXECUTABLE="$POD5R_FLATC"

"$BUILD_PREFIX/bin/cmake" \
    --build "$POD5R_NATIVE_BUILD" \
    --parallel 2

"$BUILD_PREFIX/bin/cmake" \
    --install "$POD5R_NATIVE_BUILD"

# Assemble the static libraries expected by the R package's configure script.
cp \
    "$POD5R_DEPENDENCIES/arrow/18.0.0/Release/x86_64/lib/libarrow.a" \
    "$POD5_ROOT/lib/"

cp \
    "$POD5R_DEPENDENCIES/zstd/1.5.7/Release/x86_64/lib/libzstd.a" \
    "$POD5_ROOT/lib/"

cp \
    "$POD5R_DEPENDENCIES/zlib/1.3.1/Release/x86_64/lib/libz.a" \
    "$POD5_ROOT/lib/"

# Collect POD5 and dependency licences for the Conda package.
mkdir -p "$SRC_DIR/native-licenses/pod5"

cp -a \
    "$POD5_ROOT/licenses/." \
    "$SRC_DIR/native-licenses/pod5/"

while IFS= read -r -d '' license_dir; do
    relative_dir="${license_dir#"$POD5R_DEPENDENCIES"/}"
    destination="$SRC_DIR/native-licenses/dependencies/$relative_dir"

    mkdir -p "$destination"
    cp -a "$license_dir/." "$destination/"
done < <(
    find "$POD5R_DEPENDENCIES" -type d -name licenses -print0
)

# Keep personal R settings out of the package build.
export R_ENVIRON_USER=/dev/null
export R_PROFILE_USER=/dev/null
export R_MAKEVARS_SITE=/dev/null
export R_MAKEVARS_USER="$SRC_DIR/Makevars.conda"
export R_LIBS="$PREFIX/lib/R/library"
export R_LIBS_USER="$PREFIX/lib/R/library"

# Use Conda's compiler and sysroot for the Rcpp interface.
cat > "$R_MAKEVARS_USER" <<EOF
CC = ${CC}
CXX = ${CXX}
CXX17 = ${CXX}
CXX17STD = -std=gnu++17
CFLAGS = ${CFLAGS:-} --sysroot=${CONDA_BUILD_SYSROOT}
CXXFLAGS = ${CXXFLAGS:-} --sysroot=${CONDA_BUILD_SYSROOT}
CXX17FLAGS = ${CXXFLAGS:-} --sysroot=${CONDA_BUILD_SYSROOT}
CPPFLAGS = ${CPPFLAGS:-}
LDFLAGS = ${LDFLAGS:-} --sysroot=${CONDA_BUILD_SYSROOT}
EOF

mkdir -p "$PREFIX/lib/R/library"

"$PREFIX/bin/R" CMD INSTALL \
    --preclean \
    --library="$PREFIX/lib/R/library" \
    "$POD5R_SOURCE"

test -s "$PREFIX/lib/R/library/pod5R/libs/pod5R.so"
