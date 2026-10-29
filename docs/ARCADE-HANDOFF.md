# Arcade handoff — AI Station 0.1.0-test

Standalone Godot 4.3 debug APK. The WebView arcade is HTML. This title is not an iframe game. List it the same way `download.html` lists `EmpireClash-*.apk`: a file next to the page, and a download link on the card.

## Card

In [Awfulchunk/arcade](https://github.com/Awfulchunk/arcade) `download.html`, add a block in the same shape as Empire Clash:

```html
<h3>AI Station</h3>
<p class="sub">Standalone Godot debug APK · fixed-cam oil rig · 0.1.0-test · com.awfulchunk.aistation</p>
<a href="AIStation-0.1.0-test.apk" download>Download AI Station APK (0.1.0-test)</a>
```

Put `AIStation-0.1.0-test.apk` in the arcade site root, beside `download.html` and `EmpireClash-1.0.5.apk`. The public link is:

https://awfulchunk.github.io/arcade/AIStation-0.1.0-test.apk

Own package, own install. Do not fold it into `ToughAndJsArcade-*.apk`. Do not add an HTML play link unless a later HTML5 export is actually built and checked. This drop did not produce one.

## This APK

Built from `main` after PR #4 (`ff63571`). `godot --headless --path . --script res://scripts/sim/self_test.gd` printed `SELF_TEST_OK` before export.

| | |
| --- | --- |
| File | `AIStation-0.1.0-test.apk` (same bytes as `build/ai-station-debug.apk`) |
| Bytes | 33953833 |
| md5 | `32328d4ebc4fe666b7f97cdbb1327c98` |
| Package | `com.awfulchunk.aistation` |
| Version | `0.1.0-test` (versionCode 1) |
| Label | AI Station |
| ABI | `arm64-v8a` only |
| Orientation | landscape (`android:screenOrientation` 0) |
| Renderer | Compatibility (`gl_compatibility` on desktop and mobile) |
| Permissions | none added |
| Signing | debug APK, `android:debuggable=true`, v1/v2/v3 verified |

The APK and the debug keystore are not in git. Copy the artifact onto the arcade repo by hand.

`proof-fixedcam/14-subbay-closed.png` is still md5 `839d8c2641a66464034d96a04ed0f0af`, 74162 bytes. `PontoonLayer` stays hidden. The APK packs `scripts/cutaway/oil_rig_underdeck_systems.gd` and `oil_rig_pontoon_layer.gd`, not the `jay-lock` copies.

## Export again

Godot 4.3.stable. Copy `export_presets.cfg.example` to `export_presets.cfg` (gitignored). Leave the keystore lines empty. Editor Settings hold the SDK path, the JDK path, and the debug keystore.

`project.godot` sets `textures/vram_compression/import_etc2_astc=true`. Without that line Godot 4.3 refuses the Android export and the command-line error is blank.

`jay-lock/.gdignore` stays. Those files repeat `class_name`. If Godot scans them, the live pontoon and hatch scripts fail to compile and the class cache points at the frozen copies.

```bash
godot --headless --path . --import --quit
godot --headless --path . --script res://scripts/sim/self_test.gd
mkdir -p build
godot --headless --path . --export-debug "Android" build/ai-station-debug.apk
```

The preset uses the official debug template (`gradle_build/use_gradle_build=false`). Landscape is `display/window/handheld/orientation` = 0, which this project already uses.

## Toolchain for 0.1.0-test

| Piece | Version |
| --- | --- |
| Godot | 4.3.stable.official.77dcf97d8 |
| Export templates | 4.3.stable (`android_debug.apk` from `Godot_v4.3-stable_export_templates.tpz`) |
| JDK | OpenJDK 17.0.20.1 at `/usr/lib/jvm/java-17-openjdk-amd64` |
| Android cmdline-tools | 12.0 (`commandlinetools-linux-11076708_latest.zip`) |
| Android SDK Platform | android-34, revision 3 (API 34) |
| Build-Tools | 34.0.0 (apksigner 0.9) |
| Platform-Tools | 37.0.1 |

The template’s min SDK is 21. Target SDK is 34. No phone install was run on this machine.
