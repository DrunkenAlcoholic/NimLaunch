# ── Defaults as TOML text (same as NimLaunch) ───────────────────────────
const defaultToml* = """
# ==========================
# NimLaunch Configuration
# ==========================
# This file controls how NimLaunch looks and behaves.
# All settings are optional — if removed, defaults will be used.
# Edit values, save, and restart NimLaunch to apply changes.
# Colors must be in HEX format (e.g., "#RRGGBB").

[window]
width = 500                       # Width of the launcher window in pixels
opacity = 1.0                     # Window opacity (0.1 - 1.0); requires SDL support
max_visible_items = 10            # Number of items visible at once (affects height)
center = true                     # true: center window horizontally; false: use position_x/position_y
position_x = 20                   # X position in pixels when center=false
position_y = 500                  # Y position in pixels when center=false
vertical_align = "one-third"      # Only used when center=true; "top", "center", or "one-third"
display = 0                       # Display index when center=true (0 = primary)
pollIntervalMs = 10               # Main loop polling interval in milliseconds

[font]
fontname = "Dejavu:size=16"       # Font name & size (e.g., "Font Family:size=N")

[input]
prompt = "> "                     # Prompt prefix shown before your query
cursor = "_"                      # Cursor character displayed after query text
vim_mode = false                  # true enables Vim-style modes/hjkl navigation

[terminal]
program = "gnome-terminal"        # Terminal emulator for slash commands (/ ...)
                                  # If not found, NimLaunch will fall back to a default

[border]
width = 2                         # Border thickness in pixels (0 = no border)

[icons]
enabled = true                    # Set to false to hide icons in the list

# ==========================
# Groups
# ==========================
# Define group names used by [[shortcuts]].
# query_mode = "filter" (default) or "pass".

[[groups]]
name = "sys"
query_mode = "filter"

# ==========================
# Shortcuts
# ==========================
# Define custom prefix triggers. Each shortcut supports:
#   prefix  = letters you trigger with ':' (e.g., ":g"); leading/trailing ':' is optional
#   label   = text shown before your query in the results list
#   base    = template containing optional {query} placeholder
#   mode    = "url" (default), "shell", or "file"
#   group   = optional group name (e.g. "sys")
#   run_mode = "terminal" (default) or "spawn" for shell commands
#   stay_open = true keeps NimLaunch open after running the action

[[shortcuts]]
prefix = ":g"
label  = "Search Google: "
base   = "https://www.google.com/search?q={query}"
mode   = "url"

[[shortcuts]]
prefix = ":w"
label  = "Search Wiki: "
base   = "https://en.wikipedia.org/wiki/Special:Search?search={query}"
mode   = "url"

[[shortcuts]]
prefix = ":y"
label  = "Search YouTube: "
base   = "https://www.youtube.com/results?search_query={query}"
mode   = "url"

# ==========================
# Run commands
# ==========================
# Use `:r` (or `!`) to execute shell commands directly without a custom shortcut.

[[shortcuts]]
prefix    = "="
label     = "Calculate: "
base      = "res=$(echo '{query}' | bc -l); echo \"$res\" | wl-copy; notify-send 'Calculator' \"Result: $res\" -i accessories-calculator"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "scripts"
label     = "Window Switcher"
base      = "bash ~/.config/nimlaunch/scripts/nimlaunch_windows.sh"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "scripts"
label     = "Clipboard Manager"
base      = "bash ~/.config/nimlaunch/scripts/nimlaunch_cliphist.sh"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "scripts"
label     = "WiFi Network Manager"
base      = "bash ~/.config/nimlaunch/scripts/nimlaunch_wifi.sh"
mode      = "shell"
run_mode  = "spawn"
stay_open = false
[[shortcuts]]
group     = "sys"
label     = "Lock"
base      = "loginctl lock-session"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "sys"
label     = "Suspend"
base      = "systemctl suspend"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "sys"
label     = "Shutdown"
base      = "systemctl poweroff"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "sys"
label     = "Reboot"
base      = "systemctl reboot"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

[[shortcuts]]
group     = "sys"
label     = "Logout"
base      = "loginctl terminate-user $USER"
mode      = "shell"
run_mode  = "spawn"
stay_open = false

# ==========================
# Themes
# ==========================
# Add or remove [[themes]] blocks to customize appearance.
# The "name" field is what you'll see in the `:t` theme selector.
# Colors:
#   bgColorHex          = Window background
#   fgColorHex          = Normal text color
#   highlightBgColorHex = Background of selected/highlighted item
#   highlightFgColorHex = Text color of selected/highlighted item
#   borderColorHex      = Window border color
#   matchFgColorHex     = Color for matching characters in search results
#
# Tip: You can quickly preview themes in-app with the `t:` command.

[[themes]]
name                = "Default"
bgColorHex          = "#2E3440"
fgColorHex          = "#D8DEE9"
highlightBgColorHex = "#88C0D0"
highlightFgColorHex = "#2E3440"
borderColorHex      = "#8BE9FD"
matchFgColorHex     = "#f8c291"

[[themes]]
name                = "Ayu Dark"
bgColorHex          = "#0F1419"
fgColorHex          = "#BFBDB6"
highlightBgColorHex = "#59C2FF"
highlightFgColorHex = "#0F1419"
borderColorHex      = "#1F2328"
matchFgColorHex     = ""

[[themes]]
name                = "Ayu Light"
bgColorHex          = "#FAFAFA"
fgColorHex          = "#5C6773"
highlightBgColorHex = "#399EE6"
highlightFgColorHex = "#FAFAFA"
borderColorHex      = "#F0F0F0"
matchFgColorHex     = ""

[[themes]]
name                = "Catppuccin Frappe"
bgColorHex          = "#303446"
fgColorHex          = "#C6D0F5"
highlightBgColorHex = "#8CAAEE"
highlightFgColorHex = "#303446"
borderColorHex      = "#414559"
matchFgColorHex     = ""

[[themes]]
name                = "Catppuccin Latte"
bgColorHex          = "#EFF1F5"
fgColorHex          = "#4C4F69"
highlightBgColorHex = "#1E66F5"
highlightFgColorHex = "#EFF1F5"
borderColorHex      = "#BCC0CC"
matchFgColorHex     = ""

[[themes]]
name                = "Catppuccin Macchiato"
bgColorHex          = "#24273A"
fgColorHex          = "#CAD3F5"
highlightBgColorHex = "#8AADF4"
highlightFgColorHex = "#24273A"
borderColorHex      = "#363A4F"
matchFgColorHex     = ""

[[themes]]
name                = "Catppuccin Mocha"
bgColorHex          = "#1E1E2E"
fgColorHex          = "#CDD6F4"
highlightBgColorHex = "#89B4FA"
highlightFgColorHex = "#1E1E2E"
borderColorHex      = "#313244"
matchFgColorHex     = ""

[[themes]]
name                = "Dracula"
bgColorHex          = "#282A36"
fgColorHex          = "#F8F8F2"
highlightBgColorHex = "#BD93F9"
highlightFgColorHex = "#282A36"
borderColorHex      = "#44475A"
matchFgColorHex     = ""

[[themes]]
name                = "GitHub Dark"
bgColorHex          = "#0D1117"
fgColorHex          = "#E6EDF3"
highlightBgColorHex = "#388BFD"
highlightFgColorHex = "#0D1117"
borderColorHex      = "#30363D"
matchFgColorHex     = ""

[[themes]]
name                = "GitHub Light"
bgColorHex          = "#FFFFFF"
fgColorHex          = "#1F2328"
highlightBgColorHex = "#0969DA"
highlightFgColorHex = "#FFFFFF"
borderColorHex      = "#D1D9E0"
matchFgColorHex     = ""

[[themes]]
name                = "Gruvbox Dark"
bgColorHex          = "#282828"
fgColorHex          = "#EBDBB2"
highlightBgColorHex = "#83A598"
highlightFgColorHex = "#282828"
borderColorHex      = "#3C3836"
matchFgColorHex     = ""

[[themes]]
name                = "Gruvbox Light"
bgColorHex          = "#FBF1C7"
fgColorHex          = "#3C3836"
highlightBgColorHex = "#83A598"
highlightFgColorHex = "#FBF1C7"
borderColorHex      = "#EBDBB2"
matchFgColorHex     = ""

[[themes]]
name                = "Nord"
bgColorHex          = "#2E3440"
fgColorHex          = "#D8DEE9"
highlightBgColorHex = "#88C0D0"
highlightFgColorHex = "#2E3440"
borderColorHex      = "#4C566A"
matchFgColorHex     = ""

[theme]
last_chosen = "Default"

"""
