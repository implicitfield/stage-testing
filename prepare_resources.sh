#!/bin/sh

set -eu

git clone https://github.com/ungoogled-software/ungoogled-chromium-macos.git
cd ungoogled-chromium-macos

git submodule init
git submodule update

cd ungoogled-chromium
git checkout master
git pull origin
cd ..

mkdir -p build/src
mkdir build/download_cache

./retrieve_and_unpack_resource.sh -d -g arm64

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

cd build/src

python3 build/util/lastchange.py -m DAWN_COMMIT_HASH -s third_party/dawn --revision gpu/webgpu/DAWN_VERSION --header gpu/webgpu/dawn_commit_hash.h

./tools/gn/bootstrap/bootstrap.py -o out/Default/gn --skip-generate-buildfiles
./tools/rust/build_bindgen.py --skip-test

./out/Default/gn gen out/Default --fail-on-unused-args

cd ../../..

tar -c -f - . | zstd -vv -11 -T0 -o resources.tar.zst
