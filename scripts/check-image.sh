#!/usr/bin/env bash
# check-image.sh IMAGE.img.xz VERSION   (as root; VERSION X.Y.Z or a nightly's X.Y.Z+gitYYYYMMDD.<sha7>)
#
# Mount a built image read-only and check what the design promises: the
# app at VERSION, started only by the network setup, the setup hotspot, no
# usable password, SSH off, no leftover first-boot state. Prints one line
# per check; exits 1 if any fails.

# The helper functions run through trap and check(), which shellcheck can't see.
# shellcheck disable=SC2317
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

[ $# -eq 2 ] || die "usage: check-image.sh IMAGE.img.xz VERSION"
image=$1
version=$2
valid_package_version "$version" || exit 1
[ "$(id -u)" -eq 0 ] || die "check-image.sh needs root (losetup, mount)"

work=$(mktemp -d)
loop=''
cleanup() {
    umount "$work/boot" "$work/root" 2>/dev/null || true
    [ -z "$loop" ] || losetup -d "$loop" || true
    rm -rf "$work"
}
trap cleanup EXIT

xz -dc "$image" > "$work/image"
loop=$(losetup -P --show -f "$work/image")
udevadm settle 2>/dev/null || true
mkdir "$work/boot" "$work/root"
mount -o ro "${loop}p1" "$work/boot"
mount -o ro,noload "${loop}p2" "$work/root"
boot="$work/boot"
r="$work/root"
wants="$r/etc/systemd/system/multi-user.target.wants"

failed=0
check() {
    local what=$1
    shift
    if "$@" > /dev/null 2>&1; then
        echo "ok   $what"
    else
        echo "FAIL $what"
        failed=1
    fi
}

pkg_version() { dpkg-query --admindir="$r/var/lib/dpkg" -W -f '${Version}' "$1"; }
pkg_installed() { [ "$(dpkg-query --admindir="$r/var/lib/dpkg" -W -f '${db:Status-Status}' "$1")" = installed ]; }
no_usable_password() { [ -z "$(awk -F: '$2 !~ /^[!*]/ {print $1}' "$r/etc/shadow")" ]; }
empty_or_absent() { [ ! -e "$1" ] || [ -z "$(ls -A "$1")" ]; }
# cloud-init's record of a boot it has run; empty directories don't count.
no_cloud_instance() { [ ! -e "$r/var/lib/cloud/instance" ] && empty_or_absent "$r/var/lib/cloud/instances"; }
root_755_no_cr() { [ "$(stat -c '%a %u' "$1")" = '755 0' ] && ! grep -q $'\r' "$1"; }
licence_files() { [ "$(find "$r/usr/share/doc" -name copyright | wc -l)" -gt 100 ]; }

check "gbs-anywhere binary installed" test -x "$r/usr/bin/gbs-anywhere"
check "gbs-anywhere package is ${version}-1" test "$(pkg_version gbs-anywhere)" = "${version}-1"
check "gbs-anywhere.service not started at boot" test ! -e "$wants/gbs-anywhere.service"
check "comitup.service enabled" test -L "$wants/comitup.service"
check "comitup starts gbs-anywhere" grep -qx 'web_service: gbs-anywhere.service' "$r/etc/comitup.conf"
check "comitup hotspot has no password" bash -c "! grep -q '^ap_password' '$r/etc/comitup.conf'"
check "comitup skipped while a cable is connected" test -f "$r/etc/systemd/system/comitup.service.d/gbs-anywhere.conf"
check "gbs-anywhere-net: root, 755, LF" root_755_no_cr "$r/usr/lib/gbs-anywhere-pi/gbs-anywhere-net"
check "dispatcher hook: root, 755, LF" root_755_no_cr "$r/etc/NetworkManager/dispatcher.d/50-gbs-anywhere-wired"
check "hostname is gbs-anywhere" test "$(cat "$r/etc/hostname")" = gbs-anywhere
check "ssh not enabled" test ! -e "$wants/ssh.service" -a ! -e "$wants/sshd.service"
check "no account has a usable password" no_usable_password
check "no first-boot state baked in" no_cloud_instance
check "no package copy left behind" test ! -e "$r/var/tmp/gbs-anywhere.deb"
check "cloud-init installed" pkg_installed cloud-init
check "rpi-cloud-init-mods installed" pkg_installed rpi-cloud-init-mods
check "cloud-init seed files on the boot partition" test -f "$boot/user-data" -a -f "$boot/network-config" -a -f "$boot/meta-data"
check "IPv6 off on the kernel command line" grep -qw 'ipv6\.disable=1' "$boot/cmdline.txt"
check "gbs-anywhere licence kept" test -f "$r/usr/share/doc/gbs-anywhere/copyright"
check "package licence files kept" licence_files

exit "$failed"
