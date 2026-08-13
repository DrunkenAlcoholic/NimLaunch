#!/bin/bash
# A clipboard history picker for NimLaunch dmenu
# Requires: cliphist, wl-copy

# Get history from cliphist
history=$(cliphist list)

if [ -z "$history" ]; then
    echo "Clipboard history is empty."
    exit 1
fi

# Format with icons (cliphist outputs "index\tcontent")
# We display the content and attach a paste icon
items=$(echo "$history" | awk -F'\t' '{print $2 "\\0icon\\x1fedit-paste"}')

choice=$(printf "%b" "$items" | nimlaunch --dmenu)

[ -n "$choice" ] || exit 1

# Retrieve the full item from cliphist using the text and copy it to active clipboard
match=$(echo "$history" | grep -F "$choice" | head -n 1)
echo "$match" | cliphist decode | wl-copy
