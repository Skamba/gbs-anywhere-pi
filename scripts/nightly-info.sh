#!/usr/bin/env bash
# nightly-info.sh CARGO_TOML COMMIT_SHA COMMIT_DATE
#
# Name a nightly built from gbs-anywhere at COMMIT_SHA, committed at
# COMMIT_DATE (ISO 8601, UTC), whose Cargo.toml is CARGO_TOML. Prints
# stamp=, version=, tag= and name= lines, for $GITHUB_OUTPUT. The package
# version, X.Y.Z+gitYYYYMMDD.<sha7>, sorts after release X.Y.Z and before
# the next one.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 3 ] || die "usage: nightly-info.sh CARGO_TOML COMMIT_SHA COMMIT_DATE"
cargo=$1
sha=$2
date=$3
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "invalid commit: $sha"
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || die "invalid commit date: $date"

# The package's version, read the way upstream's packaging script reads it.
line=$(grep -m 1 '^version = ' "$cargo") || die "no version in $cargo"
[[ "$line" =~ ^version\ =\ \"([0-9]+\.[0-9]+\.[0-9]+)\"$ ]] ||
    die "$cargo: version is not X.Y.Z: $line"

stamp="${date:0:4}${date:5:2}${date:8:2}-${sha:0:7}"
version="${BASH_REMATCH[1]}+git${stamp/-/.}"
valid_nightly_stamp "$stamp" || exit 1
valid_package_version "$version" || exit 1

printf 'stamp=%s\nversion=%s\ntag=nightly-%s\nname=gbs-anywhere-nightly-%s-arm64\n' \
    "$stamp" "$version" "$stamp" "$stamp"
