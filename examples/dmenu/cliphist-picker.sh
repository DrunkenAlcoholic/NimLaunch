#!/usr/bin/env bash
set -euo pipefail

launcher="${NIMLAUNCH_BIN:-nimlaunch}"

if ! command -v cliphist >/dev/null 2>&1; then
  printf 'cliphist-picker: cliphist is not installed\n' >&2
  exit 1
fi

selection="$(cliphist list | "$launcher" --dmenu)" || exit 1
[[ -n "$selection" ]] || exit 1

decoded="$(printf '%s\n' "$selection" | cliphist decode)"

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$decoded" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$decoded" | xclip -selection clipboard
else
  printf 'cliphist-picker: no clipboard writer found (need wl-copy or xclip)\n' >&2
  exit 1
fi

printf '%s\n' "$decoded"
