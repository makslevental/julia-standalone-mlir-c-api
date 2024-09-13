#!/bin/bash

set -eux -o errtrace

this_dir="$(cd $(dirname $0) && pwd)"
repo_root="$(cd $this_dir && pwd)"
standalone_dir="$(cd $repo_root/standalone && pwd)"
build_dir="$repo_root/standalone-build"
mkdir -p "$build_dir"
build_dir="$(cd $build_dir && pwd)"
llvm_install_dir="${llvm_install_dir:-}"
cache_dir="${cache_dir:-}"

if [ -z "${cache_dir}" ]; then
  cache_dir="${repo_root}/.build-cache"
  mkdir -p "${cache_dir}"
  cache_dir="$(cd ${cache_dir} && pwd)"
fi
echo "Caching to ${cache_dir}"
mkdir -p "${cache_dir}/ccache"
mkdir -p "${cache_dir}/pip"

python="$(which python)"
echo "Using python: $python"

export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"
export CCACHE_DIR="${cache_dir}/ccache"
export CCACHE_MAXSIZE="700M"
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
export CCACHE_SLOPPINESS=include_file_ctime,include_file_mtime,time_macros

ccache -z

cmake \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH=$llvm_install_dir \
  -DLLVM_EXTERNAL_LIT=$(which lit) \
  -DLLVM_USE_SANITIZER="Address" \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DPython3_EXECUTABLE=$(which python) \
  -DBUILD_SHARED_LIBS=ON \
  -S $standalone_dir -B $build_dir

echo "Building all"
echo "------------"
cmake --build "$build_dir" -- -k 0

echo "Testing"
echo "----------"
cmake --build "$build_dir" --target check-standalone || true

find standalone-build -name *.a
