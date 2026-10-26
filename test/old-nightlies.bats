#!/usr/bin/env bats

setup() {
    OLD="$BATS_TEST_DIRNAME/../scripts/old-nightlies.sh"
}

# Releases as `gh release list --json tagName,createdAt,publishedAt` gives
# them. createdAt is the target commit's date, the same for every nightly
# of one commit here; only publishedAt orders them.
releases() {
    local i=0 tag
    printf '['
    for tag in "$@"; do
        [ "$i" -eq 0 ] || printf ','
        printf '{"tagName":"%s","createdAt":"2026-10-26T08:07:46Z","publishedAt":"2026-11-%02dT04:30:00Z"}' "$tag" $((i + 1))
        i=$((i + 1))
    done
    printf ']'
}

@test "prints the nightlies past the newest KEEP by publish time, nothing else" {
    # Oldest first, the order gh gives releases with the same createdAt.
    run "$OLD" 7 < <(releases nightly-20261022-0000001 nightly-20261023-0000002 v0.3.1-1 \
        nightly-20261024-0000003 nightly-20261025-0000004 nightly-20261026-0000005 \
        nightly-20261027-0000006 nightly-foo nightly-20261028-0000007 nightly-20261029-0000008 \
        v0.3.2-1 nightly-20261030-0000009)
    [ "$status" -eq 0 ]
    [ "$output" = $'nightly-20261023-0000002\nnightly-20261022-0000001' ]
}

@test "a draft, with no publish time, counts as the oldest" {
    run "$OLD" 1 <<'JSON'
[{"tagName":"nightly-20261026-0000005","createdAt":"2026-10-26T08:07:46Z","publishedAt":"2026-10-27T04:30:00Z"},
 {"tagName":"nightly-20261027-0000006","createdAt":"2026-10-26T08:07:46Z","publishedAt":null}]
JSON
    [ "$status" -eq 0 ]
    [ "$output" = nightly-20261027-0000006 ]
}

@test "fewer than KEEP, or none: nothing" {
    run "$OLD" 7 < <(releases nightly-20261025-0000004 nightly-20261026-0000005 v0.3.1-1)
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run "$OLD" 7 <<< '[]'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "input that isn't a release list is refused" {
    run "$OLD" 7 <<< 'nightly-20261026-0000005'
    [ "$status" -ne 0 ]
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
