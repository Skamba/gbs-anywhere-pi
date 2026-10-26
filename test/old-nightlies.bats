#!/usr/bin/env bats

setup() {
    OLD="$BATS_TEST_DIRNAME/../scripts/old-nightlies.sh"
}

@test "prints the nightlies past the newest KEEP, nothing else" {
    run "$OLD" 7 <<'TAGS'
nightly-20261030-0000009
v0.3.2-1
nightly-20261029-0000008
nightly-20261028-0000007
nightly-foo
nightly-20261027-0000006
nightly-20261026-0000005
nightly-20261025-0000004
nightly-20261024-0000003
v0.3.1-1
nightly-20261023-0000002
nightly-20261022-0000001
TAGS
    [ "$status" -eq 0 ]
    [ "$output" = $'nightly-20261023-0000002\nnightly-20261022-0000001' ]
}

@test "fewer than KEEP, or none: nothing" {
    run "$OLD" 7 <<< $'nightly-20261026-0000005\nnightly-20261025-0000004\nv0.3.1-1'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run "$OLD" 7 < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "a bad KEEP is refused" {
    local k
    for k in 0 x -1 ''; do
        run "$OLD" "$k" < /dev/null
        [ "$status" -ne 0 ] || { echo "accepted KEEP '$k'"; return 1; }
    done
    run "$OLD" < /dev/null
    [ "$status" -ne 0 ]
}
