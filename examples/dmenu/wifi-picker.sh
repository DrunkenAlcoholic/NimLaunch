#!/bin/bash
# A WiFi network picker for NimLaunch dmenu
# Requires: nmcli

# Get list of available SSIDs
ssids=$(nmcli -t -f SSID dev wifi | grep -v '^$' | sort -u)

# Format with icons
items=$(echo "$ssids" | awk '{print $0 "\\0icon\\x1fnetwork-wireless"}')

choice=$(printf "%b" "$items" | nimlaunch --dmenu)

[ -n "$choice" ] || exit 1

# Try to connect (prompts for password in terminal or via agent if required)
nmcli dev wifi connect "$choice"
