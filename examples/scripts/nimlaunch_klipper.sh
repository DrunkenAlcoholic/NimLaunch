#!/usr/bin/env bash
# NimLaunch Showcase: KDE Klipper Clipboard Manager
# Requires: busctl, jq, qdbus (optional)

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

# Fetch clipboard history from Klipper via DBus and format with jq
selected=$(busctl --user --json=short call org.kde.klipper /klipper org.kde.klipper.klipper getClipboardHistoryMenu | jq -r '.data[0][] | gsub("\n"; " ") + "\u0000icon\u001fedit-paste"' | "$NIMLAUNCH" --dmenu -p "Klipper:")

if [[ -n "$selected" ]]; then
    # Set the selected item back to the top of Klipper
    busctl --user call org.kde.klipper /klipper org.kde.klipper.klipper setClipboardContents s "$selected"
    notify-send "Klipper" "Item copied to clipboard buffer." -i edit-paste
fi
