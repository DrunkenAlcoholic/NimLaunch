# Configuration

NimLaunch reads its config from:

```text
~/.config/nimlaunch/nimlaunch.toml
```

If the file does not exist, NimLaunch generates one on first run from the
embedded default template in the binary.

If the file exists but contains invalid TOML, NimLaunch ignores it for that
session, prints a parse error on startup, and uses built-in defaults until the
file is fixed.

## Layout

The generated config is split into these sections:

- `[window]`
- `[font]`
- `[input]`
- `[terminal]`
- `[border]`
- `[icons]`
- `[[groups]]`
- `[[shortcuts]]`
- `[[themes]]`
- `[theme]`

## Window

```toml
[window]
width = 500
opacity = 1.0
max_visible_items = 10
center = true
position_x = 20
position_y = 500
vertical_align = "one-third"
display = 0
```

Meaning:

- `width`: launcher width in pixels
- `opacity`: `0.1` to `1.0`; may be ignored by some compositors
- `max_visible_items`: number of rows before scrolling starts
- `center`: if `true`, NimLaunch ignores `position_x` and centers the window
- `position_x`, `position_y`: used only when `center = false`
- `vertical_align`: only used when centered; valid values are `top`, `center`,
  and `one-third`
- `display`: monitor index used when centered

## Font

```toml
[font]
fontname = "Dejavu:size=16"
```

This is a fontconfig-style font string. Use an installed font family and size.

Examples:

```toml
fontname = "Noto Sans:size=14"
fontname = "JetBrains Mono:size=15"
fontname = "Dejavu:size=16"
```

## Input

```toml
[input]
prompt = "> "
cursor = "_"
vim_mode = false
```

- `prompt`: prefix shown before the active query
- `cursor`: cursor glyph shown after the query
- `vim_mode`: enables Vim-style movement and command handling

## Terminal

```toml
[terminal]
program = "gnome-terminal"
```

This is used by `:r` and `!` commands. Set it to the terminal you actually use.

Examples:

```toml
program = "kitty"
program = "foot"
program = "gnome-terminal"
```

## Border

```toml
[border]
width = 2
```

Set `0` to disable the border completely.

## Icons

```toml
[icons]
enabled = true
```

NimLaunch resolves icons from standard desktop/icon-theme locations and loads
PNG and SVG icons through `SDL3_image`.

## Themes

Theme structure, selection, persistence, and custom theme examples are covered
in [Themes](themes.md).

## Generated Defaults

The checked-in [example config](../examples/nimlaunch.toml)
matches the embedded default template in
[`src/state.nim`](../src/state.nim).

That file is the reference for:

- first-run generated config
- default groups
- default shortcuts
- bundled themes

## Related Docs

- [Themes](themes.md)
- [Groups and Shortcuts](groups-and-shortcuts.md)
- [Dmenu Mode](dmenu.md)
