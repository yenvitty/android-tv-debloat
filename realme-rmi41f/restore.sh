#!/usr/bin/env bash
# restore.sh — undo the debloat on the realme TechLife RMI41F (Google TV, Android 14).
# Re-enables every package listed in disabled_packages.txt. Refuses to run on any other model.
#
# It does NOT touch com.cltv.hybrid: that was already disabled through TV Settings before this
# work started. Nor does it change Home: the stock launcher was never disabled on this TV.
#
# Usage:   TV_IP=192.168.1.50 ./restore.sh
#          TV_IP=192.168.1.50 DRY_RUN=1 ./restore.sh    (print the commands, change nothing)
set -u

TV_IP="${TV_IP:?Set TV_IP to the IP address of your TV, e.g. TV_IP=192.168.1.50 ./restore.sh}"
SERIAL="$TV_IP:5555"
EXPECTED_MODEL="RMI41F"
DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/disabled_packages.txt"

run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

shell() { run adb -s "$SERIAL" shell "$@"; }

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install with: brew install android-platform-tools" >&2
  exit 1
fi

run adb connect "$SERIAL"
if [ "${DRY_RUN:-0}" != "1" ]; then
  state="$(adb -s "$SERIAL" get-state 2>/dev/null)"
  if [ "$state" != "device" ]; then
    echo "TV at $SERIAL is not connected/authorized (state: ${state:-none})." >&2
    echo "Accept the 'Allow USB debugging?' popup on the TV and re-run." >&2
    exit 1
  fi
  model="$(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
  if [ "$model" != "$EXPECTED_MODEL" ]; then
    echo "REFUSING: $SERIAL is '$model', not $EXPECTED_MODEL. Find the right IP and use TV_IP=..." >&2
    exit 1
  fi
fi

failed=0
if [ -f "$LIST" ]; then
  # Re-enable in reverse order (last disabled comes back first).
  pkgs="$(grep -vE '^[[:space:]]*(#|$)' "$LIST" | awk '{print $1}' | tail -r 2>/dev/null || true)"
  for pkg in $pkgs; do
    echo "Enabling $pkg"
    shell pm enable "$pkg" || failed=1
  done
else
  echo "No $LIST found; nothing to re-enable."
fi

echo "Home now resolves to:"
shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

echo "Still disabled on the TV (com.cltv.hybrid was already disabled before this work):"
shell pm list packages -d

if [ "$failed" -ne 0 ]; then
  echo "Some commands failed; read the output above." >&2
  exit 1
fi
echo "Restore complete."
