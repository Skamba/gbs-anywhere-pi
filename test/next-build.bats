#!/usr/bin/env bats

setup() {
    NEXT="$BATS_TEST_DIRNAME/../scripts/next-build.sh"
}

@test "first build of a version is 1" {
    run "$NEXT" 0.3.1 < /dev/null
    [ "$status" -eq 0 ]
    [ "$output" = 1 ]
}

@test "one more than the highest build" {
    run "$NEXT" 0.3.1 <<< $'v0.3.1-1\nv0.3.1-2'
    [ "$output" = 3 ]
}

@test "other versions and malformed tags don't count" {
    run "$NEXT" 0.3.1 <<< $'v0.3.10-4\nv0.3.1-2\nv0.3.1-x\nv0.3.1\nv0.3.1-3a\nv0.3.1.1-9'
    [ "$output" = 3 ]
}

@test "gaps: still one more than the highest" {
    run "$NEXT" 0.3.1 <<< $'v0.3.1-1\nv0.3.1-5'
    [ "$output" = 6 ]
}

@test "invalid version is refused" {
    run "$NEXT" '0.3.1;true' < /dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid version"* ]]
}
