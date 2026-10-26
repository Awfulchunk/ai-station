# AI Station — Mechanics grade M0/M1 (Ms. Bitch)
Date: 2026-10-25 America/Los_Angeles
Package: webview.zip md5 `05de2c6e6d30c9d58a9dfc106f92e153` (25650 bytes) — VERIFIED on box
Bundle: `index-Rs0CtijD.js`

## Lane
- Look / package honesty: CODI
- Mechanics: Ms. Bitch

## M0 Visual blockout — LOOK (not graded here)
CODI owns. Proofs: `proof-extreme/22-extreme-surface.png`, `23-extreme-deep.png`, `24-extreme-module.png`.

## M1 State foundation — MECHANICS GRADE: **PARTIAL / NO STAMP**

### Pass
- Fixed 1s sim tick via `tickAccum` + `simulationTimeSeconds` (fractional dt accumulates; only whole seconds advance)
- Pause blocks tick advance
- Speed cycle 1× → 2× → 4× → 1× multiplies accum
- `transfer` / bin fill: cannot overdraw source; returns `Storage full` / `Source empty`; recipe overflow waits (no silent delete)
- Stock clamped ≥0 on load normalize (`nt`)
- Live stock shown in module inspect (agent claim + bundle has storage panel wiring)

### Fail / soft (must adjust before M1 stamp)
1. **Save/load incomplete for M1 Done-When ("State persists")** — `nt` only default-fills missing clock fields; no migration version bump; no mid-job / mid-mission restore proof. Old `day`/`minuteOfDay`/`weather` still sit beside the new clock (dual-clock smell).
2. **Power still a single `stock.power` number** — not generated / requested / granted. Spec foundation wants real power flow before machines expand (blocks honest M2).
3. **No in-package sanity harness** — Cursor claims 10k-tick + fractional-step tests on their VM; nothing shippable here for us to re-run. Need a tiny replay test file or script in artifacts.
4. **Modules still thin `k(condition)` shells** — fine to defer machine FSM to M2, but do not claim M1 "complete" while advertising full module inspect as sim-authoritative beyond condition/stock.

### Adjust list for Cursor (mechanics only)
- [ ] Bump save `version`, migrate old saves, round-trip test: pause mid-tick + mid-sub job → reload → same simTime, stock, sub mode/work
- [ ] Split power into generated / requested / granted (even stub) so UI cannot lie
- [ ] Ship a `sanity-m1` script or logged test output in artifacts we can re-verify
- [ ] Drop or freeze old day/minute clock so one authoritative time remains

### Stamp
**No mechanics stamp on M1.** Clock + inventory transfer are real; persistence and power foundation are soft. Re-grade after adjust list.
