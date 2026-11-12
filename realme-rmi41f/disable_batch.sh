#!/usr/bin/env bash
# disable_batch.sh — disable up to 5 packages for user 0 on the realme RMI41F (reversible with restore.sh).
# Each package is appended to disabled_packages.txt only if the TV confirms it.
# Refuses to run on any other model.
#
# Usage:   TV_IP=192.168.1.50 ./disable_batch.sh pkg1 [pkg2 ... pkg5]
set -u

TV_IP="${TV_IP:?Set TV_IP to the IP address of your TV, e.g. TV_IP=192.168.1.50 ./disable_batch.sh pkg}"
SERIAL="$TV_IP:5555"
EXPECTED_MODEL="RMI41F"
DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="$DIR/disabled_packages.txt"

# Hard stop list: never disable these, whatever is passed in.
# launcherx + setupwraith: launcherx has Home priority 2, setupwraith's RecoveryActivity priority 1,
# Projectivy 0. Disabling launcherx hands Home to the setup wizard, which factory-reset a sibling TV.
PROTECTED="android com.android.shell com.android.systemui com.android.tv.settings
com.google.android.packageinstaller com.google.android.permissioncontroller
com.google.android.inputmethod.latin com.realtek.rtkvirtualkeyboard com.android.inputdevices
com.android.bluetooth com.google.android.tv.remote.service com.google.android.tv.googletvremotepairer
com.google.android.tv.googletvremotepairer.customizationsample com.google.android.tv.dfuservice com.realsil.ota
com.google.android.tv.globalkeyhandler com.realtek.globalkeyhandler
com.google.android.tv.inputplayer com.realtek.android.tv.inputplayer.customization
com.realtek.tv com.realtek.tv.passthrough com.realtek.tv.atv com.realtek.dtv com.android.providers.tv
com.realtek.systemservice com.realtek.power com.realtek.energymode com.realtek.display.monitor
com.realtek.menu com.realtek.slices com.realtek.service.agent com.realtek.mdnsoffload
com.android.tv.mdnsoffloadmanager com.realtek.connecteddevices com.realtek.leanbacklauncher.partnercustomizer
com.cltv.mal com.vewd.core.service com.google.android.katniss com.google.android.apps.mediashell
com.google.android.gms com.google.android.gsf com.android.vending
com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith com.realtek.setupwizard
com.hk.factorymenu com.factory.factoryautomation com.realtek.tvfactory
com.android.providers.settings com.android.providers.media com.android.providers.media.module
com.android.providers.downloads com.android.networkstack com.android.networkstack.tethering
com.android.wifi.resources com.google.android.webview com.dolby.android.audio.service
com.netflix.tokenmanager com.spocky.projengmenu com.google.android.youtube.tv com.netflix.ninja
in.startv.hotstar com.graymatrix.did com.amazon.amazonvideo.livingroom"

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
