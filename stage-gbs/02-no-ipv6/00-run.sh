#!/bin/bash -e
# Turn IPv6 off for the whole Pi, on the kernel command line. avahi renames
# the Pi (gbs-anywhere-2.local) when an IPv6 address changes, and the .local
# name is how the phone and the grinder find the app
# (https://github.com/avahi/avahi/issues/117). A sysctl isn't enough:
# NetworkManager turns IPv6 back on for profiles with ipv6.method=auto.
# The app, the grinders and the setup Wi-Fi only use IPv4.

cmdline="${ROOTFS_DIR}/boot/firmware/cmdline.txt"
[ -f "$cmdline" ] || { echo "no $cmdline" >&2; exit 1; }
grep -qw 'ipv6\.disable=1' "$cmdline" || sed -i '1 s/$/ ipv6.disable=1/' "$cmdline"
