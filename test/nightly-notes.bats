#!/usr/bin/env bats

SHA=a9d33ae00b1e457c92acc35ed3f1a824cc02fc6b46106d4c5a2089ec3abf3300
COMMIT=0123abc0123456789abcdef0123456789abcdef0

setup() {
    NOTES="$BATS_TEST_DIRNAME/../scripts/nightly-notes.sh"
}

notes() {
    "$NOTES" --version "${1:-0.3.1+git20261026.0123abc}" --tag "${2:-nightly-20261026-0123abc}" \
        --commit "${3:-$COMMIT}" --deb-sha256 "${4:-$SHA}" \
        --pi-gen-tag 2026-10-06-raspios-trixie-arm64 --repo Skamba/gbs-anywhere-pi
}

@test "nightly notes say untested and carry the commit, package and notices" {
    run notes
    [ "$status" -eq 0 ]
    [[ "$output" == *"**Nightly build: untested.**"* ]]
    [[ "$output" == *"https://github.com/Skamba/gbs-anywhere/commit/$COMMIT"* ]]
    [[ "$output" == *"0.3.1+git20261026.0123abc"* ]]
    [[ "$output" == *"gbs-anywhere_0.3.1+git20261026.0123abc-1_arm64.deb"* ]]
    [[ "$output" == *"$SHA"* ]]
    [[ "$output" == *"packaging/build-release.sh"* ]]
    [[ "$output" == *"https://github.com/Skamba/gbs-anywhere-pi/releases/download/nightly-20261026-0123abc/gbs-anywhere-nightly.rpi-imager-manifest"* ]]
    [[ "$output" == *"2026-10-06-raspios-trixie-arm64"* ]]
    [[ "$output" == *"Raspberry Pi is a trademark of Raspberry Pi Ltd"* ]]
    [[ "$output" == *"Not affiliated with Mahlkönig or Hemro"* ]]
    [[ "$output" == *"2.0.12"* ]]
}

@test "bad or mismatched input is refused" {
    run notes 0.3.1
    [ "$status" -ne 0 ]
    run notes 0.3.1+git20261026.0123abc nightly-20261027-0123abc
    [ "$status" -ne 0 ]
    run notes 0.3.1+git20261026.0123abc nightly-20261026-0123abc "${COMMIT:0:7}"
    [ "$status" -ne 0 ]
    run notes 0.3.1+git20261026.0123abc nightly-20261026-0123abc "fedcba9${COMMIT:7}"
    [ "$status" -ne 0 ]
    run notes 0.3.1+git20261026.0123abc nightly-20261026-0123abc "$COMMIT" nothex
    [ "$status" -ne 0 ]
}
