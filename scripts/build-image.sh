#!/usr/bin/env bash
# build-image.sh VERSION BUILD
# build-image.sh --nightly STAMP DEB
# build-image.sh --config-only VERSION BUILD OUTFILE
# build-image.sh --config-only --nightly STAMP OUTFILE
#
# Build gbs-anywhere-VERSION-BUILD-arm64.img.xz with pi-gen at the tag in
# PI_GEN_TAG: Raspberry Pi OS Lite plus stage-gbs. With --nightly, build
# gbs-anywhere-nightly-STAMP-arm64.img.xz with the package DEB, built from
# gbs-anywhere's main, instead of downloading a release. Needs Docker on an
# arm64 host. Works in ./build/; the image, its .info and logs end up in
# ./deploy/, and the image's path is printed last. --config-only only
# writes the pi-gen config.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
root=$(cd "$(dirname "$0")/.." && pwd)

config_only=0
nightly=0
if [ "${1:-}" = --config-only ]; then
    config_only=1
    shift
fi
if [ "${1:-}" = --nightly ]; then
    nightly=1
    shift
fi

if [ "$nightly" = 1 ]; then
    [ $# -eq 2 ] || die "usage: build-image.sh [--config-only] --nightly STAMP DEB|OUTFILE"
    stamp=$1
    valid_nightly_stamp "$stamp" || exit 1
    name="gbs-anywhere-nightly-${stamp}-arm64"
    label="gbs-anywhere nightly ${stamp}"
    outfile=$2
    if [ "$config_only" = 0 ]; then
        deb=$(realpath -e -- "$2" 2>/dev/null) || die "no such package: $2"
        [[ "$deb" != "$root/build/"* ]] || die "keep the package outside build/, which is wiped: $2"
    fi
else
    if [ "$config_only" = 1 ]; then
        [ $# -eq 3 ] || die "usage: build-image.sh --config-only VERSION BUILD OUTFILE"
        outfile=$3
    else
        [ $# -eq 2 ] || die "usage: build-image.sh VERSION BUILD"
    fi
    version=$1
    build=$2
    valid_version "$version" || exit 1
    [[ "$build" =~ ^[1-9][0-9]*$ ]] || die "invalid build number: $build"
    name="gbs-anywhere-${version}-${build}-arm64"
    label="gbs-anywhere ${version}-${build}"
fi

# Only what differs from pi-gen's defaults. No FIRST_USER_PASS (the account
# stays locked until Imager sets one), no WPA_COUNTRY (Wi-Fi stays off until
# Imager sets the country with the Wi-Fi details).
write_config() {
    cat > "$1" <<EOF
IMG_NAME=gbs-anywhere
IMG_FILENAME=$name
ARCHIVE_FILENAME=$name
RELEASE=trixie
TARGET_HOSTNAME=gbs-anywhere
DEPLOY_COMPRESSION=xz
ENABLE_CLOUD_INIT=1
ENABLE_SSH=0
DISABLE_FIRST_BOOT_USER_RENAME=0
STAGE_LIST="stage0 stage1 stage2 stage-gbs"
PI_GEN_RELEASE="$label (based on Raspberry Pi OS Lite)"
EOF
}

if [ "$config_only" = 1 ]; then
    write_config "$outfile"
    exit 0
fi

pi_gen_tag=$(cat "$root/PI_GEN_TAG")
work="$root/build"
pigen="$work/pi-gen"
rm -rf "$work"
mkdir -p "$work" "$root/deploy"

git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$pi_gen_tag" \
    https://github.com/RPi-Distro/pi-gen.git "$pigen"
cp -r "$root/stage-gbs" "$pigen/"
# Only stage-gbs exports an image.
touch "$pigen/stage2/SKIP_IMAGES"

if [ "$nightly" = 0 ]; then
    deb=$("$root/scripts/fetch-deb.sh" "$version" "$work/deb")
fi
mkdir -p "$pigen/stage-gbs/00-gbs-anywhere/files"
cp "$deb" "$pigen/stage-gbs/00-gbs-anywhere/files/gbs-anywhere.deb"

write_config "$work/config"
(cd "$pigen" && ./build-docker.sh -c "$work/config") >&2

mv "$pigen"/deploy/* "$root/deploy/"
image="$root/deploy/$name.img.xz"
[ -f "$image" ] || die "pi-gen made no $name.img.xz"
printf '%s\n' "$image"
