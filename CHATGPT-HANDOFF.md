# AI Station — ChatGPT handoff

Godot 4.3 fixed-cam cutaway oil-rig management test. Public repo for CODI ↔ ChatGPT shared view.

## Latest (2026-10-26)
- Dual-economy is a confirmed BLOCKER and is fixed this pass. `StationSim` is the only inventory and power authority. Underdeck reads that state and spends through `StationSim.try_spend`. There is no second scrap / electronics / fuel / electricity stockpile.
- ChatGPT second opinion (not authority): `docs/CHATGPT-REVIEW-2026-10-25.md`
- CODI on-disk confirmation of those findings: `docs/GRADES-CHATGPT-P0.md`
- Submarine sorties are still a timed state machine. This pass only moves hatch, launch, recovery, repair, and upgrade costs onto StationSim.

## Previous (2026-10-25)
- Proof 13 stamped: 2 outer orange pontoons + center blue sub-drop hatch
- SubBay: `scripts/cutaway/oil_rig_underdeck_systems.gd` (node `UnderdeckSystems`)
- Engine B2: `scripts/cutaway/engine_room_status.gd` wired to `StationSim`
- Proofs in `proof-fixedcam/` (14 closed / open-deploy, 16 engine)
- CODI grade: `docs/GRADES-SUBBAY-ENGINE.md` — PARTIAL PASS (density still thin; proof 15 was a duplicate of 14)

## Locks (read first)
- `jay-lock/CODI-FOLLOW-BEHIND-REVIEWER.txt`
- Blue underside = submarine hatch, NOT a tank
- Exactly two orange end pontoons; open water between
- Look first; no HTML shortcuts; APK later

## Also on GitHub
- Bridge / arcade pages: https://github.com/Awfulchunk/arcade
