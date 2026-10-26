# AI Station — zoomed-in room module reference

This is a **real Godot scene module**, not a generated image. It is deliberately isolated from the wider station so Grok can use it as a construction reference.

## Contents
- `scenes/power_core_room.tscn` — standalone room scene.
- `scripts/power_core_room.gd` — builds the room using Godot nodes and geometry.
- `docs/ROOM_SCHEMATIC.md` — top-level engineering schematic and integration notes.

## Run
Open this folder in Godot 4.3 and run the project. No ocean, water background, station backdrop, or HUD is included. The room is shown zoomed in.

Click the yellow service switch near the generator to toggle generator output and AI core state. Press `R` to reset. The script emits `state_changed(generator_running, power_kw, core_online)`.

## Integration
Instance `scenes/power_core_room.tscn` into the main station and scale/position it as a room kit. It intentionally uses no autoloads or external assets. It is a visual/interaction prototype, not connected to the main game's `StationSim` inventory yet.
