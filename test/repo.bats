#!/usr/bin/env bats
# Checks on the repository itself: a Windows checkout must not turn scripts
# into files the Pi or CI can't run.

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "no CR in tracked text files" {
    run bash -c "git ls-files --eol | grep -E 'i/crlf|w/crlf|i/mixed|w/mixed'"
    [ "$status" -eq 1 ]
}

@test "scripts are executable in git" {
    local missing=()
    while read -r mode _ _ path; do
        case "$path" in
            *.sh | */gbs-anywhere-net | */50-gbs-anywhere-wired)
                [ "$mode" = 100755 ] || missing+=("$path")
                ;;
        esac
    done < <(git ls-files -s)
    if [ "${#missing[@]}" -ne 0 ]; then
        printf 'not executable: %s\n' "${missing[@]}"
        return 1
    fi
}
