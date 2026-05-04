# Dmenu Examples

These scripts show practical ways to use NimLaunch as a generic selector with
`--dmenu`.

Assumptions:
- `nimlaunch` is on `PATH`, or you set `NIMLAUNCH_BIN=/path/to/nimlaunch`
- scripts are run from your user session

Examples:

```bash
examples/dmenu/project-picker.sh
examples/dmenu/cliphist-picker.sh
examples/dmenu/power-menu.sh
examples/dmenu/audio-sink-picker.sh
examples/dmenu/git-branch-picker.sh
```

You can also copy them into `~/.local/bin` and bind them in your compositor or
call them from NimLaunch shortcuts.

Environment overrides:
- `NIMLAUNCH_BIN`: launcher binary to use instead of `nimlaunch`
- `PROJECTS_ROOT`: root directory for `project-picker.sh`
- `PROJECTS_DEPTH`: max depth for `project-picker.sh` directory scan


## Example Shortcut Snippets

You can call these scripts from NimLaunch shortcuts instead of binding them only
in your compositor.

```toml
[[shortcuts]]
prefix = ":proj"
label = "Projects"
base = "~/.local/bin/project-picker.sh"
mode = "shell"
run_mode = "spawn"

[[shortcuts]]
prefix = ":clip"
label = "Clipboard History"
base = "~/.local/bin/cliphist-picker.sh"
mode = "shell"
run_mode = "spawn"

[[shortcuts]]
prefix = ":audio"
label = "Audio Output"
base = "~/.local/bin/audio-sink-picker.sh"
mode = "shell"
run_mode = "spawn"

[[shortcuts]]
prefix = ":gitb"
label = "Git Branches"
base = "~/.local/bin/git-branch-picker.sh"
mode = "shell"
run_mode = "spawn"

[[shortcuts]]
prefix = ":powermenu"
label = "Power Menu"
base = "~/.local/bin/power-menu.sh"
mode = "shell"
run_mode = "spawn"
```
