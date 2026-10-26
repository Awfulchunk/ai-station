# CODI grade — SubBay + density + engine (Cursor run #6)
Date: 2026-10-25 (America/Los_Angeles)
Pack: ai-station-subbay-density.tar.gz md5 d09da4ac67bb76643062e4ee250c711c (11988935 B) — VERIFIED on disk

## Proofs (md5 verified)
| file | md5 | notes |
| 14-subbay-closed.png | 5567e361ee5c8a7a5871f89f42de776a | sealed hatch plate |
| 14-subbay-open-deploy.png | 7507968467d2b265519f90f6fa7d366e | hatch open / sub deploying |
| 15-density-rooms.png | 5567e361ee5c8a7a5871f89f42de776a | **IDENTICAL to 14-closed** — not a real density proof |
| 16-engine-room.png | 7ceafeb850c0ad28a82b9382547177ce | engine + RUNNING frame |

Pixel check (14-open): L/R pontoons orange (233,77,0); gaps water (43,142,196) — not continuous orange bar. PASS silhouette vs proof-13 lock (2 end pods).

## Architecture check
- UnderdeckSystems present; PontoonLayer visible=false (single underside owner). PASS
- EngineRoomStatus binds StationSim generator / power_generated / power_requested / fuel. PASS wiring claim
- Underdeck scrap/fuel/electricity ledger still local to UnderdeckSystems — not StationSim. OPEN (Cursor admitted)

## Categories
BLOCKERS: none found on disk (Godot headless not run this pass — parser not available on box).
REGRESSIONS: none vs proof-13 pontoon/hatch silhouette.
DESIGN DRIFT:
- Proof 15 is a soft deliverable (byte-identical to 14). Density pass exists in equipment_builder but was not separately captured.
- Some rooms still thin (ladder bay especially). Density improved vs early PASS2 but not Metal Slug / FS target yet.
OPTIONAL POLISH: unify underdeck resource ledger into StationSim; re-capture a true 15 zoomed/annotated density plate.

## Verdict
PARTIAL PASS — SubBay integrate + engine/sim glow land. Pontoon/hatch lock held. Density incomplete (fake proof 15 + still-thin rooms). No soft stamp. APK held. Awaiting Jay visual stamp on 14/16.
