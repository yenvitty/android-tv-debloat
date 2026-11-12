# android-tv-debloat

Reversible debloating of two budget smart TVs over ADB on home Wi-Fi. No root, no uninstalls, no firmware changes:
every change is `pm disable-user --user 0 <package>`, logged to a file, and undone by one script.

| TV | OS | RAM | What changed |
| --- | --- | --- | --- |
| [Xiaomi Smart TV 5A 40" (L40M7-EAIN, `MiTV-MOSR1`)](xiaomi-5a/) | Android TV 11 + PatchWall | 1.5 GB | 13 packages disabled, Projectivy Launcher as Home, boots straight to it |
| [realme TechLife `RMI41F`](realme-rmi41f/) | Google TV, Android 14 | 940 MB | 4 packages disabled, a looping Play Store sync stopped |

> **Use at your own risk.** These lists were checked on one unit of each model, on the firmware noted below.
> Other models and firmware ship different packages. Check your own TV's package list before disabling anything.

## Rules I followed

1. Only `pm disable-user --user 0`. Everything comes back with `pm enable`, and nothing is uninstalled.
2. Never disable: System UI, Settings, the package installer, the keyboard, Bluetooth and remote services, network and Wi-Fi,
   HDMI/TV input services, Google Play Services, Play Store, Chromecast, voice search, the setup wizard, or factory apps.
   When unsure, leave it enabled.
3. Write `restore.sh` and dry-run it **before** the first disable.
4. At most 5 packages per batch. After each batch: the TV still responds, the streaming apps open, and the crash log is empty.
5. The scripts refuse protected packages, and refuse to run on any other TV model, in case the router reassigns IP addresses.

## Xiaomi Smart TV 5A (`MiTV-MOSR1`, firmware `RTT8.210119.001.1086`)

Disabled ([list](xiaomi-5a/disabled_packages.txt)):

| Package | What it is |
| --- | --- |
| `com.miui.tv.analytics` | Xiaomi analytics |
| `com.xiaomi.statistic` | Xiaomi statistics and log upload |
| `com.mitv.tvhome.michannel` | Xiaomi recommendation rows |
| `com.xm.webcontent` | Xiaomi promo web content |
| `com.xiaomi.mitv.tvmanager` | "TV Manager" cleaner |
| `fusion.android.tv.demo` | In-store demo loop |
| `android.autoinstalls.config.xiaomi.amelie` | Silent installer for preloaded apps |
| `com.xiaomi.mitv.handbook` | On-screen manual |
| `com.xiaomo.tv.milegal` | Legal notices viewer |
| `com.mitv.toolhouse` | Xiaomi toolbox |
| `com.google.android.partnersetup` | Google partner attribution |
| `com.google.android.feedback` | Feedback reporter |
| `com.google.android.tvlauncher` | Stock Android TV home, only after Projectivy was installed and tested |

- **Launcher:** Projectivy Launcher from the Play Store. Home goes straight to it once the stock home is disabled.
- **PatchWall splash at power-on:** turn off *Settings → Device Preferences → PatchWall → Set PatchWall as default launcher*.
  The TV then boots straight into the launcher. `restore.sh` turns this back on.
- **Keep enabled on this model:**
  - `com.mitv.tvhome.atv` (PatchWall), which hosts the Input/source popup
  - `com.mitv.livetv`, the HDMI input switcher
  - `com.mitv.tvhome.mitvplus`, which registers a TV input
  - `mitv.service`
  - `com.mitv.overseaservice`, which handles the Netflix button
  - `com.xiaomi.android.tvsetup.partnercustomizer` and `com.mediatek.tv.service`, which receive the remote's shortcut keys
- **Result:**
  - The launcher dropped from about 131 MB to 58 MB.
  - Analytics and TV Manager (about 27 MB) no longer run.
  - After heavy use, available RAM ends up similar to before, because Android fills spare memory with cached apps.
    The gain is that less of it goes to things you never use.

## realme TechLife `RMI41F` (firmware `UKRE.260524.033`)

Disabled ([list](realme-rmi41f/disabled_packages.txt)):

| Package | What it is |
| --- | --- |
| `tv.anoki.acr.anokiacroptin` | Anoki "Viewing Information Service": controls ACR (viewing-tracking) opt-in |
| `com.realtek.retailmode` | In-store demo mode |
| `com.google.android.feedback` | Feedback reporter |
| `com.google.android.partnersetup` | Google partner attribution |

**Do not disable the stock launcher on this TV.** These are the apps that can answer the Home button, and their priorities:

| Home app | Priority |
| --- | --- |
| `com.google.android.apps.tv.launcherx` (stock Google TV home) | 2 |
| `com.google.android.tungsten.setupwraith/.RecoveryActivity` (setup wizard) | 1 |
| `com.spocky.projengmenu` (Projectivy) | 0 |

With the stock launcher disabled, the setup wizard takes over Home. On a related Xiaomi Google TV model, documented in
cleanyourtv, a reboot in that state re-ran setup and factory-reset the TV. Here, Projectivy holds the Home role and uses
its accessibility service to take over from the stock launcher.

- **Play Store loop:** after boot, the Play Store kept repeating "replicate library" sync requests, about 24 a minute.
  It used 20–24% of a CPU core and grew to about 170 MB. `adb shell am force-stop com.android.vending` stopped it,
  and it had not come back after a reboot. The cause is unknown.
- **Not removable this way:** the native `vendor.anoki.acrservice` service keeps running, at about 1 MB.
- **Result:** available RAM 6 minutes after boot went from 376 MB to 387 MB, which is within normal variation.
  The disabled packages were not running at idle. The real speed gain was the Play Store fix.

## How to use

```bash
brew install android-platform-tools          # macOS; installs adb
adb connect 192.168.1.50:5555                # your TV's IP; accept "Allow USB debugging?" on the TV
TV_IP=192.168.1.50 DRY_RUN=1 ./restore.sh    # check what an undo would do
TV_IP=192.168.1.50 ./disable_batch.sh com.example.one com.example.two   # 1 to 5 packages per batch
TV_IP=192.168.1.50 ./restore.sh              # undo everything in disabled_packages.txt
```

Run the commands from inside the TV's folder (`xiaomi-5a/` or `realme-rmi41f/`). The protected lists in
`disable_batch.sh` include the streaming apps I use, so edit them to suit yours.

**When you are done, turn USB debugging off on the TV.** Network ADB on port 5555 is unencrypted, so any device on
your Wi-Fi could try to connect.

## Files in each folder

| File | Contents |
| --- | --- |
| `packages_before.txt` | Every package on the TV before any change |
| `baseline_before.txt`, `baseline_after.txt` | RAM, storage and launcher, before and after |
| `disabled_packages.txt` | What was disabled, in order |
| `disable_batch.sh` | Disables 1 to 5 packages, logs only confirmed ones, refuses protected packages and other models |
| `restore.sh` | Re-enables everything in `disabled_packages.txt` (supports `DRY_RUN=1`) |

## Credits

- [cleanyourtv](https://github.com/Gathin23/cleanyourtv), whose device notes for the `MiTV-MOSR1` and related models
  flagged the packages and launcher swaps to avoid.

## License

[MIT](LICENSE)
