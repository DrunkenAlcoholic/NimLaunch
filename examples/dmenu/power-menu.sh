#!/bin/bash
# A polished power menu for NimLaunch dmenu

items="Lock\0icon\x1fsystem-lock-screen\nSuspend\0icon\x1fsystem-suspend\nLogout\0icon\x1fsystem-log-out\nReboot\0icon\x1fsystem-reboot\nShutdown\0icon\x1fsystem-shutdown"

choice=$(printf "%b" "$items" | nimlaunch --dmenu)

case "$choice" in
  Lock)
    loginctl lock-session
    ;;
  Suspend)
    systemctl suspend
    ;;
  Logout)
    loginctl terminate-user $USER
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
esac
