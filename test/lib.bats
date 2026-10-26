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
