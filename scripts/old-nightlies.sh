#!/usr/bin/env bash
# old-nightlies.sh KEEP < TAGS
#
# Read release tags newest first and print the nightly tags after the first
# KEEP nightly ones: the nightlies to delete. Other tags are never printed.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 1 ] || die "usage: old-nightlies.sh KEEP < TAGS"
[[ "$1" =~ ^[1-9][0-9]*$ ]] || die "invalid KEEP: $1"
keep=$1

seen=0
while IFS= read -r tag; do
    [[ "$tag" =~ ^nightly-[0-9]{8}-[0-9a-f]{7}$ ]] || continue
    seen=$((seen + 1))
    [ "$seen" -le "$keep" ] || printf '%s\n' "$tag"
done
