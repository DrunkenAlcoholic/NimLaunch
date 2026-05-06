# Groups And Shortcuts

NimLaunch supports two related config concepts:

- `shortcuts`: actions triggered by a prefix or by selecting a grouped entry
- `groups`: named collections used to organize shortcuts

These are declared in `~/.config/nimlaunch/nimlaunch.toml`.

## Shortcut Fields

Each `[[shortcuts]]` block can use:

- `prefix`
- `label`
- `base`
- `mode`
- `group`
- `run_mode`
- `stay_open`

Example:

```toml
[[shortcuts]]
prefix = ":g"
label  = "Search Google: "
base   = "https://www.google.com/search?q={query}"
mode   = "url"
```

Meaning:

- `prefix`: what you type to trigger the shortcut
- `label`: text shown in the UI before your query
- `base`: URL, shell command, or file path template
- `mode`: one of `url`, `shell`, or `file`
- `group`: optional group name such as `sys` or `media`
- `run_mode`: for shell actions, either `terminal` or `spawn`
- `stay_open`: keep NimLaunch open after running the action

## Prefix Shortcuts

Prefix shortcuts are for direct command-style actions.

Example:

```toml
[[shortcuts]]
prefix = ":w"
label  = "Search Wiki: "
base   = "https://en.wikipedia.org/wiki/Special:Search?search={query}"
mode   = "url"
```

Usage:

```text
:w nim language
```

The `{query}` placeholder is replaced with the typed query text.

## Shortcut Modes

### URL

Opens a browser or URL handler.

```toml
[[shortcuts]]
prefix = ":y"
label  = "Search YouTube: "
base   = "https://www.youtube.com/results?search_query={query}"
mode   = "url"
```

### Shell

Runs a command.

```toml
[[shortcuts]]
prefix   = ":term"
label    = "Open btop: "
base     = "btop"
mode     = "shell"
run_mode = "terminal"
```

Use `run_mode = "spawn"` when the command should run directly without opening a
terminal window.

### File

Opens a file or path through the default handler.

```toml
[[shortcuts]]
prefix = ":docs"
label  = "Open Docs: "
base   = "~/Documents/{query}"
mode   = "file"
```

## Groups

Groups are named shortcut collections. They are useful when you want one prefix
to expose a menu of related actions.

Example:

```toml
[[groups]]
name = "sys"
query_mode = "filter"
```

Then attach shortcuts to that group:

```toml
[[shortcuts]]
group     = "sys"
label     = "Lock"
base      = "loginctl lock-session"
mode      = "shell"
run_mode  = "spawn"
stay_open = false
```

Usage:

```text
:sys lock
```

## Group Query Modes

Each group has a `query_mode`:

- `filter`
- `pass`

### filter

The default. NimLaunch filters the items inside that group using the typed text.

Example:

```toml
[[groups]]
name = "sys"
query_mode = "filter"
```

Typing `:sys re` narrows the group to actions such as `Reboot`.

### pass

The query is passed through to the selected shortcut instead of being used only
as a filter. This is useful when a grouped action still needs the free-form
query text.

## Example: Media Group

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

## Example: Web Shortcuts

```toml
[[shortcuts]]
prefix = ":gh"
label  = "Search GitHub: "
base   = "https://github.com/search?q={query}"
mode   = "url"

[[shortcuts]]
prefix = ":aw"
label  = "Search Arch Wiki: "
base   = "https://wiki.archlinux.org/index.php?search={query}"
mode   = "url"
```


## Related Docs

- [Themes](themes.md)
- [Configuration](configuration.md)
- [Dmenu Mode](dmenu.md)
