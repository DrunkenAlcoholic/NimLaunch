# Dmenu Mode

Using the `--dmenu` flag turns NimLaunch into a generic selector interface.

Instead of scanning desktop applications, NimLaunch reads newline-separated items from standard input (`stdin`), displays them in the standard launcher UI, and outputs the selected line to standard output (`stdout`).

## Basic Behavior

Example:

```bash
printf "one\ntwo\nthree\n" | nimlaunch --dmenu
```

Behavior:

- **`Enter`**: Prints the selected line to `stdout` and exits with status `0`.
- **`Esc`**: Cancels the selection and exits with status `1`.
- **Empty Query**: Preserves the original input order without filtering.

This mode is designed for wrapper scripts and global selection menus.

## Icon Support

NimLaunch natively supports Rofi's inline icon syntax. By appending `\0icon\x1f<icon-name>` to any line, NimLaunch extracts the label, renders the icon using your current system theme, and returns only the clean label to `stdout` upon selection.

Example:

```bash
printf "Terminal\0icon\x1futilities-terminal\nFirefox\0icon\x1ffirefox\n" | nimlaunch --dmenu
```

## Good Use Cases

The `--dmenu` mode is highly effective when the source list is dynamic, global, text-first, and independent of the current shell working directory. 

Common applications include:
- Audio sink pickers
- Power and session menus
- SSH host selectors
- Recent document pickers
- Device or profile selectors

## Provided Examples

The repository includes several practical examples in the `examples/scripts/` directory demonstrating the capabilities of `--dmenu`:

1. **[nimlaunch_audio.sh](../examples/scripts/nimlaunch_audio.sh)**
   - Enumerates real PipeWire `Audio/Sink` nodes.
   - Sets the selected sink as the new default through `wpctl`.

2. **[nimlaunch_bluetooth.sh](../examples/scripts/nimlaunch_bluetooth.sh)**
   - Uses `bluetoothctl` to list all paired devices dynamically.
   - Toggles the connection on or off for the selected device.

3. **[nimlaunch_wifi.sh](../examples/scripts/nimlaunch_wifi.sh)**
   - Uses `nmcli` to scan and list nearby WiFi networks.
   - Connects to the selected network.

4. **[nimlaunch_cliphist.sh](../examples/scripts/nimlaunch_cliphist.sh)**
   - Hooks into `wl-clipboard` (via `cliphist`) to show recent clipboard items.
   - Copies the selected history item back into your active clipboard.

5. **[nimlaunch_klipper.sh](../examples/scripts/nimlaunch_klipper.sh)**
   - Designed for KDE Plasma users. Hooks into Klipper natively via `busctl` and `jq` without any X11/Wayland dependency issues.
   - Copies the selected history item back into your active clipboard.

6. **[nimlaunch_power.sh](../examples/scripts/nimlaunch_power.sh)**
   - A clean, icon-supported exit menu (Lock, Suspend, Logout, Reboot, Shutdown).
   - Safely triggers system state changes using `systemctl` or `loginctl`.

## Building Custom Scripts

You can build your own scripts that pipe content into NimLaunch. The standard wrapper pattern involves generating a list, piping it into NimLaunch, and processing the result.

Skeleton script:

```bash
#!/bin/bash

# 1. Build a newline-separated list and pipe it into NimLaunch
choice="$(printf "Option 1\nOption 2\nOption 3\n" | nimlaunch --dmenu)" || exit 1

# 2. Ensure a choice was made
[ -n "$choice" ] || exit 1

# 3. Perform the action
echo "You selected: $choice"
```

## Integrating Scripts into NimLaunch

Custom scripts can be exposed directly through NimLaunch using grouped shortcuts.

Example configuration:

```toml
[[shortcuts]]
group    = "media"
label    = "Audio Sink"
base     = "~/.local/bin/nimlaunch_audio.sh"
mode     = "shell"
run_mode = "spawn"
```

This allows you to trigger your script seamlessly from within the launcher (e.g., typing `:media audio`).

## Related Documentation

- [Themes](themes.md)
- [Configuration](configuration.md)
- [Groups and Shortcuts](groups-and-shortcuts.md)
