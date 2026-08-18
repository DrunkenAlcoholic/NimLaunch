#!/usr/bin/env bash
# NimLaunch Showcase: WiFi Manager
# Requires: nmcli, awk, nimlaunch

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

# Inject icons and emojis based on security, and pipe directly into nimlaunch
selected=$(nmcli --fields "SECURITY,SSID" device wifi list | sed 1d | grep -v "^--" | grep -v "^ $" | awk '!seen[$2]++' | awk '{
    if ($1 ~ /WPA/ || $1 ~ /WEP/) {
        print "🔒 " $2 "\0icon\x1fnetwork-wireless-encrypted"
    } else {
        print "🔓 " $2 "\0icon\x1fnetwork-wireless"
    }
}' | $NIMLAUNCH --dmenu -p "WiFi:")

if [[ -n "$selected" ]]; then
    ssid=$(echo "$selected" | awk '{print $2}')
    known=$(nmcli -g NAME connection show | grep "^$ssid$")
    
    if [[ -n "$known" ]]; then
        notify-send "WiFi" "Connecting to $ssid..." -i network-wireless
        nmcli connection up id "$ssid"
    else
        pass=$(echo "" | $NIMLAUNCH --dmenu -p "Password for $ssid:")
        if [[ -n "$pass" ]]; then
            notify-send "WiFi" "Connecting to $ssid..." -i network-wireless
            nmcli device wifi connect "$ssid" password "$pass"
        fi
    fi
fi
