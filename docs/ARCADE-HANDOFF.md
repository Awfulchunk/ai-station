# Arcade handoff — AI Station 0.1.0

Standalone Godot APK first. This is not an arcade WebView game and it is not `GAME_SRC`. Do not iframe it. Do not fold it into `ToughAndJsArcade-*.apk`.

List it later on https://awfulchunk.github.io/arcade/download.html the same way the Empire Clash standalones are listed: a file in the site root next to `download.html`, and a download link on the card.

## Lock

| | |
| --- | --- |
| Artifact name | `AIStation-0.1.0.apk` |
| Package id | `app.tj.aistation` |
| versionName | `0.1.0` |
| versionCode | `1` |
| Card name | AI Station |
| Size cap | about 750MB–1GB is fine |

The keystore and the APK stay out of git. Copy the artifact onto the arcade repo by hand.

## Card

```html
<h3>AI Station</h3>
<p class="sub">Standalone Godot APK · 0.1.0 · app.tj.aistation</p>
<a href="AIStation-0.1.0.apk" download>Download AI Station APK (0.1.0)</a>
```

Put `AIStation-0.1.0.apk` beside `EmpireClash-1.0.5.apk`. The public link is:

https://awfulchunk.github.io/arcade/AIStation-0.1.0.apk

## This build

`godot --headless --path . --script res://scripts/sim/self_test.gd` printed `SELF_TEST_OK` before export.

| | |
| --- | --- |
| Artifact | `/opt/cursor/artifacts/AIStation-0.1.0.apk` |
| Bytes | 33953833 |
| md5 | `f77c5d105b8fbe3ef311c58ff817e9b0` |
| ABI | `arm64-v8a` only |
| Orientation | landscape (`android:screenOrientation` 0) |
| Renderer | Compatibility (`gl_compatibility`) |
| Permissions | none |
| Signing | debug APK, `android:debuggable=true`, apksigner verify passed |

Local export path is gitignored `build/ai-station-debug.apk`. The file that goes on the hub is `AIStation-0.1.0.apk`.

`proof-fixedcam/14-subbay-closed.png` is still md5 `839d8c2641a66464034d96a04ed0f0af`, 74162 bytes. `PontoonLayer` stays hidden. The APK packs the live `scripts/cutaway` pontoon and hatch, not `jay-lock`.

## Export again

Godot 4.3.stable. Copy `export_presets.cfg.example` to `export_presets.cfg` (gitignored). Leave the keystore lines empty. Package id in that preset is `app.tj.aistation`. versionName is `0.1.0`. versionCode is `1`.

```bash
godot --headless --path . --script res://scripts/sim/self_test.gd
mkdir -p build
godot --headless --path . --export-debug "Android" build/ai-station-debug.apk
```

`project.godot` sets `textures/vram_compression/import_etc2_astc=true`. Without that line Godot 4.3 refuses the Android export and the command-line error is blank. `jay-lock/.gdignore` stays so those copies do not take the live class names.

## Toolchain

| Piece | Version |
| --- | --- |
| Godot | 4.3.stable.official.77dcf97d8 |
| Export templates | 4.3.stable (`android_debug.apk` from `Godot_v4.3-stable_export_templates.tpz`) |
| JDK | OpenJDK 17.0.20.1 at `/usr/lib/jvm/java-17-openjdk-amd64` |
| Android cmdline-tools | 12.0 (`commandlinetools-linux-11076708_latest.zip`) |
| Android SDK Platform | android-34, revision 3 (API 34) |
| Build-Tools | 34.0.0 (apksigner 0.9) |
| Platform-Tools | 37.0.1 |

Non-Gradle debug template. Min SDK 21. Target SDK 34. No phone install was run on this machine.
