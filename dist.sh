#!/bin/sh
set -e

cd "$(dirname "$0")"
FINAL_FILE="zoom-platform.sh"

# doZennn/innoextract (the ZOOM-patched fork this script depends on for --zoom-game-id
# and --print-headers) hasn't cut a GitHub Release since v1.11.1 (2024-03-03), which only
# understands Inno Setup installers up to 6.2.2. Real ZOOM Platform installers already
# ship with newer Inno Setup versions (e.g. e-Racer's is 6.6.0), so that release binary
# fails --zoom-game-id on them and the script wrongly reports "doesn't seem to be a ZOOM
# Platform installer". We maintain our own fork (DarthSidiousPT/innoextract) with its own
# release pipeline (tags darth-<version>, e.g. darth-1.11-zoom.1) so we control when fixes
# land instead of waiting on upstream's release cadence. Pin a specific release tag here;
# bump INNOEXTRACT_TAG after verifying a newer release against real installers.
INNOEXTRACT_TAG=darth-1.11-zoom.1
INNOEXTRACT_URL="https://github.com/DarthSidiousPT/innoextract/releases/download/${INNOEXTRACT_TAG}/innoextract-upx.tar.gz"

rm -rf innoextract-upx innoextract-upx.tar.gz
curl -fsSL -o innoextract-upx.tar.gz "$INNOEXTRACT_URL"
tar -xzf innoextract-upx.tar.gz
rm innoextract-upx.tar.gz
chmod +x innoextract-upx

./build.sh "src.sh" "innoextract-upx" > "$FINAL_FILE"
