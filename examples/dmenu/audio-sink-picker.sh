#!/usr/bin/env bash
set -euo pipefail

launcher="${NIMLAUNCH_BIN:-nimlaunch}"

if ! command -v wpctl >/dev/null 2>&1; then
  printf 'audio-sink-picker: wpctl is not installed\n' >&2
  exit 1
fi

selection="$({
  wpctl status |
    sed -n '/Sinks:/,/Sources:/p' |
    sed '1d;$d' |
    sed -E 's/^([[:space:]]*)(\*?)([[:space:]]*)([0-9]+)\.([[:space:]]*)(.*)$/\4\t\6/'
} | "$launcher" --dmenu)" || exit 1

[[ -n "$selection" ]] || exit 1

sink_id="${selection%%$'\t'*}"
[[ -n "$sink_id" ]] || exit 1

exec wpctl set-default "$sink_id"
