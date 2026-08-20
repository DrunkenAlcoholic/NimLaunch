#!/usr/bin/env bash
# NimLaunch Bluetooth Picker
# Requires: bluetoothctl

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

# Get list of paired devices, attach icon, and pipe to NimLaunch
choice=$(bluetoothctl devices | awk '{
  mac = $2;
  $1 = ""; $2 = "";
  # Remove leading spaces
  sub(/^[ \t]+/, "");
  # Pass literal null byte using \000 in awk
  printf "%s\000icon\x1fbluetooth\n", $0
}' | "$NIMLAUNCH" --dmenu)

[ -n "$choice" ] || exit 1

# Extract MAC address of chosen device
mac=$(bluetoothctl devices | grep "$choice" | awk '{print $2}')

# Check if currently connected to toggle state
if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$mac"
else
    bluetoothctl connect "$mac"
fi
