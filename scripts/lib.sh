# shellcheck shell=bash
# Shared helpers, sourced by the other scripts.

# die MESSAGE: print MESSAGE to stderr and exit 1.
die() {
    printf '%s\n' "$*" >&2
    exit 1
}

# valid_version VERSION: succeed for a plain X.Y.Z release version. Versions
# reach URLs and file names, and may come from a workflow input or
# gbs-anywhere's release tag, so nothing else gets through.
valid_version() {
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    printf 'invalid version: %q\n' "$1" >&2
    return 1
}

# valid_nightly_stamp STAMP: succeed for YYYYMMDD-<7 hex>, the part of a
# nightly's tag and file names after "nightly-".
valid_nightly_stamp() {
    if [[ "$1" =~ ^[0-9]{8}-[0-9a-f]{7}$ ]]; then
        return 0
    fi
    printf 'invalid nightly stamp: %q\n' "$1" >&2
    return 1
}

# valid_package_version VERSION: succeed for a release version (X.Y.Z) or a
# nightly's (X.Y.Z+gitYYYYMMDD.<7 hex>), without the Debian revision.
valid_package_version() {
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+git[0-9]{8}\.[0-9a-f]{7})?$ ]]; then
        return 0
    fi
    printf 'invalid package version: %q\n' "$1" >&2
    return 1
}
