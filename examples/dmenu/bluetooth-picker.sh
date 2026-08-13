#!/bin/bash
# A Bluetooth device picker for NimLaunch dmenu
# Requires: bluetoothctl

# Get list of paired devices
devices=$(bluetoothctl devices | awk '{$1=""; $2=""; print substr($0,3)}')

if [ -z "$devices" ]; then
    echo "No paired devices found."
    exit 1
fi

# Format with icons (using standard bluetooth icon)
items=$(echo "$devices" | awk '{print $0 "\\0icon\\x1fbluetooth"}')

# Pipe into NimLaunch
choice=$(printf "%b" "$items" | nimlaunch --dmenu)

[ -n "$choice" ] || exit 1

# Get MAC address for the chosen device
mac=$(bluetoothctl devices | grep "$choice" | awk '{print $2}')

# Check if currently connected to toggle state
if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$mac"
else
    bluetoothctl connect "$mac"
fi
