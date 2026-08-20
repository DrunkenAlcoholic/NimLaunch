#!/usr/bin/env bash
# NimLaunch Power Menu
# Requires: systemd / loginctl

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

choice=$(echo -e "Lock\0icon\x1fsystem-lock-screen\nSuspend\0icon\x1fsystem-suspend\nLogout\0icon\x1fsystem-log-out\nReboot\0icon\x1fsystem-reboot\nShutdown\0icon\x1fsystem-shutdown" | "$NIMLAUNCH" --dmenu)

case "$choice" in
  Lock)
    loginctl lock-session
    ;;
  Suspend)
    systemctl suspend
    ;;
  Logout)
    loginctl terminate-user "$USER"
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
esac
