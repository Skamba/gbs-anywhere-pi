#!/usr/bin/env bash
# make-manifest.sh --image PATH.img.xz --tag TAG --repo OWNER/NAME
#                  --date YYYY-MM-DD --official OS_LIST.json
#
# Print a Raspberry Pi Imager manifest with one entry: this image. Imager
# offers its OS customisation (Wi-Fi, user, hostname, SSH) only for images
# opened through a manifest, not for "Use custom". Device tags,
# capabilities and the customisation format come from the official
# "Raspberry Pi OS Lite (64-bit)" entry, which this image is built from.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

image='' tag='' repo='' date='' official=''
while [ $# -gt 0 ]; do
    case "$1" in
        --image) image=$2 ;;
        --tag) tag=$2 ;;
        --repo) repo=$2 ;;
        --date) date=$2 ;;
        --official) official=$2 ;;
        *) die "unknown option: $1" ;;
    esac
    shift 2
done
if [ -z "$image" ] || [ -z "$tag" ] || [ -z "$repo" ] || [ -z "$date" ] || [ -z "$official" ]; then
    die "usage: make-manifest.sh --image PATH.img.xz --tag TAG --repo OWNER/NAME --date YYYY-MM-DD --official OS_LIST.json"
fi

[[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)-([1-9][0-9]*)$ ]] || die "invalid tag: $tag"
version=${BASH_REMATCH[1]}
file=$(basename "$image")
[ "$file" = "gbs-anywhere-${version}-${BASH_REMATCH[2]}-arm64.img.xz" ] ||
    die "image $file does not belong to tag $tag"
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die "invalid repo: $repo"
[[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "invalid date: $date"

lite=$(jq -c '[.. | objects | select(.name? == "Raspberry Pi OS Lite (64-bit)")]' "$official")
[ "$(jq length <<< "$lite")" -eq 1 ] ||
    die "expected one \"Raspberry Pi OS Lite (64-bit)\" entry in $official"
format=$(jq -r '.[0].init_format' <<< "$lite")
[ "$format" = cloudinit-rpi ] ||
    die "the official Lite entry now uses init_format $format, not cloudinit-rpi: check the image before releasing"

download="https://github.com/$repo/releases/download/$tag"
jq -n \
    --argjson devices "$(jq -c '.imager.devices' "$official")" \
    --argjson lite "$lite" \
    --arg description "gbs-anywhere $version on Raspberry Pi OS Lite (64-bit). Grind-by-Sync for Mahlkönig grinders with any espresso machine." \
    --arg icon "$download/gbs-anywhere-icon.png" \
    --arg url "$download/$file" \
    --argjson extract_size "$(xz -dc "$image" | wc -c)" \
    --arg extract_sha256 "$(xz -dc "$image" | sha256sum | cut -d' ' -f1)" \
    --argjson download_size "$(stat -c %s "$image")" \
    --arg download_sha256 "$(sha256sum < "$image" | cut -d' ' -f1)" \
    --arg date "$date" \
    --arg website "https://github.com/$repo" \
    '{
        imager: {devices: $devices},
        os_list: [{
            name: "gbs-anywhere",
            description: $description,
            icon: $icon,
            url: $url,
            extract_size: $extract_size,
            extract_sha256: $extract_sha256,
            image_download_size: $download_size,
            image_download_sha256: $download_sha256,
            release_date: $date,
            init_format: "cloudinit-rpi",
            devices: $lite[0].devices,
            capabilities: ($lite[0].capabilities // []),
            website: $website
        }]
    }'
