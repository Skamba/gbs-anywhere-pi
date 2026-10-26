#!/usr/bin/env bash
# old-nightlies.sh KEEP < RELEASES.json
#
# Read the releases as `gh release list --json tagName,publishedAt` prints
# them and print the nightly tags after the newest KEEP nightly ones, by
# publish time: the nightlies to delete. A draft has no publish time and
# counts as the oldest. Other tags are never printed. (Not createdAt: that
# is the date of the release's target commit, which nightlies share.)
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 1 ] || die "usage: old-nightlies.sh KEEP < RELEASES.json"
[[ "$1" =~ ^[1-9][0-9]*$ ]] || die "invalid KEEP: $1"
keep=$1

# Read the whole list first, so bad input fails before anything is printed.
tags=$(jq -r 'sort_by(.publishedAt // "") | reverse | .[].tagName') ||
    die "not a release list"
seen=0
while IFS= read -r tag; do
    [[ "$tag" =~ ^nightly-[0-9]{8}-[0-9a-f]{7}$ ]] || continue
    seen=$((seen + 1))
    [ "$seen" -le "$keep" ] || printf '%s\n' "$tag"
done <<< "$tags"
