# Android export

Godot 4.3 debug APK for the fixed-cam station. This file is the export path. It does not build or upload an APK.

The project already uses the Compatibility renderer on desktop and mobile (`renderer/rendering_method` and `renderer/rendering_method.mobile` are `gl_compatibility`). The main scene is `res://scenes/main.tscn`. The window is 1600×720, landscape, stretch mode `canvas_items`.

`export_presets.cfg` is gitignored. Create it on the machine that exports. Do not commit a keystore, a keystore password, or the APK.

## Before export

From the repo root, with Godot 4.3.stable:

```bash
godot --headless --path . --script res://scripts/sim/self_test.gd
```

That must print `SELF_TEST_OK`.

The sealed sub-bay plate stays the densified capture from main:

- `proof-fixedcam/14-subbay-closed.png`
- md5 `839d8c2641a66464034d96a04ed0f0af`
- 74162 bytes

Two orange end pontoons, blue center hatch, open water between the pontoons. Do not replace that file with an older plate.

## One-time editor setup

1. Install the Godot 4.3.stable Android export templates. The template version has to match the editor (`4.3.stable`).
2. Install JDK 17 and the Android SDK command-line tools. The first Gradle export needs network access so it can download its build dependencies.
3. In Godot: **Editor → Editor Settings → Export → Android**.
   - Set the Android SDK path and the JDK path.
   - Create the debug keystore from that settings page. Leave the release keystore empty until a store build is actually requested.
4. **Project → Export → Add… → Android**. Name the preset `Android`.
   - Unique name: `app.tj.aistation`. Keep that name once a device has installed a build.
   - Version name `0.1.0`, version code `1`. The delivered file is `AIStation-0.1.0.apk`.
   - Architectures: `arm64-v8a` for phones. Add `x86_64` only for an emulator.
   - Orientation: landscape.
   - Do not add extra permissions. The sim is offline.
5. Save the preset. It stays in the local `export_presets.cfg`.

## Build a debug APK

Editor: select the Android preset, turn on **Export With Debug**, and write `build/ai-station-debug.apk`.

Command line, after the preset exists:

```bash
mkdir -p build
godot --headless --path . --export-debug "Android" build/ai-station-debug.apk
```

Install on a device with USB debugging:

```bash
adb install -r build/ai-station-debug.apk
```

On the phone, check the sealed hatch plate, pause (the hatch and sub must freeze), and one sortie that returns cargo into station stock. When that APK is ready for Jay, send the chat message and the download link.
