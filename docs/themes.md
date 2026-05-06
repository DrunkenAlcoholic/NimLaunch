# Themes

NimLaunch themes control the launcher colors and the persisted active theme.

Themes are configured in `~/.config/nimlaunch/nimlaunch.toml` with repeated
`[[themes]]` blocks plus a `[theme]` section for the current selection.

## Theme Block

Example:

```toml
[[themes]]
name                = "Nord"
bgColorHex          = "#2E3440"
fgColorHex          = "#D8DEE9"
highlightBgColorHex = "#88C0D0"
highlightFgColorHex = "#2E3440"
borderColorHex      = "#4C566A"
matchFgColorHex     = "#f8c291"
```

Fields:

- `name`: label shown in the `:t` selector
- `bgColorHex`: launcher background
- `fgColorHex`: normal text
- `highlightBgColorHex`: selected row background
- `highlightFgColorHex`: selected row text
- `borderColorHex`: border color
- `matchFgColorHex`: color used for matching characters in search results

All colors must be valid hex colors in `#RRGGBB` format.

## Selecting A Theme

Use the built-in theme selector:

```text
:t
```

Then:

- type to filter theme names
- use Up/Down to preview
- press `Enter` to keep the selected theme
- press `Esc` to cancel out of the selector

## Persisted Theme

The active saved theme is tracked separately:

```toml
[theme]
last_chosen = "Nord"
```

When a theme is accepted through `:t`, NimLaunch writes that value back to the
config file.

## If Theme Changes Do Not Persist

Common causes:

- the config file is not writable
- the config file contains invalid TOML
- the saved theme name does not exist in the `[[themes]]` list

If the TOML is invalid, NimLaunch prints a startup parse warning and falls back
to built-in defaults for that session.

## Custom Themes

You can add your own themes by appending more `[[themes]]` blocks.

Example:

```toml
[[themes]]
name                = "My Theme"
bgColorHex          = "#111111"
fgColorHex          = "#f0f0f0"
highlightBgColorHex = "#2a2a2a"
highlightFgColorHex = "#ffffff"
borderColorHex      = "#555555"
matchFgColorHex     = "#ff8c42"
```

## Reference Files

The generated default theme set is embedded in:

- [`src/state.nim`](../src/state.nim)

The checked-in sample config lives at:

- [examples/nimlaunch.toml](../examples/nimlaunch.toml)

## Related Docs

- [Configuration](configuration.md)
- [Groups and Shortcuts](groups-and-shortcuts.md)
- [Dmenu Mode](dmenu.md)
