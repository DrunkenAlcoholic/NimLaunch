#!/usr/bin/env bash
# NimLaunch Bluetooth Picker
# Requires: bluetoothctl

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

# Keep each MAC address in the selected label so device names stay unambiguous.
choice=$(bluetoothctl devices | awk '{
  mac = $2;
  $1 = ""; $2 = "";
  sub(/^[ \t]+/, "");
  printf "%s %s\000icon\x1fbluetooth\n", mac, $0
}' | "$NIMLAUNCH" --dmenu)

[[ -n "$choice" ]] || exit 1

# Extract the preserved MAC address without searching by device name.
mac=${choice%% *}
[[ "$mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || exit 1

# Check if currently connected to toggle state
if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$mac"
else
    bluetoothctl connect "$mac"
fi
