#!/usr/bin/env bats

IMG=gbs-anywhere-0.3.1-1-arm64.img

setup() {
    MAKE="$BATS_TEST_DIRNAME/../scripts/make-manifest.sh"
    OFFICIAL="$BATS_TEST_DIRNAME/fixtures/os_list.json"
    cd "$BATS_TEST_TMPDIR"
    head -c 3145728 /dev/urandom > "$IMG"
    xz -k -0 "$IMG"
}

manifest() {
    "$MAKE" --image "$BATS_TEST_TMPDIR/$IMG.xz" --tag v0.3.1-1 \
        --repo Skamba/gbs-anywhere-pi --date 2026-10-26 --official "${1:-$OFFICIAL}"
}

@test "fields" {
    manifest > m.json
    run jq -e --slurpfile o "$OFFICIAL" '
        (.os_list | length) == 1 and
        .os_list[0].name == "gbs-anywhere" and
        .os_list[0].init_format == "cloudinit-rpi" and
        .os_list[0].url == "https://github.com/Skamba/gbs-anywhere-pi/releases/download/v0.3.1-1/gbs-anywhere-0.3.1-1-arm64.img.xz" and
        .os_list[0].icon == "https://github.com/Skamba/gbs-anywhere-pi/releases/download/v0.3.1-1/gbs-anywhere-icon.png" and
        .os_list[0].website == "https://github.com/Skamba/gbs-anywhere-pi" and
        .os_list[0].release_date == "2026-10-26" and
        .os_list[0].devices == ["pi5-64bit", "pi4-64bit", "pi3-64bit"] and
        .os_list[0].capabilities == ["rpi_connect"] and
        (.os_list[0].description | contains("0.3.1")) and
        .imager.devices == $o[0].imager.devices' m.json
    [ "$status" -eq 0 ]
}

@test "sizes and hashes" {
    manifest > m.json
    [ "$(jq .os_list[0].extract_size m.json)" = 3145728 ]
    [ "$(jq -r .os_list[0].extract_sha256 m.json)" = "$(sha256sum < "$IMG" | cut -d' ' -f1)" ]
    [ "$(jq .os_list[0].image_download_size m.json)" = "$(stat -c %s "$IMG.xz")" ]
    [ "$(jq -r .os_list[0].image_download_sha256 m.json)" = "$(sha256sum < "$IMG.xz" | cut -d' ' -f1)" ]
}

@test "official Lite entry missing: fails" {
    jq 'del(.os_list[0].subitems[0])' "$OFFICIAL" > o.json
    run manifest o.json
    [ "$status" -ne 0 ]
}

@test "official Lite entry changed its format: fails" {
    jq '.os_list[0].subitems[0].init_format = "rpi-preseed"' "$OFFICIAL" > o.json
    run manifest o.json
    [ "$status" -ne 0 ]
    [[ "$output" == *rpi-preseed* ]]
}

@test "image name must match the tag" {
    run "$MAKE" --image "$BATS_TEST_TMPDIR/$IMG.xz" --tag v0.3.2-1 \
        --repo Skamba/gbs-anywhere-pi --date 2026-10-26 --official "$OFFICIAL"
    [ "$status" -ne 0 ]
}

@test "nightly: its own name, URL and an untested description" {
    local img=gbs-anywhere-nightly-20261026-0123abc-arm64.img
    head -c 1048576 /dev/urandom > "$img"
    xz -k -0 "$img"
    "$MAKE" --image "$BATS_TEST_TMPDIR/$img.xz" --tag nightly-20261026-0123abc \
        --repo Skamba/gbs-anywhere-pi --date 2026-10-26 --official "$OFFICIAL" > m.json
    run jq -e '
        .os_list[0].name == "gbs-anywhere (nightly)" and
        .os_list[0].url == "https://github.com/Skamba/gbs-anywhere-pi/releases/download/nightly-20261026-0123abc/gbs-anywhere-nightly-20261026-0123abc-arm64.img.xz" and
        .os_list[0].icon == "https://github.com/Skamba/gbs-anywhere-pi/releases/download/nightly-20261026-0123abc/gbs-anywhere-icon.png" and
        (.os_list[0].description | contains("20261026-0123abc") and contains("Untested nightly build")) and
        .os_list[0].init_format == "cloudinit-rpi"' m.json
    [ "$status" -eq 0 ]
}

@test "nightly: the image must match the tag" {
    run "$MAKE" --image "$BATS_TEST_TMPDIR/$IMG.xz" --tag nightly-20261026-0123abc \
        --repo Skamba/gbs-anywhere-pi --date 2026-10-26 --official "$OFFICIAL"
    [ "$status" -ne 0 ]
    run "$MAKE" --image "$BATS_TEST_TMPDIR/$IMG.xz" --tag nightly-2026-x \
        --repo Skamba/gbs-anywhere-pi --date 2026-10-26 --official "$OFFICIAL"
    [ "$status" -ne 0 ]
}
