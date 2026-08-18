#!/usr/bin/env bash
# NimLaunch Showcase: Smart Clipboard Manager
# Requires: cliphist, wl-copy, awk, nimlaunch

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

selected=$(cliphist list | awk -F'\t' '{
    if ($2 ~ /^\[\[ binary data/) {
        print $0 "\0icon\x1fimage-x-generic"
    } else {
        print $0 "\0icon\x1fedit-paste"
    }
}' | $NIMLAUNCH --dmenu -p "Clipboard:")

if [[ -n "$selected" ]]; then
    echo "$selected" | cliphist decode | wl-copy
    notify-send "Clipboard" "Item copied to clipboard buffer." -i edit-paste
fi
