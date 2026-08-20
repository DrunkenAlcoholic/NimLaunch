#!/usr/bin/env bash
# NimLaunch Showcase: WiFi Manager
# Requires: nmcli, awk, grep, notify-send, nimlaunch, kdialog or zenity

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

# Request a password using an available desktop dialog.
prompt_password() {
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --password "Password for $1"
    elif command -v zenity >/dev/null 2>&1; then
        zenity --password --title="Password for $1"
    else
        notify-send "WiFi" "Install kdialog or zenity to enter a new network password."
        return 1
    fi
}

# Preserve complete SSIDs and attach a generic wireless icon.
selected=$(nmcli -t --escape no --fields SSID device wifi list | awk '
    length($0) > 0 && !seen[$0]++ {
        printf "%s%cicon\037network-wireless\n", $0, 0
    }
' | "$NIMLAUNCH" --dmenu -p "WiFi:")

if [[ -n "$selected" ]]; then
    ssid=$selected

    if nmcli -g NAME connection show | grep -Fqx -- "$ssid"; then
        notify-send "WiFi" "Connecting to $ssid..." -i network-wireless
        nmcli connection up id "$ssid"
    else
        pass=$(prompt_password "$ssid") || exit 1
        if [[ -n "$pass" ]]; then
            notify-send "WiFi" "Connecting to $ssid..." -i network-wireless
            nmcli device wifi connect "$ssid" password "$pass"
        fi
    fi
fi
