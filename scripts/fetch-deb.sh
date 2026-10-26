#!/usr/bin/env bash
# fetch-deb.sh VERSION OUTDIR
#
# Download gbs-anywhere's arm64 .deb for VERSION from its GitHub release,
# check it against that release's SHA256SUMS, and print its path. On any
# failure nothing is left at that path.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 2 ] || die "usage: fetch-deb.sh VERSION OUTDIR"
version=$1
outdir=$2
valid_version "$version" || exit 1

base_url=${GBS_RELEASE_BASE_URL:-https://github.com/Skamba/gbs-anywhere/releases/download}
deb="gbs-anywhere_${version}-1_arm64.deb"

mkdir -p "$outdir"
outdir=$(cd "$outdir" && pwd)
work=$(mktemp -d "$outdir/.fetch.XXXXXX")
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 3 -o "$work/$deb" "$base_url/v$version/$deb"
curl -fsSL --retry 3 -o "$work/SHA256SUMS" "$base_url/v$version/SHA256SUMS"

# Only the line for exactly this file counts (sha256sum's binary-mode "*"
# prefix included), so a line for a lookalike name can't vouch for it.
awk -v f="$deb" '$2 == f || $2 == "*" f' "$work/SHA256SUMS" > "$work/check"
[ "$(wc -l < "$work/check")" -eq 1 ] || die "SHA256SUMS has no single line for $deb"
(cd "$work" && sha256sum --quiet -c check) || die "checksum mismatch for $deb"

mv "$work/$deb" "$outdir/$deb"
printf '%s\n' "$outdir/$deb"
