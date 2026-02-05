#!/usr/bin/env bash
set -euo pipefail

TEMP_NIGHT="${BLUELIGHT_TEMP:-4200}"
TEMP_DAY="${BLUELIGHT_DAY:-6500}"

if command -v wlsunset >/dev/null 2>&1; then
  NAME="wlsunset"
  CMD=(wlsunset -t "$TEMP_NIGHT" -T "$TEMP_DAY")
elif command -v gammastep >/dev/null 2>&1; then
  NAME="gammastep"
  CMD=(gammastep -O "$TEMP_NIGHT")
elif command -v redshift >/dev/null 2>&1; then
  NAME="redshift"
  CMD=(redshift -O "$TEMP_NIGHT")
else
  NAME=""
  CMD=()
fi

is_on() {
  pgrep -x "$NAME" >/dev/null 2>&1
}

if [[ "${1:-}" == "--status" ]]; then
  if [[ -z "$NAME" ]]; then
    echo "󰖙"
  elif is_on; then
    echo "󰖔"
  else
    echo "󰖙"
  fi
  exit 0
fi

if [[ -z "$NAME" ]]; then
  echo "bluelight-toggle: install wlsunset, gammastep, or redshift" >&2
  exit 1
fi

if is_on; then
  pkill -x "$NAME"
else
  "${CMD[@]}" >/dev/null 2>&1 & disown
fi
