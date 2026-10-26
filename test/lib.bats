#!/usr/bin/env bats

setup() {
    # shellcheck source=../scripts/lib.sh
    source "$BATS_TEST_DIRNAME/../scripts/lib.sh"
}

@test "valid_version accepts X.Y.Z" {
    valid_version 0.3.1
    valid_version 10.20.30
}

@test "valid_version refuses anything else" {
    local v
    for v in v0.3.1 0.3 0.3.1-1 '0.3.1; true' ../0.3.1 '' ' 0.3.1' $'0.3.1\n1.2.3'; do
        run valid_version "$v"
        [ "$status" -eq 1 ] || { echo "accepted: '$v'"; return 1; }
        [[ "$output" == *"invalid version"* ]]
    done
}

@test "valid_nightly_stamp accepts YYYYMMDD-sha7" {
    valid_nightly_stamp 20261026-abc1234
}

@test "valid_nightly_stamp refuses anything else" {
    local s
    for s in 2026102-abc1234 20261026-ABC1234 20261026-abc123 '20261026-abc1234;x' \
        $'20261026-abc1234\n20261027-abc1234' ''; do
        run valid_nightly_stamp "$s"
        [ "$status" -eq 1 ] || { echo "accepted: '$s'"; return 1; }
        [[ "$output" == *"invalid nightly stamp"* ]]
    done
}

@test "valid_package_version accepts a release or a nightly" {
    valid_package_version 0.3.1
    valid_package_version 0.3.1+git20261026.abc1234
}

@test "valid_package_version refuses anything else" {
    local v
    for v in 0.3.1+git2026.abc1234 0.3.1~rc1 0.3.1+git20261026.abc1234-1 v0.3.1 \
        '0.3.1+git20261026.abc1234;x' $'0.3.1\n0.3.2'; do
        run valid_package_version "$v"
        [ "$status" -eq 1 ] || { echo "accepted: '$v'"; return 1; }
        [[ "$output" == *"invalid package version"* ]]
    done
}
