#!/usr/bin/env bats

setup() {
    BUILD="$BATS_TEST_DIRNAME/../scripts/build-image.sh"
}

@test "config-only writes the pi-gen config" {
    run "$BUILD" --config-only 0.3.1 1 "$BATS_TEST_TMPDIR/config"
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/config")" = 'IMG_NAME=gbs-anywhere
IMG_FILENAME=gbs-anywhere-0.3.1-1-arm64
ARCHIVE_FILENAME=gbs-anywhere-0.3.1-1-arm64
RELEASE=trixie
TARGET_HOSTNAME=gbs-anywhere
DEPLOY_COMPRESSION=xz
ENABLE_CLOUD_INIT=1
ENABLE_SSH=0
DISABLE_FIRST_BOOT_USER_RENAME=0
STAGE_LIST="stage0 stage1 stage2 stage-gbs"
PI_GEN_RELEASE="gbs-anywhere 0.3.1-1 (based on Raspberry Pi OS Lite)"' ]
}

@test "config-only refuses a bad version or build number" {
    run "$BUILD" --config-only 'x;y' 1 "$BATS_TEST_TMPDIR/config"
    [ "$status" -ne 0 ]
    local b
    for b in 0 -1 01 x 1a; do
        run "$BUILD" --config-only 0.3.1 "$b" "$BATS_TEST_TMPDIR/config"
        [ "$status" -ne 0 ] || { echo "accepted build '$b'"; return 1; }
    done
    [ ! -e "$BATS_TEST_TMPDIR/config" ]
}

@test "the config sets no password, no SSH and no Wi-Fi country" {
    "$BUILD" --config-only 0.3.1 1 "$BATS_TEST_TMPDIR/config"
    ! grep -E '^(FIRST_USER_PASS|PUBKEY_SSH_FIRST_USER|WPA_COUNTRY|PUBKEY_ONLY_SSH)=' "$BATS_TEST_TMPDIR/config"
}

@test "the .deb is staged in /var/tmp, not the /tmp pi-gen covers with a tmpfs" {
    local stage="$BATS_TEST_DIRNAME/../stage-gbs/00-gbs-anywhere"
    grep -q '"${ROOTFS_DIR}/var/tmp/gbs-anywhere.deb"' "$stage/00-run.sh"
    grep -qx 'apt-get install -y /var/tmp/gbs-anywhere.deb' "$stage/01-run-chroot.sh"
    grep -qx 'rm /var/tmp/gbs-anywhere.deb' "$stage/01-run-chroot.sh"
    ! grep -E '(^|[^r])/tmp/gbs-anywhere' "$stage/00-run.sh" "$stage/01-run-chroot.sh"
}

@test "the stage exports the only image" {
    local stage="$BATS_TEST_DIRNAME/../stage-gbs"
    [ "$(cat "$stage/EXPORT_IMAGE")" = 'IMG_SUFFIX=""' ]
    grep -qx comitup "$stage/01-setup-hotspot/00-packages"
}

@test "config-only --nightly writes the nightly's pi-gen config" {
    run "$BUILD" --config-only --nightly 20261026-0123abc "$BATS_TEST_TMPDIR/config"
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/config")" = 'IMG_NAME=gbs-anywhere
IMG_FILENAME=gbs-anywhere-nightly-20261026-0123abc-arm64
ARCHIVE_FILENAME=gbs-anywhere-nightly-20261026-0123abc-arm64
RELEASE=trixie
TARGET_HOSTNAME=gbs-anywhere
DEPLOY_COMPRESSION=xz
ENABLE_CLOUD_INIT=1
ENABLE_SSH=0
DISABLE_FIRST_BOOT_USER_RENAME=0
STAGE_LIST="stage0 stage1 stage2 stage-gbs"
PI_GEN_RELEASE="gbs-anywhere nightly 20261026-0123abc (based on Raspberry Pi OS Lite)"' ]
}

@test "--nightly refuses a bad stamp or a missing package before doing anything" {
    run "$BUILD" --config-only --nightly 'x;y' "$BATS_TEST_TMPDIR/config"
    [ "$status" -ne 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/config" ]
    # A copy of the repo, so a mistaken build can't touch the real build/.
    local repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$repo"
    cp -r "$BATS_TEST_DIRNAME/../scripts" "$repo/"
    run "$repo/scripts/build-image.sh" --nightly 20261026-0123abc "$BATS_TEST_TMPDIR/missing.deb"
    [ "$status" -ne 0 ]
    [[ "$output" == *missing.deb* ]]
    [ ! -e "$repo/build" ]
    run "$repo/scripts/build-image.sh" --nightly '20261026-0123abc;x' "$BATS_TEST_TMPDIR/missing.deb"
    [ "$status" -ne 0 ]
    [ ! -e "$repo/build" ]
}
