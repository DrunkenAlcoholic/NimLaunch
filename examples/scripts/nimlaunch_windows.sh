#!/usr/bin/env bash
# NimLaunch Showcase: Hyprland Window Switcher
# Requires: hyprctl, jq, nimlaunch

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

selected=$(hyprctl clients -j | jq -r '.[] | select(.mapped == true) | "\(.address) | \(.title)\u0000icon\u001f\(.class)"' | "$NIMLAUNCH" --dmenu -p "Windows:")

if [[ -n "$selected" ]]; then
    address=$(echo "$selected" | awk '{print $1}')
    hyprctl dispatch focuswindow address:"$address"
fi
