# Groups and Shortcuts

NimLaunch supports two related configuration concepts for organizing commands:

- **Shortcuts**: Actions triggered by a prefix or by selecting a grouped entry.
- **Groups**: Named collections used to organize shortcuts.

These are declared in `~/.config/nimlaunch/nimlaunch.toml`.

## Shortcut Fields

Each `[[shortcuts]]` block supports the following fields:

```toml
[[shortcuts]]
prefix = ":g"
label  = "Search Google: "
base   = "https://www.google.com/search?q={query}"
mode   = "url"
```

- **`prefix`**: The text typed to trigger the shortcut.
- **`label`**: The text shown in the UI before your query.
- **`base`**: The URL, shell command, or file path template.
- **`mode`**: The action type, which can be `url`, `shell`, or `file`.
- **`group`**: An optional group name to attach this shortcut to (e.g., `sys` or `media`).
- **`run_mode`**: For shell actions, specifies either `terminal` or `spawn`.
- **`stay_open`**: If `true`, NimLaunch remains open after running the action.

## Prefix Shortcuts

Prefix shortcuts are designed for direct command-style actions.

```toml
[[shortcuts]]
prefix = ":w"
label  = "Search Wiki: "
base   = "https://en.wikipedia.org/wiki/Special:Search?search={query}"
mode   = "url"
```

Usage: `:w nim language`

The `{query}` placeholder is replaced with the typed query text. 

> **Note on Shell Commands:** When `mode = "shell"`, NimLaunch automatically wraps `{query}` in shell-safe single quotes to prevent command injection. Do not wrap `{query}` in quotes in your configuration file.

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
Runs a command. Use `run_mode = "spawn"` when the command should run directly in the background without opening a terminal window.

```toml
[[shortcuts]]
prefix   = ":term"
label    = "Open btop: "
base     = "btop"
mode     = "shell"
run_mode = "terminal"
```

### File
Opens a file or path through the default system handler.

```toml
[[shortcuts]]
prefix = ":docs"
label  = "Open Docs: "
base   = "~/Documents/{query}"
mode   = "file"
```

## Groups

Groups act as named collections for shortcuts, allowing a single prefix to expose a menu of related actions. 

**Important:** Group definitions are completely optional. If you assign a shortcut to a group (e.g., `group = "scripts"`), NimLaunch automatically registers that group and uses the default `filter` behavior. 

The only time you must explicitly declare a `[[groups]]` block is when you want to change its `query_mode` from `"filter"` to `"pass"`.

### Example: Implicit Filter Group

You can create a group simply by referencing it in your shortcuts:

```toml
[[shortcuts]]
group     = "sys"
label     = "Lock"
base      = "loginctl lock-session"
mode      = "shell"
run_mode  = "spawn"
stay_open = false
```

Usage: `:sys lock`

Because `sys` is used as a `group` in a shortcut, NimLaunch registers it automatically as a `filter` group.

## Group Query Modes

A group can have one of two `query_mode` settings: `filter` or `pass`.

### filter (Default)

NimLaunch uses the typed text to filter the items inside the group. This is the default behavior and does not require an explicit `[[groups]]` block. 

Typing `:sys re` narrows the group to actions matching "re" (such as "Reboot"). This is ideal when choosing between a set of fixed actions.

### pass

The `pass` mode forwards the raw query text to the selected shortcut instead of using it to filter the menu. This is useful when the grouped action requires free-form query input.

To use `pass` mode, you must explicitly declare the group in your configuration:

```toml
[[groups]]
name = "svc"
query_mode = "pass"

[[shortcuts]]
group = "svc"
label = "systemctl status: "
base  = "systemctl status {query}"
mode  = "shell"

[[shortcuts]]
group = "svc"
label = "systemctl cat: "
base  = "systemctl cat {query}"
mode  = "shell"
```

Usage: `:svc ssh`

Choosing `systemctl status: ` runs `systemctl status ssh`. This makes `pass` mode an excellent fit for read-only inspection commands or search-style actions where the input forms the arguments.

## Related Documentation

- [Themes](themes.md)
- [Configuration](configuration.md)
- [Dmenu Mode](dmenu.md)
