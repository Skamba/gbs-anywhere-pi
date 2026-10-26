#!/usr/bin/env bats

SHA=0123abc0123456789abcdef0123456789abcdef0

setup() {
    INFO="$BATS_TEST_DIRNAME/../scripts/nightly-info.sh"
    CARGO="$BATS_TEST_TMPDIR/Cargo.toml"
    cargo_toml 0.3.1
}

# cargo_toml VERSION: a Cargo.toml with other "version" keys after the
# package's own.
cargo_toml() {
    cat > "$CARGO" <<TOML
[package]
name = "gbs-anywhere"
version = "$1"
edition = "2021"

[dependencies]
serde = { version = "1.0.200" }

[workspace.package]
version = "9.9.9"
TOML
}

@test "names the nightly after the package version, commit date and commit" {
    run "$INFO" "$CARGO" "$SHA" 2026-10-26T23:59:59Z
    [ "$status" -eq 0 ]
    [ "$output" = 'stamp=20261026-0123abc
version=0.3.1+git20261026.0123abc
tag=nightly-20261026-0123abc
name=gbs-anywhere-nightly-20261026-0123abc-arm64' ]
}

@test "a pre-release package version is refused" {
    cargo_toml 0.4.0-dev
    run "$INFO" "$CARGO" "$SHA" 2026-10-26T23:59:59Z
    [ "$status" -ne 0 ]
}

@test "no package version is refused" {
    printf '[package]\nname = "gbs-anywhere"\n' > "$CARGO"
    run "$INFO" "$CARGO" "$SHA" 2026-10-26T23:59:59Z
    [ "$status" -ne 0 ]
    run "$INFO" "$BATS_TEST_TMPDIR/missing.toml" "$SHA" 2026-10-26T23:59:59Z
    [ "$status" -ne 0 ]
}

@test "a bad commit or date is refused" {
    local sha date
    for sha in "${SHA:0:39}" "${SHA^^}" "${SHA:0:39};"; do
        run "$INFO" "$CARGO" "$sha" 2026-10-26T23:59:59Z
        [ "$status" -ne 0 ] || { echo "accepted sha '$sha'"; return 1; }
    done
    for date in 2026-10-26 26-10-2026T00:00:00Z '2026-10-26T23:59:59Z;x' ''; do
        run "$INFO" "$CARGO" "$SHA" "$date"
        [ "$status" -ne 0 ] || { echo "accepted date '$date'"; return 1; }
    done
}
