# shellcheck shell=bash
# Shared helpers, sourced by the other scripts.

# die MESSAGE: print MESSAGE to stderr and exit 1.
die() {
    printf '%s\n' "$*" >&2
    exit 1
}

# valid_version VERSION: succeed for a plain X.Y.Z release version. Versions
# reach URLs and file names, and may come from a dispatch payload, so
# nothing else gets through.
valid_version() {
    if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    printf 'invalid version: %q\n' "$1" >&2
    return 1
}
