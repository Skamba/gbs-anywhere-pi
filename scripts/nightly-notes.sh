#!/usr/bin/env bash
# nightly-notes.sh --version PKGVER --tag TAG --commit SHA --deb-sha256 HEX
#                  --pi-gen-tag T --repo OWNER/NAME
#
# Print the notes for a nightly image release, as Markdown. PKGVER is the
# package version from nightly-info.sh; TAG and the commit must belong to it.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

version='' tag='' commit='' sha='' pigen='' repo=''
while [ $# -gt 0 ]; do
    case "$1" in
        --version) version=$2 ;;
        --tag) tag=$2 ;;
        --commit) commit=$2 ;;
        --deb-sha256) sha=$2 ;;
        --pi-gen-tag) pigen=$2 ;;
        --repo) repo=$2 ;;
        *) die "unknown option: $1" ;;
    esac
    shift 2
done
[[ "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+git([0-9]{8})\.([0-9a-f]{7})$ ]] ||
    die "invalid nightly version: $version"
sha7=${BASH_REMATCH[3]}
stamp="${BASH_REMATCH[2]}-$sha7"
[ "$tag" = "nightly-$stamp" ] || die "tag $tag does not belong to $version"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || die "invalid commit: $commit"
[ "${commit:0:7}" = "$sha7" ] || die "commit $commit does not belong to $version"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid sha256: $sha"
[[ "$pigen" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid pi-gen tag: $pigen"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid repo: $repo"
deb="gbs-anywhere_${version}-1_arm64.deb"

cat <<NOTES
> **Nightly build: untested.** Built automatically from gbs-anywhere's
> \`main\` branch, for testing only. Only the newest 7 nightlies are kept.
> For everyday use, flash the [latest release](https://github.com/$repo/releases/latest).

gbs-anywhere $version, ready to flash, for a Raspberry Pi 3, 4, 5 or
Zero 2 W. Based on Raspberry Pi OS Lite (64-bit).

**Flash it** with Raspberry Pi Imager 2.0.12 or newer: download
[gbs-anywhere-nightly.rpi-imager-manifest](https://github.com/$repo/releases/download/$tag/gbs-anywhere-nightly.rpi-imager-manifest)
and open it with Imager, then pick your Pi, "gbs-anywhere (nightly)" and
your card. Set your Wi-Fi in Imager's settings, as the
[README](https://github.com/$repo#readme) describes. With SSH you can
instead install the attached \`$deb\` on a Pi already running this image
(\`sudo apt install ./$deb\`).

## What's inside

- gbs-anywhere $version, built in this repository from commit
  [\`${commit:0:7}\`](https://github.com/Skamba/gbs-anywhere/commit/$commit)
  of gbs-anywhere's \`main\` with its own \`packaging/build-release.sh\`,
  unchanged, and packaged as \`$deb\` (SHA256 \`$sha\`)
- Raspberry Pi OS Lite (Debian 13 "Trixie"), built with pi-gen
  [\`$pigen\`](https://github.com/RPi-Distro/pi-gen/tree/$pigen),
  with the packages current on the build date
- comitup, for the setup Wi-Fi when the Pi can't join yours

The \`.info\` file lists every package in the image.

## Licences

The image is a collection of separately licensed works (Debian, Raspberry
Pi, gbs-anywhere, comitup and others), each under its own licence, listed
in \`/usr/share/doc/*/copyright\` on the image; that includes firmware that
may only be used with the hardware it was made for. gbs-anywhere is
AGPL-3.0-or-later; its source is at the commit linked above. The build
scripts in this repository are MIT.

This image is based on Raspberry Pi OS Lite but is not Raspberry Pi OS, and
is not made or endorsed by Raspberry Pi Ltd.
Raspberry Pi is a trademark of Raspberry Pi Ltd.
Not affiliated with Mahlkönig or Hemro.
NOTES
