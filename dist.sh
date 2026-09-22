#!/bin/sh
set -e

cd "$(dirname "$0")"
FINAL_FILE="zoom-platform.sh"

# doZennn/innoextract (the ZOOM-patched fork this script depends on for --zoom-game-id
# and --print-headers) hasn't cut a GitHub Release since v1.11.1 (2024-03-03), which only
# understands Inno Setup installers up to 6.2.2. Real ZOOM Platform installers already
# ship with newer Inno Setup versions (e.g. e-Racer's is 6.6.0), so that release binary
# fails --zoom-game-id on them and the script wrongly reports "doesn't seem to be a ZOOM
# Platform installer". We maintain our own fork (DarthSidiousPT/innoextract, forked from
# doZennn at the commit below) so we control when fixes land instead of waiting on
# upstream's release cadence. Build from a pinned commit instead of downloading a release
# tarball; bump INNOEXTRACT_COMMIT after verifying a newer commit against real installers.
INNOEXTRACT_COMMIT=0c5962cabf10a2105d9c2bc60d6a96524c55b1f3

rm -rf innoextract-src innoextract-build innoextract-upx
git clone -q https://github.com/DarthSidiousPT/innoextract.git innoextract-src
git -C innoextract-src checkout -q "$INNOEXTRACT_COMMIT"

cmake -S innoextract-src -B innoextract-build -DCMAKE_BUILD_TYPE=Release
cmake --build innoextract-build --target innoextract -- -j"$(nproc)"

cp innoextract-build/innoextract innoextract-upx
# Best-effort: keep the embedded binary small like the old prebuilt release did.
# Not fatal if upx isn't installed, just embeds a slightly larger base64 blob.
command -v upx > /dev/null 2>&1 && upx -q --best innoextract-upx

./build.sh "src.sh" "innoextract-upx" > "$FINAL_FILE"
