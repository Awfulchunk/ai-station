# AI Station Fixed-Cam Test — Build Status

Date: 2026-10-25 (America/Los_Angeles)
Godot: 4.3.stable.official.77dcf97d8
Binary: `/workspace/game/tools/godot/godot`

## Authority
- Design + Plan under `requests/ai-station/docs/superpowers/`
- Extreme Spec + Jay mock (md5 f6d52327bb9ff78fbf0a80b89d790d89)

## Run
```
/workspace/game/tools/godot/godot --path /workspace/game/ai-station-test
# proofs:
xvfb-run -a /workspace/game/tools/godot/godot --path /workspace/game/ai-station-test --resolution 1600x720 -- --proof
# self-test:
/workspace/game/tools/godot/godot --headless --path /workspace/game/ai-station-test --script res://scripts/sim/self_test.gd
```

## Controls
Space pause · 1/2/4 speed · click hotspot → inspect

## Proofs
`/workspace/game/requests/ai-station/proof-fixedcam/01-plate.png` … `04-sim-running.png`

## Cutaway look pass (2026-10-25)
- Blueprint: `/workspace/game/requests/ai-station/jay-lock/OIL-RIG-CUTAWAY-BLUEPRINT.pdf`
- Art builder: `jay-lock/tools/build_cutaway.py` → `assets/station/cutaway/{01_shell,02_walls,03_machines,04_pipes}.png`
- Plate composite also at `assets/station/station_plate.png`
- Godot StationRoot layers: Plate=shell, RoomLayers=walls+machines+pipes
- Hotspots remapped to R01–R10; stubs: biology, waste, receiving, walkways
- Proofs: `proof-fixedcam/05..08-cutaway-*.png` + `md5s-cutaway.txt` + `CUTAWAY-GAPS.md`
- Rebuild art: `python3 /workspace/game/requests/ai-station/jay-lock/tools/build_cutaway.py`
- Capture proofs: `xvfb-run -a godot --path /workspace/game/ai-station-test -- --proof`

## PASS2 equipment (2026-10-25)

Godot 4.3.stable. Front wall still hide-only. Flat `_bay_prop` blocks removed.

- Builder: `scripts/cutaway/equipment_builder.gd`, called from `InteriorBuilder` after the shell.
- Proof: `proof-fixedcam/10-pass2-equipment.png`
- md5: `3f5418b8e3c6a6d64683325dcc5f0865` (924046 bytes, front_wall_hidden=true, sim sanity true)
- Capture: `xvfb-run -a godot --path . --resolution 1600x720 -- --proof`

UpperWash used to add `CUT.position` on top of absolute `_mid_y()`, so a flat wash covered the hull, pontoons, and near water. That slab is gone. Lower-deck truss is drawn only in the dark gaps between pontoons.

PASS2 does not add gameplay. PowerNet, modules, and hidden hotspots are unchanged. No PASS3–5, no APK, no HTML.

## Coherent hull (2026-10-25)

Jay rejected `10-pass2-equipment.png`: a rectangular equipment panel in a hole in `exterior_with_hole.png`.

- `scenes/oil_rig.tscn` no longer instances that sprite or `front_wall_panel.png`.
- `scripts/cutaway/hull_builder.gd` builds the rig around `CUT = Rect2(120, 268, 1360, 262)`.
- Lower-works bays in `equipment_builder.gd` match the five pontoon gaps. Room kits are still there.
- Proof: `proof-fixedcam/11-coherent-hull.png` (Godot 4.3.stable, FrontWall hidden, silhouette sprite absent).
- The cut opening is still the straight room block. Dome, tanks, towers, and end posts cross it. This is not the painted mock.

## Sub-bay and room density (2026-10-26)

- Script: `scripts/cutaway/oil_rig_underdeck_systems.gd` (`OilRigUnderdeckSystems`) on `OilRig/UnderdeckSystems`.
- Public calls used by the proof: `open_hatch`, `launch_sub`, `get_system_status`. `close_hatch`, `recover_sub`, `damage_hatch`, `repair_hatch` stay on the same node.
- `PontoonLayer.visible = false`. `IntegratedRigLayer.draw_separated_pontoons = false`. One underside owner.
- Fit: art width 1500, deck bottom 525, scale 1, two pontoons 240×112, spacing 618, hatch 900×58.
- Room kits gained service pipes, windows, furniture, and StationSim bus taps. No painted kW digits.
- `15-density-rooms.png` is a zoomed cutaway plate, not a copy of the sealed-hatch frame.
- Proofs: `14-subbay-closed.png`, `14-subbay-open-deploy.png`, `15-density-rooms.png`, each with a `.md5` note.
- StationSim is the only scrap / electronics / fuel_oil / power authority. Underdeck calls `try_spend`. No trench camera. No APK.

## Engine room (2026-10-26)

- `PowerRoom` kit replaced with intake, turbine, combustors, exhaust stub, day tank, alternator, and two gauge faces.
- `scripts/cutaway/engine_room_status.gd` reads `StationSim` generator mode, `power_generated`, `power_requested`, fuel, and condition.
- Visual status is `RUNNING`, `STRAINED`, or `OFFLINE`. Heat, the bus, the lamp, and both needles follow those values. No painted kW digits.
- Proof: `proof-fixedcam/16-engine-room.png`.
