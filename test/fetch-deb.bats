#!/usr/bin/env bats

DEB=gbs-anywhere_0.3.1-1_arm64.deb

setup() {
    FETCH="$BATS_TEST_DIRNAME/../scripts/fetch-deb.sh"
    RELEASES="$BATS_TEST_TMPDIR/releases"
    OUT="$BATS_TEST_TMPDIR/out"
    mkdir -p "$RELEASES/v0.3.1" "$OUT"
    printf 'not really a package\n' > "$RELEASES/v0.3.1/$DEB"
    printf 'amd64 package\n' > "$RELEASES/v0.3.1/gbs-anywhere_0.3.1-1_amd64.deb"
    (cd "$RELEASES/v0.3.1" && sha256sum gbs-anywhere_0.3.1-1_amd64.deb "$DEB" > SHA256SUMS)
    export GBS_RELEASE_BASE_URL="file://$RELEASES"
}

@test "good checksum: prints the path of the verified .deb" {
    run "$FETCH" 0.3.1 "$OUT"
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$OUT" && pwd)/$DEB" ]
    cmp "$OUT/$DEB" "$RELEASES/v0.3.1/$DEB"
}

@test "mismatched checksum: fails and leaves no .deb" {
    printf 'tampered\n' >> "$RELEASES/v0.3.1/$DEB"
    run "$FETCH" 0.3.1 "$OUT"
    [ "$status" -ne 0 ]
    [ ! -e "$OUT/$DEB" ]
}

@test "a lookalike line in SHA256SUMS does not count" {
    (cd "$RELEASES/v0.3.1" && sha256sum "$DEB" | sed "s/$DEB/$DEB.sig/" > SHA256SUMS)
    run "$FETCH" 0.3.1 "$OUT"
    [ "$status" -ne 0 ]
    [ ! -e "$OUT/$DEB" ]
}

@test "missing release: fails" {
    run "$FETCH" 9.9.9 "$OUT"
    [ "$status" -ne 0 ]
    [ ! -e "$OUT/gbs-anywhere_9.9.9-1_arm64.deb" ]
}

@test "invalid version: refused before any download" {
    export GBS_RELEASE_BASE_URL="file://$BATS_TEST_TMPDIR/does-not-exist"
    local v
    for v in '0.3.1;true' v0.3.1; do
        run "$FETCH" "$v" "$OUT"
        [ "$status" -ne 0 ]
        [[ "$output" == *"invalid version"* ]]
        [[ "$output" != *curl* ]]
    done
}
