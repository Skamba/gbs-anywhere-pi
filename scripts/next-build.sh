#!/usr/bin/env bash
# next-build.sh VERSION < tags
#
# Read release tags, one per line, and print the next build number for
# VERSION: one more than the highest vVERSION-N, or 1 if there is none.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 1 ] || die "usage: next-build.sh VERSION < tags"
version=$1
valid_version "$version" || exit 1

pattern="^v${version//./\\.}-([0-9]+)$"
highest=0
while IFS= read -r tag; do
    if [[ "$tag" =~ $pattern ]] && ((10#${BASH_REMATCH[1]} > highest)); then
        highest=$((10#${BASH_REMATCH[1]}))
    fi
done
echo $((highest + 1))
