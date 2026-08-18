#!/usr/bin/env bash
set -euo pipefail

NIMLAUNCH="nimlaunch"
if [[ -f "./bin/nimlaunch" ]]; then
    NIMLAUNCH="./bin/nimlaunch"
fi

WPCTL_BIN="${WPCTL_BIN:-wpctl}"
# PipeWire graph dump tool used to enumerate real Audio/Sink nodes.
PIPEWIRE_DUMP_BIN="${PIPEWIRE_DUMP_BIN:-pw-dump}"

if ! command -v "$NIMLAUNCH" >/dev/null 2>&1 && [[ ! -x "$NIMLAUNCH" ]]; then
  printf 'nimlaunch_audio: nimlaunch not found\n' >&2
  exit 127
fi

if ! command -v "$WPCTL_BIN" >/dev/null 2>&1; then
  printf 'audio-sink-picker: wpctl not found\n' >&2
  exit 127
fi

if ! command -v "$PIPEWIRE_DUMP_BIN" >/dev/null 2>&1; then
  printf 'audio-sink-picker: pw-dump not found\n' >&2
  exit 127
fi

default_sink_id() {
  "$WPCTL_BIN" inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '
    /^id[[:space:]]+[0-9]+,/ {
      gsub(",", "", $2)
      print $2
      exit
    }
  '
}

sink_rows() {
  "$PIPEWIRE_DUMP_BIN" --raw 2>/dev/null | perl -MJSON::PP -e '
    local $/;
    my $json = <STDIN>;
    my $data = eval { JSON::PP::decode_json($json) };
    exit 1 if !$data || ref($data) ne "ARRAY";
    for my $obj (@$data) {
      next if ref($obj) ne "HASH";
      next if ($obj->{type} // "") ne "PipeWire:Interface:Node";
      my $props = $obj->{info}{props} // {};
      next if ($props->{"media.class"} // "") ne "Audio/Sink";
      my $id = $obj->{id};
      next if !defined $id;
      my $name =
           $props->{"node.description"}
        // $props->{"device.description"}
        // $props->{"node.nick"}
        // $props->{"node.name"}
        // "Sink $id";
      $name =~ s/[\r\n]+/ /g;
      print "$id\t$name\n";
    }
  '
}

declare -a SINK_IDS=()
declare -a SINK_LABELS=()
DEFAULT_ID="$(default_sink_id)"

while IFS=$'\t' read -r id name; do
  [[ -n "$id" ]] || continue
  marker=" "
  [[ -n "${DEFAULT_ID:-}" && "$id" == "$DEFAULT_ID" ]] && marker="*"
  label="$marker $name"

  duplicate=0
  for existing in "${SINK_LABELS[@]:-}"; do
    if [[ "$existing" == "$label" ]]; then
      duplicate=1
      break
    fi
  done
  if ((duplicate)); then
    label="$marker $name ($id)"
  fi

  SINK_IDS+=("$id")
  SINK_LABELS+=("$label")
done < <(sink_rows)

((${#SINK_IDS[@]} > 0)) || exit 1

selection="$(
  printf '%b\n' "${SINK_LABELS[@]/%/\\0icon\\x1faudio-speakers}" | "$NIMLAUNCH" --dmenu
)" || exit $?
[[ -n "$selection" ]] || exit 1

sink_id=""
for i in "${!SINK_LABELS[@]}"; do
  if [[ "${SINK_LABELS[$i]}" == "$selection" ]]; then
    sink_id="${SINK_IDS[$i]}"
    break
  fi
done

[[ -n "$sink_id" ]] || exit 1

"$WPCTL_BIN" set-default "$sink_id"
