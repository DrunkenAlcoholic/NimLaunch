#!/usr/bin/env bash
set -euo pipefail

launcher="${NIMLAUNCH_BIN:-nimlaunch}"
repo_root="${1:-.}"

if ! command -v git >/dev/null 2>&1; then
  printf 'git-branch-picker: git is not installed\n' >&2
  exit 1
fi

if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  printf 'git-branch-picker: not a git repository: %s\n' "$repo_root" >&2
  exit 1
fi

selection="$({
  git -C "$repo_root" for-each-ref --format='%(refname:short)' refs/heads refs/remotes | awk '!seen[$0]++'
} | "$launcher" --dmenu)" || exit 1

[[ -n "$selection" ]] || exit 1

if [[ "$selection" == remotes/* ]]; then
  branch="${selection#remotes/}"
  branch="${branch#*/}"
  exec git -C "$repo_root" switch --track "$selection"
else
  exec git -C "$repo_root" switch "$selection"
fi
