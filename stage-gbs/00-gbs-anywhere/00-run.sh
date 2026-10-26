#!/bin/bash -e

# files/gbs-anywhere.deb is put there by scripts/build-image.sh, after
# checking it against the release's SHA256SUMS. Not /tmp: pi-gen's on_chroot
# mounts an empty tmpfs over it.
install -m 644 files/gbs-anywhere.deb "${ROOTFS_DIR}/var/tmp/gbs-anywhere.deb"
