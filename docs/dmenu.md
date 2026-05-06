# Dmenu Mode

`--dmenu` turns NimLaunch into a generic selector UI.

Instead of scanning desktop applications, NimLaunch reads newline-separated
items from `stdin`, shows them in the normal launcher UI, and returns the
selected line on `stdout`.

## Basic Behavior

Example:

```bash
printf "one\ntwo\nthree\n" | nimlaunch --dmenu
```

Behavior:

- `Enter`: prints the selected line and exits with status `0`
- `Esc`: cancels and exits with status `1`
- empty query: preserves the original input order

This mode is intended for wrapper scripts and global selection menus.

## Good Use Cases

`--dmenu` is strongest when the source list is:

- dynamic
- global
- text-first
- not tied to the current shell working directory

Good examples:

- audio sink picker
- power/session menu
- SSH host selector
- recent note or document picker
- device/profile selectors backed by system tools


## Audio Sink Example

The repo includes one practical example:

- [examples/dmenu/audio-sink-picker.sh](../examples/dmenu/audio-sink-picker.sh)

That script:

- enumerates real PipeWire `Audio/Sink` nodes
- marks the current default sink
- launches NimLaunch in `--dmenu` mode
- sets the selected sink as the new default through `wpctl`

## Wiring A Dmenu Script Into NimLaunch

You can expose a script through a normal grouped shortcut.

Example:

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

That gives you a normal launcher flow such as:

```text
:media audio
```

## Wrapper Pattern

The usual wrapper pattern is:

1. build a newline-separated list
2. pipe it into `nimlaunch --dmenu`
3. read the selected line from `stdout`
4. perform the real action

Skeleton:

```bash
choice="$(some-command | nimlaunch --dmenu)" || exit 1
[ -n "$choice" ] || exit 1
do-something-with "$choice"
```

## Notes

- `--dmenu` is a selector mode, not an app launcher mode
- it does not need a `.desktop` source list
- it is best used by scripts, not by hand-typing large static menus

## Related Docs

- [Themes](themes.md)
- [Configuration](configuration.md)
- [Groups and Shortcuts](groups-and-shortcuts.md)
