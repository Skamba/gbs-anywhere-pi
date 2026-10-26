#!/usr/bin/env bash
# release-notes.sh --version V --tag TAG --deb-sha256 HEX --pi-gen-tag T
#                  --repo OWNER/NAME
#
# Print the notes for an image release, as Markdown.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

version='' tag='' sha='' pigen='' repo=''
while [ $# -gt 0 ]; do
    case "$1" in
        --version) version=$2 ;;
        --tag) tag=$2 ;;
        --deb-sha256) sha=$2 ;;
        --pi-gen-tag) pigen=$2 ;;
        --repo) repo=$2 ;;
        *) die "unknown option: $1" ;;
    esac
    shift 2
done
valid_version "$version" || exit 1
[[ "$tag" =~ ^v${version//./\\.}-[1-9][0-9]*$ ]] || die "invalid tag for $version: $tag"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "invalid sha256: $sha"
[[ "$pigen" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid pi-gen tag: $pigen"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid repo: $repo"

cat <<EOF
> **Pre-release: not tested on a Raspberry Pi yet.** (Delete this line when
> marking the release as latest.)

gbs-anywhere $version, ready to flash, for a Raspberry Pi 3, 4, 5 or
Zero 2 W. Based on Raspberry Pi OS Lite (64-bit).

**Flash it** with Raspberry Pi Imager 2.0.12 or newer: download
[gbs-anywhere.rpi-imager-manifest](https://github.com/$repo/releases/download/$tag/gbs-anywhere.rpi-imager-manifest)
and open it with Imager, then pick your Pi, "gbs-anywhere" and your card.
Set your Wi-Fi in Imager's settings. The [README](https://github.com/$repo#readme)
has the steps.

## What's inside

- gbs-anywhere [$version](https://github.com/Skamba/gbs-anywhere/releases/tag/v$version),
  installed unmodified from \`gbs-anywhere_${version}-1_arm64.deb\`
  (SHA256 \`$sha\`)
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
AGPL-3.0-or-later; its source is at the tag linked above. The build scripts
in this repository are MIT.

This image is based on Raspberry Pi OS Lite but is not Raspberry Pi OS, and
is not made or endorsed by Raspberry Pi Ltd.
Raspberry Pi is a trademark of Raspberry Pi Ltd.
Not affiliated with Mahlkönig or Hemro.
EOF
