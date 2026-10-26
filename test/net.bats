#!/usr/bin/env bats
# gbs-anywhere-net with stand-ins for nmcli and systemctl: nmcli answers from
# STUB_* variables, systemctl records its arguments.

setup() {
    NET="$BATS_TEST_DIRNAME/../stage-gbs/01-setup-hotspot/files/gbs-anywhere-net"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
[ "${STUB_NMCLI_FAIL:-0}" = 1 ] && exit 8
case "$*" in
    "-t -f TYPE,STATE device") printf '%b\n' "$STUB_DEVICES" ;;
    "-g GENERAL.TYPE device show "*) [ -n "${STUB_TYPE:-}" ] || exit 10; printf '%s\n' "$STUB_TYPE" ;;
    "-t -f UUID,TYPE connection show --active") printf '%b\n' "${STUB_ACTIVE:-}" ;;
    "-g 802-11-wireless.mode connection show "*)
        case " ${STUB_AP_UUIDS:-} " in *" $5 "*) echo ap ;; *) echo infrastructure ;; esac ;;
    "--wait 0 connection down "*) echo "nmcli $*" >> "$BATS_TEST_TMPDIR/calls" ;;
    *) echo "unexpected nmcli $*" >&2; exit 2 ;;
esac
EOF
    cat > "$BATS_TEST_TMPDIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BATS_TEST_TMPDIR/calls"
exit "${STUB_SYSTEMCTL_EXIT:-0}"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    CALLS="$BATS_TEST_TMPDIR/calls"
    : > "$CALLS"
}

@test "no-wired: a connected cable means no comitup" {
    STUB_DEVICES='wifi:disconnected\nethernet:connected' run "$NET" no-wired
    [ "$status" -eq 1 ]
}

@test "no-wired: no cable means comitup may run" {
    STUB_DEVICES='ethernet:unavailable\nwifi:connected\nloopback:connected (externally)' run "$NET" no-wired
    [ "$status" -eq 0 ]
}

@test "no-wired: nmcli failing still lets comitup run" {
    STUB_NMCLI_FAIL=1 run "$NET" no-wired
    [ "$status" -eq 0 ]
}

@test "cable up: hotspot off, app on" {
    STUB_TYPE=ethernet run "$NET" dispatch eth0 up
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = $'--no-block stop comitup.service comitup-web.service\n--no-block start gbs-anywhere.service' ]
}

@test "cable up: the open setup Wi-Fi is taken down too" {
    STUB_TYPE=ethernet STUB_AP_UUIDS='ap-1' \
        STUB_ACTIVE='eth-1:802-3-ethernet\nap-1:802-11-wireless\nhome-1:802-11-wireless' \
        run "$NET" dispatch eth0 up
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = $'--no-block stop comitup.service comitup-web.service\nnmcli --wait 0 connection down ap-1\n--no-block start gbs-anywhere.service' ]
}

@test "cable down after a USB adapter is pulled: comitup takes over" {
    STUB_TYPE='' STUB_DEVICES='wifi:disconnected' run "$NET" dispatch eth1 down
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = '--no-block start comitup.service' ]
}

@test "wifi up: left to comitup" {
    STUB_TYPE=wifi run "$NET" dispatch wlan0 up
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "cable down, no other cable: comitup takes over" {
    STUB_TYPE=ethernet STUB_DEVICES='ethernet:unavailable\nwifi:connected' run "$NET" dispatch eth0 down
    [ "$status" -eq 0 ]
    [ "$(cat "$CALLS")" = '--no-block start comitup.service' ]
}

@test "cable down, another cable still connected: nothing" {
    STUB_TYPE=ethernet STUB_DEVICES='ethernet:unavailable\nethernet:connected' run "$NET" dispatch eth0 down
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "other actions: nothing" {
    STUB_TYPE=ethernet run "$NET" dispatch eth0 dhcp4-change
    [ "$status" -eq 0 ]
    [ ! -s "$CALLS" ]
}

@test "dispatch exits 0 even when systemctl or nmcli fail" {
    STUB_TYPE=ethernet STUB_SYSTEMCTL_EXIT=1 run "$NET" dispatch eth0 up
    [ "$status" -eq 0 ]
    STUB_NMCLI_FAIL=1 run "$NET" dispatch eth0 up
    [ "$status" -eq 0 ]
}

@test "dispatcher hook hands over to gbs-anywhere-net" {
    run cat "$BATS_TEST_DIRNAME/../stage-gbs/01-setup-hotspot/files/50-gbs-anywhere-wired"
    [ "$output" = $'#!/bin/sh\nexec /usr/lib/gbs-anywhere-pi/gbs-anywhere-net dispatch "$@"' ]
}

@test "comitup config: open hotspot named gbs-anywhere, app as web service" {
    local conf="$BATS_TEST_DIRNAME/../stage-gbs/01-setup-hotspot/files/comitup.conf"
    run grep -v -e '^#' -e '^$' "$conf"
    [ "$output" = $'ap_name: gbs-anywhere-<nnn>\nweb_service: gbs-anywhere.service\nenable_appliance_mode: false' ]
    ! grep -q ap_password "$conf"
}

@test "comitup drop-in skips comitup while a cable is connected" {
    run cat "$BATS_TEST_DIRNAME/../stage-gbs/01-setup-hotspot/files/comitup-gbs-anywhere.conf"
    [[ "$output" == *$'[Service]\nExecCondition=/usr/lib/gbs-anywhere-pi/gbs-anywhere-net no-wired'* ]]
}
