#!/usr/bin/env bash
set -euo pipefail

launcher="${NIMLAUNCH_BIN:-nimlaunch}"
projects_root="${PROJECTS_ROOT:-$HOME/Projects}"
projects_depth="${PROJECTS_DEPTH:-2}"

if [[ ! -d "$projects_root" ]]; then
  printf 'project-picker: directory not found: %s\n' "$projects_root" >&2
  exit 1
fi

if command -v fd >/dev/null 2>&1; then
  selection="$({
    fd . "$projects_root" -t d -d "$projects_depth" --absolute-path
  } | "$launcher" --dmenu)" || exit 1
else
  selection="$({
    find "$projects_root" -mindepth 1 -maxdepth "$projects_depth" -type d | sort
  } | "$launcher" --dmenu)" || exit 1
fi

[[ -n "$selection" ]] || exit 1

if command -v zed >/dev/null 2>&1; then
  exec zed "$selection"
elif command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "$selection"
else
  printf '%s\n' "$selection"
fi
