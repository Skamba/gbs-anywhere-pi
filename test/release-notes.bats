#!/usr/bin/env bats

SHA=a9d33ae00b1e457c92acc35ed3f1a824cc02fc6b46106d4c5a2089ec3abf3300

setup() {
    NOTES="$BATS_TEST_DIRNAME/../scripts/release-notes.sh"
}

@test "release notes carry the links, checksum and notices" {
    run "$NOTES" --version 0.3.1 --tag v0.3.1-1 --deb-sha256 "$SHA" \
        --pi-gen-tag 2026-10-06-raspios-trixie-arm64 --repo Skamba/gbs-anywhere-pi
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://github.com/Skamba/gbs-anywhere/releases/tag/v0.3.1"* ]]
    [[ "$output" == *"$SHA"* ]]
    [[ "$output" == *"2026-10-06-raspios-trixie-arm64"* ]]
    [[ "$output" == *"https://github.com/Skamba/gbs-anywhere-pi/releases/download/v0.3.1-1/gbs-anywhere.rpi-imager-manifest"* ]]
    [[ "$output" == *"Raspberry Pi is a trademark of Raspberry Pi Ltd"* ]]
    [[ "$output" == *"Not affiliated with Mahlkönig or Hemro"* ]]
    [[ "$output" == *"2.0.12"* ]]
}

@test "bad input is refused" {
    run "$NOTES" --version '0.3.1;x' --tag v0.3.1-1 --deb-sha256 "$SHA" \
        --pi-gen-tag t --repo Skamba/gbs-anywhere-pi
    [ "$status" -ne 0 ]
    run "$NOTES" --version 0.3.1 --tag v0.3.1-1 --deb-sha256 nothex \
        --pi-gen-tag t --repo Skamba/gbs-anywhere-pi
    [ "$status" -ne 0 ]
}
