#!/bin/bash

set -eux -o errtrace

this_dir="$(cd $(dirname $0) && pwd)"
repo_root="$(cd $this_dir && pwd)"
llvm_dir="$(cd $repo_root/llvm-project/llvm && pwd)"
build_dir="$repo_root/llvm-build"
install_dir="$repo_root/llvm-install"
mkdir -p "$build_dir"
build_dir="$(cd $build_dir && pwd)"
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
# export CCACHE_COMPILERCHECK="string:$(clang --version)"
export CCACHE_DIR="${cache_dir}/ccache"
export CCACHE_MAXSIZE="700M"
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
export CCACHE_SLOPPINESS=include_file_ctime,include_file_mtime,time_macros

ccache -p
ccache -z

cmake \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=$install_dir \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_ENABLE_LIBEDIT=OFF \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=ON \
  -DMLIR_INCLUDE_TESTS=ON \
  -DLLVM_USE_SANITIZER="Address" \
  -DLLVM_TARGETS_TO_BUILD=X86 \
  -DLLVM_TARGET_ARCH=X86 \
  -DLLVM_BUILD_UTILS=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
  -DPython3_EXECUTABLE=$(which python) \
  \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DMLIR_BUILD_MLIR_C_DYLIB=ON \
  -DMLIR_LINK_MLIR_DYLIB=ON \
  \
  -S $llvm_dir -B $build_dir

echo "Building all"
echo "------------"
cmake --build "$build_dir" -- -k 1

echo "Installing"
echo "----------"
echo "Install to: $install_dir"
cmake --build "$build_dir" --target install


echo "Testing"
echo "----------"
cmake --build "$build_dir" --target check-mlir || true

ccache -s
