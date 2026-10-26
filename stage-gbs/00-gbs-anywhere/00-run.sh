#!/bin/bash -e

# files/gbs-anywhere.deb is put there by scripts/build-image.sh, after
# checking it against the release's SHA256SUMS.
install -m 644 files/gbs-anywhere.deb "${ROOTFS_DIR}/tmp/gbs-anywhere.deb"
