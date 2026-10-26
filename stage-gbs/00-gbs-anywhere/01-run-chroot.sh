#!/bin/bash -e

apt-get install -y /var/tmp/gbs-anywhere.deb
rm /var/tmp/gbs-anywhere.deb

# Not started at boot: comitup starts it once the Pi is on Wi-Fi
# (web_service in /etc/comitup.conf), gbs-anywhere-net once a cable is
# connected.
systemctl disable gbs-anywhere.service
