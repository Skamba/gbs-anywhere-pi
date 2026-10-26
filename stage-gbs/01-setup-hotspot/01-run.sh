#!/bin/bash -e

install -D -m 755 files/gbs-anywhere-net "${ROOTFS_DIR}/usr/lib/gbs-anywhere-pi/gbs-anywhere-net"
install -m 755 files/50-gbs-anywhere-wired "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/50-gbs-anywhere-wired"
install -m 644 files/comitup.conf "${ROOTFS_DIR}/etc/comitup.conf"
install -D -m 644 files/comitup-gbs-anywhere.conf "${ROOTFS_DIR}/etc/systemd/system/comitup.service.d/gbs-anywhere.conf"
