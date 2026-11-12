#!/usr/bin/env bash
# restore.sh — undo the debloat on the Xiaomi MiTV-MOSR1 (L40M7-EAIN).
# Re-enables every package listed in disabled_packages.txt, then makes sure the
# original launcher (com.google.android.tvlauncher) is enabled and set as Home.
#
# Usage:   TV_IP=192.168.1.50 ./restore.sh
#          TV_IP=192.168.1.50 DRY_RUN=1 ./restore.sh    (print the commands, change nothing)
# Refuses to run on any model other than MiTV-MOSR1.
set -u

TV_IP="${TV_IP:?Set TV_IP to the IP address of your TV, e.g. TV_IP=192.168.1.50 ./restore.sh}"
SERIAL="$TV_IP:5555"
EXPECTED_MODEL="MiTV-MOSR1"
DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/disabled_packages.txt"
ORIGINAL_HOME="com.google.android.tvlauncher/.MainActivity"
ORIGINAL_HOME_PKG="${ORIGINAL_HOME%%/*}"

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
  echo "No $LIST found; only restoring the original launcher."
fi

echo "Restoring original launcher $ORIGINAL_HOME"
shell pm enable "$ORIGINAL_HOME_PKG" || failed=1
shell cmd package set-home-activity "$ORIGINAL_HOME" || failed=1

# Was switched off in Settings > Device Preferences > PatchWall to stop the boot splash.
echo "Turning 'Set PatchWall as default launcher' back on"
shell settings put global set_patchwall_default 1 || failed=1

echo "Home now resolves to:"
shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

echo "Still disabled on the TV (should be empty or only things you disabled yourself):"
shell pm list packages -d

if [ "$failed" -ne 0 ]; then
  echo "Some commands failed; read the output above." >&2
  exit 1
fi
echo "Restore complete. Press Home on the remote, or run: adb -s $SERIAL reboot"
