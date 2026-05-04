#!/usr/bin/env bash
set -euo pipefail

launcher="${NIMLAUNCH_BIN:-nimlaunch}"
selection="$(printf 'lock\nlogout\nsuspend\nreboot\nshutdown\n' | "$launcher" --dmenu)" || exit 1

case "$selection" in
  lock)
    exec loginctl lock-session
    ;;
  logout)
    if command -v niri >/dev/null 2>&1; then
      exec niri msg action quit
    elif command -v hyprctl >/dev/null 2>&1; then
      exec hyprctl dispatch exit
    else
      printf 'power-menu: no compositor-specific logout command configured\n' >&2
      exit 1
    fi
    ;;
  suspend)
    exec systemctl suspend
    ;;
  reboot)
    exec systemctl reboot
    ;;
  shutdown)
    exec systemctl poweroff
    ;;
  *)
    exit 1
    ;;
 esac
