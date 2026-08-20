#!/usr/bin/env bash
# NimLaunch Showcase: WiFi Manager
# Requires: nmcli, awk, grep, notify-send, nimlaunch

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

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
        pass=$(printf '\n' | "$NIMLAUNCH" --dmenu -p "Password for $ssid:")
        if [[ -n "$pass" ]]; then
            notify-send "WiFi" "Connecting to $ssid..." -i network-wireless
            nmcli device wifi connect "$ssid" password "$pass"
        fi
    fi
fi
