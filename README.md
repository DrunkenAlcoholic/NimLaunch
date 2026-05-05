# NimLaunch (SDL3)

NimLaunch is a keyboard-first launcher for Wayland and X11 built on SDL3. It
covers three main workflows:

- application launching from `.desktop` entries
- configurable command/url/file shortcuts
- generic stdin-driven selection through `--dmenu`

It uses SDL3 for native Wayland/X11 support with GPU-backed compositing and
loads PNG/SVG icons through the SDL3 stack.

![NimLaunch screenshot](screenshots/NimLaunch-SDL2.gif)

## Features
- Fuzzy app search with typo tolerance, recent-item bias, and persistent usage-based ranking.
- Desktop entry actions for apps that expose secondary launch actions.
- Prefix commands: `:t`, `:c`, `:s`, `:r`, `!`, and custom groups.
- Vim mode (optional): `j/k` navigation, `/ : !` command bar, `gg/G`, `:q`, etc.
- Themes with live preview, status/toast messages, and clock overlay.
- `--dmenu` mode for scripts, audio menus, and other stdin-driven workflows.
- Icons from `.desktop` files (PNG/SVG) with theme-aware lookup; can be disabled.
- Window opacity setting (0.1–1.0) via SDL3 when supported.

## Install
Grab a compiled binary from the releases:
https://github.com/Vyrnexis/NimLaunch/releases

## Build
> [!NOTE]
> Runtime/build deps: `nim >= 2.0`, `sdl3`, `sdl3-ttf`, `sdl3-image`, plus a font
> (default `ttf-dejavu`).
>
> Nim package note: this project currently pins the Nim SDL3 wrapper to
> `sdl3 == 1.0` because the code imports `sdl3_ttf`, which is not exposed by
> newer incompatible `sdl3` package variants.
>
> Optional helpers:
> - `fd` and/or `locate` for faster `:s` file search

### Archlinux
```bash
sudo pacman -S sdl3 sdl3-ttf sdl3-image ttf-dejavu --needed
```

### Ubuntu
```bash
sudo apt install libsdl3-dev libsdl3-ttf-dev libsdl3-image-dev fonts-dejavu-core
```

### OpenSUSE
```bash
# Tumbleweed / Slowroll package names:
sudo zypper install SDL3-devel SDL3_ttf-devel SDL3_image-devel dejavu-fonts
```
If you are on Leap and a name differs, run `zypper search sdl3`
to find the matching package variant.

### Solus
```bash
sudo eopkg it sdl3-devel sdl3-ttf-devel sdl3-image
```

### Build from source
```bash
git clone https://github.com/Vyrnexis/NimLaunch.git
cd NimLaunch
```

```bash
nimble -y nimDebug    # debug build -> ./bin/nimlaunch
nimble build          # package/default debug build -> ./nimlaunch
nimble -y nimRelease  # release build for current CPU (fastest on this machine) -> ./bin/nimlaunch
nimble -y nimReleasePortable  # portable + smaller release build (generic x86_64 baseline) -> ./bin/nimlaunch
```

For a more portable release build (via Zig/clang), use:

```bash
nimble -y zigDebug    # debug build -> ./bin/nimlaunch
nimble -y zigRelease  # release build for current CPU via Zig/clang -> ./bin/nimlaunch
nimble -y zigReleasePortable  # portable + smaller Zig/clang release build (generic x86_64 baseline) -> ./bin/nimlaunch
```

Use `nimble c` if you need custom compiler flags while keeping Nimble-managed
dependency paths:

```bash
nimble c -d:release --opt:speed -o:./bin/nimlaunch src/nimlaunch.nim
```

```bash
./nimlaunch          # from `nimble build`
./bin/nimlaunch      # from task builds above
```

Place the binary (`nimlaunch`) somewhere on your `PATH` (e.g., `~/.local/bin`) and
bind a hotkey to launch it. The TOML config is auto-generated on first run.

## Wayland/X11
Runs natively on both via SDL3 (no XWayland required on Wayland). Borderless
window like the original. GPU compositing handles fills/icons/text blits; SDL_ttf
still rasterizes glyphs in software.

## Troubleshooting
- Build fails with `cannot open .../src/nimlaunch.nim`: build from project root,
  and use `nimble build`, `nimble c ...`, or the provided Nimble tasks.
- Build fails with `cannot open file: sdl3_ttf`: your Nimble environment is
  resolving the wrong `sdl3` package. This project expects the pinned
  `sdl3 == 1.0` wrapper that includes `sdl3_ttf`.
- `:s` search feels slow: install `fd` and/or `locate` so search avoids the
  slower `$HOME` fallback walk.
- Icons are missing for SVG apps: ensure your `SDL3_image` build includes SVG
  support. This project now loads SVG icons through `SDL3_image` directly.
- `--dmenu` looks empty: make sure you are piping newline-separated input into
  it, for example `printf "one\\ntwo\\n" | nimlaunch --dmenu`.
- Text looks wrong or too small: set `[font].fontname` to an installed font and
  size (e.g., `"Dejavu:size=16"`).
- Wayland/Niri black padding or delayed repaint: build with
  `nimble c -d:nimlaunchWindowDebug --nimcache:/tmp/nimlaunch_dbg_cache -o:/tmp/nimlaunch_dbg src/nimlaunch.nim`
  and run `/tmp/nimlaunch_dbg` to log window events + redraw timing.
- Theme changes do not persist: verify `~/.config/nimlaunch/nimlaunch.toml`
  is writable.

## Dmenu Mode
Use `--dmenu` to turn NimLaunch into a generic selector for stdin-provided
items. In this mode NimLaunch does not scan desktop applications; it reads
newline-separated entries from `stdin`, lets you filter them with the normal UI,
prints the selected line to `stdout`, and exits.

Behavior:
- `Enter` prints the selected line and exits with status `0`
- `Esc` cancels and exits with status `1`
- empty query preserves the original input order

Example:

```bash
printf "one\ntwo\nthree\n" | ./nimlaunch --dmenu
```

Typical uses:
- audio sink picker
- power/session menu
- any global text-based selector driven by a wrapper script

Included example:
- `examples/dmenu/audio-sink-picker.sh`

To expose that script inside NimLaunch itself, add a grouped shortcut like:

```toml
[[groups]]
name = "media"
query_mode = "filter"

[[shortcuts]]
group    = "media"
label    = "Audio Sink"
base     = "~/.local/bin/audio-sink-picker.sh"
mode     = "shell"
run_mode = "spawn"
```

Install the script somewhere on your `PATH` such as `~/.local/bin`, or use the
repo copy directly while testing:

```toml
[[shortcuts]]
group    = "media"
label    = "Audio Sink"
base     = "/absolute/path/to/NimLaunch/examples/dmenu/audio-sink-picker.sh"
mode     = "shell"
run_mode = "spawn"
```

## Quick Reference
Core controls:

| Trigger | Context | Effect |
| ------- | ------- | ------ |
| Type text | Normal | Fuzzy-search applications; top hit updates instantly |
| Enter | Normal or command bar | Launch the highlighted entry immediately |
| Esc | Command bar | Close the bar, keep the narrowed results selected |
| Esc | Normal | Exit NimLaunch |
| ↑ / ↓ / PgUp / PgDn / Home / End | Any | Navigate the results list |
| `/` | Normal | Toggle the command bar (restores previous `/` search) |
| `:` / `!` | Normal | Open the bar primed for a prefix or `!` command |
| Ctrl+U | Command bar | Clear the current query |
| Ctrl+H / Backspace | Command bar | Delete one character (closes the bar when empty) |

### Built-in prefixes

| Prefix | Example | Description |
| ------ | ------- | ----------- |
| *none* | `fire` | Regular app search; rankings favour prefixes, recent launches, and persistent usage |
| `:t` | `:t nord` | Browse themes; Up/Down preview, Enter to keep selection |
| `:s` | `:s notes` | Search files (`fd` → `locate` → bounded `$HOME` walk) |
| `:c` | `:c sway` | Match files inside `~/.config` and open with the default handler |
| `:r` | `:r htop` | Run a shell command inside your preferred terminal |
| `!` | `!htop` | Shorthand for `:r` without the colon |
| `:<group>` | `:sys lock` | Run grouped shortcuts (for example a `sys` group for session/power actions) |

## Configuration
Config path: `~/.config/nimlaunch/nimlaunch.toml` (auto-generated on first run).

```toml
[window]
width = 500
opacity = 1.0          # 0.1–1.0; may be ignored on some Wayland setups
max_visible_items = 10
center = true
position_x = 20
position_y = 500
vertical_align = "one-third"
display = 0

[font]
fontname = "Noto Sans:size=12"

[input]
prompt   = "> "
cursor   = "_"
vim_mode = false

[terminal]
program = "kitty"

[border]
width = 2

[icons]
enabled = true                    # Set to false to hide icons in the list

[[groups]]
name = "sys"
query_mode = "filter"

[[shortcuts]]
prefix = ":g"            # write "g", ":g", or "g:" — all map to :g in the UI
label  = "Search Google: "
base   = "https://www.google.com/search?q={query}"
mode   = "url"            # other options: "shell", "file"

[[themes]]
name                = "Nord"
bgColorHex          = "#2E3440"
fgColorHex          = "#D8DEE9"
highlightBgColorHex = "#88C0D0"
highlightFgColorHex = "#2E3440"
borderColorHex      = "#4C566A"
matchFgColorHex     = "#f8c291"

[theme]
last_chosen = "Nord"
```

`vertical_align` only affects Y when `center = true` (`top`, `center`, `one-third`).
`display` selects the monitor index when centered (`0` = primary, `1` = second, ...).

## Shortcuts (how they work)
A shortcut is a `:`-triggered template. Text after the prefix is inserted as
`{query}`.

Fields:
- `prefix`: what you type after `:` (e.g., `g`, `note`, `rg`).
- `label`: text shown in the results list.
- `base`: template command/URL/path. Use `{query}` where the input should go.
- `mode = "url"`: opens URL (query is URL-encoded).
- `mode = "shell"`: runs shell command (query is safely quoted).
- `mode = "file"`: opens file/folder (`~` expands).

If `group` is set, `prefix` is optional because the group name becomes the
prefix (e.g., `:dev`, `:sys`).

## Groups (powerful shortcuts)
Groups collect shortcuts under one prefix (`:dev`, `:sys`).
- `query_mode = "filter"`: query filters by label.
- `query_mode = "pass"`: query is passed as `{query}` to each entry.

Filter example (menu-style):
```toml
[[groups]]
name = "sys"
query_mode = "filter"

[[shortcuts]]
group    = "sys"
label    = "Lock"
base     = "loginctl lock-session"
mode     = "shell"
run_mode = "spawn"

[[shortcuts]]
group    = "sys"
label    = "Suspend"
base     = "systemctl suspend"
mode     = "shell"
run_mode = "spawn"

[[shortcuts]]
group     = "sys"
label     = "Reboot"
base      = "systemctl reboot"
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
```

Pass-through example (multi-tool search):
```toml
[[groups]]
name = "dev"
query_mode = "pass"

[[shortcuts]]
group = "dev"
label = "Issues: "
base  = "gh issue list --search {query}"
mode  = "shell"

[[shortcuts]]
group = "dev"
label = "Docs: "
base  = "https://docs.example.com/search?q={query}"
mode  = "url"
```

## Vim mode
Enable with `[input].vim_mode = true` in `~/.config/nimlaunch/nimlaunch.toml`.
General controls in Quick Reference still apply; Vim mode adds:

| Trigger | Effect |
| ------- | ------ |
| `j` / `k` | Move selection down / up |
| `h` | Delete one character from the input |
| `l` | Launch the highlighted entry |
| `gg` / `Shift+G` | Jump to top / bottom of the list |
| `/` | Open the command bar for search |
| `:` | Open the command bar for prefix commands |
| `!` | Open the command bar for run commands (`:r` shorthand) |
| `Esc` | Close the command bar and keep current filtered results |
| `:q` (then Enter) | Quit NimLaunch from the command bar |

## File discovery & caching
NimLaunch indexes `.desktop` files from:

1. `~/.local/share/applications`
2. `~/.local/share/flatpak/exports/share/applications`
3. each `<dir>/applications` from `$XDG_DATA_DIRS` (defaults to `/usr/local/share:/usr/share`)
4. `/var/lib/flatpak/exports/share/applications`

App metadata is cached in `~/.cache/nimlaunch/apps.json` and invalidated when
source dirs change. Entries with `NoDisplay=true`, `Hidden=true`,
`Terminal=true`, or exact `Settings` / `System` categories are skipped.
Recent launches are tracked in `~/.cache/nimlaunch/recent.json`.

## Themes
- Use `:t` to browse themes, preview with Up/Down, and press Enter to keep.
- Leaving `:t` without Enter restores the previous theme.
- Add/edit `[[themes]]` in TOML to create custom palettes.
