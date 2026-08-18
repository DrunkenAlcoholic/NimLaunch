#!/usr/bin/env bash
# NimLaunch Showcase: Steam Game Launcher
# Requires: steam, awk, nimlaunch

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

STEAM_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/Steam"
[[ -d "$STEAM_ROOT" ]] || STEAM_ROOT="$HOME/.steam/root"

if [[ ! -d "$STEAM_ROOT" ]]; then
    echo "Could not find Steam installation directory." >&2
    exit 1
fi

declare -a manifest_files=()
if [[ -f "$STEAM_ROOT/steamapps/libraryfolders.vdf" ]]; then
    while read -r path; do
        if [[ -d "$path/steamapps" ]]; then
            for f in "$path/steamapps"/appmanifest_*.acf; do
                [[ -f "$f" ]] && manifest_files+=("$f")
            done
        fi
    done < <(awk -F'"' '/"path"/ {print $4}' "$STEAM_ROOT/steamapps/libraryfolders.vdf")
else
    if [[ -d "$STEAM_ROOT/steamapps" ]]; then
        for f in "$STEAM_ROOT/steamapps"/appmanifest_*.acf; do
            [[ -f "$f" ]] && manifest_files+=("$f")
        done
    fi
fi

if [[ ${#manifest_files[@]} -eq 0 ]]; then
    echo "No Steam games found." >&2
    exit 1
fi

declare -A games
declare -a names

while IFS='|' read -r appid name; do
    games["$name"]="$appid"
    names+=("$name")
done < <(awk -F'"' '/"appid"/ {appid=$4} /"name"/ {name=$4; if (name !~ /^(Proton|Steam Linux Runtime|Steamworks)/) print appid "|" name}' "${manifest_files[@]}")

if [[ ${#names[@]} -eq 0 ]]; then
    echo "No playable Steam games found." >&2
    exit 1
fi

# Format output with steam icon and pipe to NimLaunch
choice=$(printf '%b\n' "${names[@]/%/\\0icon\\x1fsteam}" | $NIMLAUNCH --dmenu -p "Steam:")

if [[ -n "$choice" ]] && [[ -n "${games["$choice"]}" ]]; then
    appid="${games["$choice"]}"
    notify-send "Steam Launcher" "Launching $choice..." -i steam
    steam "steam://rungameid/$appid" >/dev/null 2>&1 &
fi
