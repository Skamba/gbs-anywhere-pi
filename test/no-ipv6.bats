#!/usr/bin/env bats
# The stage step that turns IPv6 off, run against a stand-in boot partition.

setup() {
    STEP="$BATS_TEST_DIRNAME/../stage-gbs/02-no-ipv6/00-run.sh"
    export ROOTFS_DIR="$BATS_TEST_TMPDIR/root"
    mkdir -p "$ROOTFS_DIR/boot/firmware"
    # As pi-gen leaves it: one line, no newline at the end.
    printf '%s' 'console=serial0,115200 console=tty1 root=ROOTDEV rootfstype=ext4 fsck.repair=yes rootwait' \
        > "$ROOTFS_DIR/boot/firmware/cmdline.txt"
}

@test "adds ipv6.disable=1 to the one line of cmdline.txt" {
    run bash "$STEP"
    [ "$status" -eq 0 ]
    [ "$(cat "$ROOTFS_DIR/boot/firmware/cmdline.txt")" = 'console=serial0,115200 console=tty1 root=ROOTDEV rootfstype=ext4 fsck.repair=yes rootwait ipv6.disable=1' ]
    [ "$(wc -l < "$ROOTFS_DIR/boot/firmware/cmdline.txt")" -le 1 ]
}

@test "running it twice adds it once" {
    bash "$STEP"
    bash "$STEP"
    [ "$(grep -o 'ipv6.disable=1' "$ROOTFS_DIR/boot/firmware/cmdline.txt" | wc -l)" -eq 1 ]
}

@test "a missing cmdline.txt fails the build" {
    rm "$ROOTFS_DIR/boot/firmware/cmdline.txt"
    run bash "$STEP"
    [ "$status" -ne 0 ]
}
