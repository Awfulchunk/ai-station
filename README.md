# Deep Station — pixel sub-station

Godot 4.3. The main scene is a small pixel sub-station. Six HUD tabs run the rooms. The picture is not clickable and does not zoom.

| Tab | What it drives |
| --- | --- |
| Energy | `PowerNet`, generator, `fuel_oil`, exterior lights, divert kW onto processor/refinery jobs |
| Control | `SubVessel` depart, mine, return |
| Storage | `Inventory` bins and `unload_sub` |
| Mechanics | module wear, `try_repair_module`, room level, dive-gear levels |
| Life Support | air, heat, station hull from the `life_support` module's granted kW |
| Sub bay | ping (`try_spend` kW) plus depth, station, and equipment pressure |

```bash
godot --path . --resolution 1600x720
godot --path . --resolution 1600x720 -- --legacy-cutaway
```

Space pauses. Keys 1 / 2 / 4 set sim speed. F1–F6 switch rooms.

```bash
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --display-driver x11 --audio-driver Dummy --resolution 1600x720 -- --proof
```

That writes `proof-deepsea/room-energy.png` through `room-sub_bay.png`. Each shot keeps all six tabs on screen.

## Legacy cutaway

The 10-bay oil-rig scene is `scenes/legacy_main.tscn`. It is not the playable target. `--legacy-cutaway` still boots it. The notes below describe that older hull.

PASS1 is the cutaway shell: two decks, bulkheads, hatch openings, and a front wall that hides only itself. PASS2 fills every bay with `Polygon2D` equipment and routes pipes on the infrastructure layer. The coherent-hull pass removes the flattened rig photo. Sky, ocean, deck, end bulkheads, cranes, red-banded towers, dish, tanks, AI dome, pontoons, and the keel truss are scene geometry. `exterior_with_hole.png` is not drawn.

`CutawayController` still hides only `FrontWall`. There is no grid, no room-label overlay, and no crew. EquipmentBuilder is unchanged as a system; its lower-works bays were moved so the truss sits in the gaps between the new pontoons.

## Legacy run

Requires Godot 4.3. Pass `--legacy-cutaway` or these commands load the old rig, not the six-room shell.

```bash
godot --path . --resolution 1600x720 -- --legacy-cutaway
```

Space pauses. Keys 1 / 2 / 4 set sim speed. C toggles the front wall. Clicking a bay still hits the existing hidden hotspot.

## Legacy proof

```bash
xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --display-driver x11 --audio-driver Dummy --resolution 1600x720 -- --legacy-cutaway --proof
```

That writes the current plate:

- `proof-fixedcam/14-subbay-closed.png` — hatch sealed, two end pontoons
- `proof-fixedcam/14-subbay-open-deploy.png` — hatch open, sub leaving the bay
- `proof-fixedcam/15-density-rooms.png` — zoomed cutaway rooms, front wall hidden, distinct from 14
- `proof-fixedcam/16-engine-room.png` — B2 power plant after the generator has produced real kW
- a `.md5` note beside each

Godot 4.3.stable. FrontWall stays hidden. The underside owner is `UnderdeckSystems`. `PontoonLayer` is in the scene and hidden so the hatch is not drawn twice. The stamped silhouette is `proof-fixedcam/13-sub-drop-hatch.png` (md5 `8ef297a803fbaad240f30d21f4639e17`): two outer orange pontoons and a blue center launch hatch.

`10-pass2-equipment.png` is the rejected look: the same rooms composited into a rectangular hole in a flattened rig photo. `11-coherent-hull.png` is not that composite. The opening is still the straight room block the bays were built on, with the dome trunk, tank skirts, tower bases, and end posts crossing its edge. It is not a hand-painted replacement of the original mock.

## Where the geometry lives

| Node | What it is |
| --- | --- |
| `scripts/cutaway/hull_builder.gd` | Sky, ocean, deck, end bulkheads, pontoons, cranes, towers, dish, tanks, dome, front-wall skin |
| `Interior` + `scripts/cutaway/interior_builder.gd` | PASS1 shell: cavity, cut rim, decks, bulkheads, room shells |
| `Rooms/*/Equipment` | PASS2 machines, tanks, grating, panels, lamps |
| `Bulkheads/HatchLeaf_*` | Stowed hatch leaves on the door openings |
| `Infrastructure/*` | Power, water, fuel, and data runs, plus the belt link through the B3–C3 hatch |
| `UnderdeckSystems` | Two end pontoons, sub-drop hatch, launch and recovery animation |
| `PontoonLayer` | Previous underside drawing. Hidden. Exports kept. |
| `Interior/LowerWorks` | Keel chords on the outer shoulders only. The center drop stays clear. |
| `Interior/Machinery/BilgePump` | Ballast pump on the port shoulder, off the drop path |
| `StationSim` and hotspots | StationSim owns inventory and the power bus. Underdeck actions spend through `try_spend`. Hotspots still inspect modules. |

Equipment, pipes, lamps, the mini-sub, and the fish marks inside the biology tanks are visual only.
