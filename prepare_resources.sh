#!/bin/sh

set -eu

echo "::group::Fetch and prepare repositories"
git clone https://github.com/ungoogled-software/ungoogled-chromium-macos.git
cd ungoogled-chromium-macos

git submodule init
git submodule update

cd ungoogled-chromium
git checkout master
git pull origin
cd ..

gsed '$ d' -i patches/series

mkdir -p build/src
mkdir build/download_cache
echo "::endgroup::"

echo "::group::Fetch sources"
./retrieve_and_unpack_resource.sh -d -g arm64
echo "::endgroup::"

echo "::group::Apply patches with quilt"
./devutils/update_patches.sh merge
alias quilt='quilt --quiltrc -'
PLATFORM_ROOT="$PWD"
export QUILT_PATCHES="$PLATFORM_ROOT/patches"
export QUILT_SERIES="series.merged"
export QUILT_PUSH_ARGS="--color=auto"
export QUILT_DIFF_OPTS="--show-c-function"
export QUILT_PATCH_OPTS="--unified --reject-format=unified"
export QUILT_DIFF_ARGS="-p ab --no-timestamps --no-index --color=auto"
export QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
export QUILT_COLORS="diff_hdr=1;32:diff_add=1;34:diff_rem=1;31:diff_hunk=1;33:diff_ctx=35:diff_cctx=33"
export QUILT_SERIES_ARGS="--color=auto"
export QUILT_PATCHES_ARGS="--color=auto"
export LESS=""
export QUILT_PAGER="less -FRX"
cd build/src
quilt push -a --refresh
echo "::endgroup::"
echo "::group::Remove patches"
quilt pop -a
cd ../..
./devutils/update_patches.sh unmerge
git checkout HEAD -- patches/series
echo "::endgroup::"

echo "::group::Repository diff"
git --no-pager diff
echo "::endgroup::"

git reset --hard

echo "::group::Prepare source tree"
gsed '$ d' -i patches/series

mkdir -p build/src/out/Default

python3 ungoogled-chromium/utils/prune_binaries.py build/src ungoogled-chromium/pruning.list
python3 ungoogled-chromium/utils/patches.py apply build/src ungoogled-chromium/patches patches
python3 ungoogled-chromium/utils/domain_substitution.py apply -r ungoogled-chromium/domain_regex.list -f ungoogled-chromium/domain_substitution.list build/src

mkdir -p build/src/third_party/llvm-build/Release+Asserts
mkdir -p build/src/third_party/rust-toolchain/bin

./retrieve_and_unpack_resource.sh -p arm64

rm -rf build/download_cache

cp ungoogled-chromium/flags.gn build/src/out/Default/args.gn
cat flags.macos.gn >> build/src/out/Default/args.gn
echo "enable_precompiled_headers=true" >> build/src/out/Default/args.gn
echo "::endgroup::"

echo "::group::Prepare for stage 1"
cd build/src

./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
./tools/rust/build_bindgen.py --skip-test

./out/Default/gn gen out/Default --fail-on-unused-args

cd ../../..

tar -c -f - . | zstd -vv -11 -T0 -o resources.tar.zst
echo "::endgroup::"
