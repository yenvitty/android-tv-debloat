#!/usr/bin/env bash
# disable_batch.sh — disable up to 5 packages for user 0 (reversible with restore.sh).
# Each package is appended to disabled_packages.txt only if the TV confirms it.
#
# Refuses to run on any model other than MiTV-MOSR1.
#
# Usage:   TV_IP=192.168.1.50 ./disable_batch.sh pkg1 [pkg2 ... pkg5]
set -u

TV_IP="${TV_IP:?Set TV_IP to the IP address of your TV, e.g. TV_IP=192.168.1.50 ./disable_batch.sh pkg}"
SERIAL="$TV_IP:5555"
EXPECTED_MODEL="MiTV-MOSR1"
DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/disabled_packages.txt"

# Hard stop list: never disable these, whatever is passed in.
PROTECTED="com.android.systemui com.android.tv.settings com.google.android.packageinstaller
com.google.android.inputmethod.latin com.android.bluetooth com.mi.bluetooth
com.google.android.tv.remote.service com.google.android.katniss com.google.android.apps.mediashell
com.google.android.gms com.google.android.gsf com.android.vending mitv.service com.mitv.overseaservice
com.mitv.livetv com.mitv.tvhome.atv com.mitv.tvhome.mitvplus com.mediatek.tvinput com.mediatek.tv.service
com.mediatek.tv.agent com.mediatek.network com.android.providers.tv com.android.providers.settings
com.google.android.tungsten.setupwraith com.duokan.factorytest mediatek.factorymenu.ui
com.android.networkstack.inprocess com.android.wifi.resources com.dolby.android.audio.service
com.google.android.webview android com.xiaomi.android.tvsetup.partnercustomizer
com.google.android.youtube.tv com.netflix.ninja in.startv.hotstar com.graymatrix.did
com.amazon.amazonvideo.livingroom com.jio.media.stb.ondemand com.google.android.videos
com.google.android.play.games com.google.android.youtube.tvmusic com.mitv.videoplayer
com.xiaomi.mitv.smartshare com.xiaomi.wfdsinkhelperservice com.mxtech.videoplayer.television"

if [ "$#" -lt 1 ] || [ "$#" -gt 5 ]; then
  echo "Pass 1 to 5 package names." >&2
  exit 1
fi

[ "$(adb -s "$SERIAL" get-state 2>/dev/null)" = "device" ] || { echo "TV not connected." >&2; exit 1; }

model="$(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
if [ "$model" != "$EXPECTED_MODEL" ]; then
  echo "REFUSING: $SERIAL is '$model', not $EXPECTED_MODEL." >&2
  exit 1
fi

for pkg in "$@"; do
  for p in $PROTECTED; do
    [ "$pkg" = "$p" ] && { echo "REFUSING protected package: $pkg" >&2; exit 1; }
  done
done

for pkg in "$@"; do
  out="$(adb -s "$SERIAL" shell pm disable-user --user 0 "$pkg" 2>&1)"
  echo "$out"
  if echo "$out" | grep -q "new state: disabled-user"; then
    grep -qx "$pkg" "$LIST" 2>/dev/null || echo "$pkg" >> "$LIST"
  else
    echo "!! $pkg was NOT disabled; stopping this batch." >&2
    exit 1
  fi
done

echo "--- health check"
adb -s "$SERIAL" shell dumpsys activity activities | grep -i resumed | head -3
echo "--- MemAvailable"
adb -s "$SERIAL" shell grep MemAvailable /proc/meminfo
