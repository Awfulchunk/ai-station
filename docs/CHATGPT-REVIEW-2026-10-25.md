# ChatGPT Review — AI Station Design, Mechanics, and Integration Findings

**Purpose:** This is ChatGPT's source-level review and implementation guidance for Grok/CODI. Treat it as a second reviewer, not as authority over the project owner. Re-check every finding against the latest branch before acting; files may have changed since this review.

**Review scope:** GitHub source inspection of `scripts/sim/station_sim.gd`, `scripts/cutaway/oil_rig_underdeck_systems.gd`, `scripts/cutaway/engine_room_status.gd`, `scripts/main.gd`, the all-in-one visual layer, and available project/spec review notes. This was not a Godot runtime test. Do not describe the build as tested or verified based on this document alone.

## My overall opinion

AI Station has a meaningful foundation, but it is not yet one coherent, end-to-end game. The primary risk is **split authority**: the station simulation and underdeck module maintain separate resource/power values, while the submarine currently behaves largely as a timed state machine rather than a mission that interacts with the world and inventory. Fix integration before expanding the feature list.

Keep the approved identity: a fictional autonomous machine station; two-floor side-view cutaway; dense readable industrial machinery; cyan/blue AI core; two separate orange outer pontoons; and a central blue/black/yellow-striped submarine launch/recovery opening with a clear vertical path to water. The central hatch is a submarine bay—not a ballast tank. Preserve open water between the two pontoons. The player manages a machine intelligence, resources, repairs, and expansion; no human-crew management loop is needed.

## Findings to verify and fix

### P0 — One authoritative station state

The current underdeck script defines its own `scrap`, `electronics`, `fuel`, and `electricity` values and spends them for hatch/launch/repair/upgrades. `StationSim` separately owns an `Inventory` and `PowerNet`. Unless a newer integration has already replaced this design, these are two independent economies.

**Required outcome**
- `StationSim` (or a dedicated shared state service it owns) is authoritative for inventory, power, module condition, and upgrade levels.
- Underdeck visuals and controls read from that state; they must not silently create a second stockpile.
- Every successful action atomically validates and spends the same resources the HUD displays.
- Failed actions cost nothing and return a clear reason.
- No free resource grants except documented starting stock, configured renewable sources, or explicit rewards.

**Implementation direction (adapt names to actual project APIs; do not paste blindly):**
```gdscript
# Preferred shape: UI/system asks the authoritative simulation to perform an action.
# Implement these methods on StationSim or a dedicated service owned by it.
func try_spend(costs: Dictionary) -> bool:
    # First validate EVERY requested resource and capacity/constraint.
    for resource_id in costs:
        if inventory.get_amount(str(resource_id)) < float(costs[resource_id]):
            return false
    # Only after all validation succeeds, spend all costs.
    for resource_id in costs:
        inventory.transfer_out(str(resource_id), float(costs[resource_id]))
    state_changed.emit()
    return true
```

This is a design sketch, not a verified drop-in patch. Confirm the actual `Inventory` API, rounding rules, and transactional guarantees before adopting it.

### P0 — Make submarine missions real

The underdeck state transitions cover hatch opening/closing and states such as `PREPARING`, `DEPLOYING`, `AWAY`, `RETURNING`, and `RECOVERING`. Those transitions alone do not make the submarine autonomous exploration.

A complete first mission should:
1. Require a docked sub, open/healthy hatch, sufficient power/fuel/battery, and a valid mission target.
2. Move through an actual underwater world/depth or mission model, with travel time and energy use.
3. Scan target nodes; target data should be real game state, not decorative marks.
4. Gather only available resources, respecting tool capability and cargo capacity; deplete finite deposits.
5. Apply depth/pressure, hull rating, battery, tool wear, and hazard consequences.
6. Support abort/return, damage or mission failure, and recovery constraints.
7. Transfer returned cargo into the one authoritative station inventory only after successful docking.
8. Publish clear mission status, progress, target, cargo, depth, battery, and failure/block reason.

Test at least success, empty deposit, full cargo, insufficient battery, damaged sub, closed/jammed hatch, no power, and failed recovery.

### P0 — Reconcile power/electricity

`StationSim` already calculates generation, requested power, grants, and module state. The underdeck script separately drains its own electricity variable. That can make station displays and actions disagree.

Choose one consistent model: station kW/kWh with explicit battery capacity and charge/discharge, or a clearly defined shared power reserve. Do not keep two independent numbers both labelled as station power. The hatch, winch, sub charging, and machine systems must request/use power through the same model, with reservations or atomic checks preventing overspending.

### P1 — Repair/upgrade and consequence rules

The underdeck has hatch and pontoon damage, repair costs, upgrade catalogs, and buoyancy/range multipliers. Verify these values actually influence the simulation/world. A buoyancy rating that only appears in a dictionary is not a gameplay consequence. Repair and upgrade costs must use shared inventory, and upgrades must change the relevant behavior—not just the displayed level.

Implement consequences in a staged way:
- Pontoon damage affects stability/operational limits and raises a clear warning.
- Hatch damage affects operation speed/reliability; severe damage can jam it.
- Repairs consume configured resources and time.
- Sub upgrades affect battery, range, scan/tool/cargo capability as specified.
- Critical faults have warnings and recoverable response paths where intended.

### P1 — Processing and economy

`StationSim` has a limited biomass-to-bio-nutrient recipe loop with checks for input, power, and output capacity. Expand only after it is robust. Keep recipes data-driven. Processing must never create output without consuming inputs, exceed capacity, or silently delete overflow. Power loss should pause work without resetting valid progress. Define and test a real chain from returned resources → sorting/refining/processing → usable fuel/materials/components → repairs/upgrades/expansion.

### P1 — Save/load and deterministic state

Do not call persistence complete until a save/load test restores:
- inventory and capacities;
- module modes, condition, faults, and blocked reasons;
- active recipe and progress;
- installed upgrades;
- submarine mission state, position/depth, battery, cargo, damage, and target;
- world resource depletion and other state needed to avoid duplication.

Load malformed/old saves safely. Test saving during an active recipe and during a submarine mission. Confirm pause and speed multiplier affect all simulation timers consistently. Do not save transient visuals as the source of truth.

## Visual review / art direction

- Preserve the two-floor cutaway and recognizable station silhouette.
- Improve room density with purposeful silhouettes: pipe runs connected to ports, valves, pumps, filters, cable trays, gauges, service panels, brackets, fasteners, status lamps, and visible structural supports.
- Avoid random decorative clutter; every pipe should connect somewhere plausible, and interactive equipment must be distinguishable from decoration.
- Make the ladder/transition bay feel built into the hull; avoid large empty patches.
- Ensure the front cutaway edge, hull framing, room floors, pontoons, and launch opening align at the actual game camera scale.
- Keep the central launch/recovery path clear. Do not fill it with a ballast tank or a continuous orange slab.
- Review real captures at phone scale. A screenshot that is identical to a prior proof does not prove a visual improvement.

The source-level review previously noted a duplicate pair of proof images (the density proof matched the closed sub-bay proof byte-for-byte) and sparse room density around the ladder bay. Re-check the latest artifact hashes/screenshots before treating this as a current issue.

## Workflow for Grok/CODI following Cursor

1. Inspect the newest commit/diff and the live files; don't rely on old review notes if the code changed.
2. Trace each feature from input/UI → authoritative simulation → resource/cost validation → world consequence → UI update → save/load.
3. Label findings as **confirmed**, **likely**, or **needs runtime test**. Cite file and line/function names.
4. Prefer small, reviewable fixes over rewriting large scripts or introducing a second parallel system.
5. Avoid editing the same files while Cursor is actively editing them. Use one shared worktree and coordinate ownership.
6. After a fix, run the project in the target Godot version and relevant automated/manual tests. Report exact results and logs; don't infer success from code appearance.
7. Re-capture design proofs at the same camera/scale and verify the files actually differ.
8. If a fix is risky or the current architecture is unclear, propose a patch/diff and ask the project owner before destructive refactors.

## Acceptance checklist — don't mark complete until demonstrated

- [ ] One authoritative inventory and power state across HUD, machines, hatch, submarine, repairs, and upgrades.
- [ ] Every spend/action is validated atomically; failed actions spend nothing.
- [ ] Submarine can complete a real target-based mission and return actual cargo.
- [ ] Cargo capacity, battery/fuel, depth/hazards, damage, and recovery can affect outcomes.
- [ ] Resource processing respects inputs, outputs, power, and capacity.
- [ ] Repairs/upgrades change real gameplay state and use shared resources.
- [ ] Save/load restores active jobs and missions without duplication or reset.
- [ ] Pause/speed settings consistently control all simulation time.
- [ ] No parser/runtime errors in the target Godot version; test output attached.
- [ ] Fresh screenshots show the intended dense cutaway and two separate pontoons/clear hatch opening.

**Final principle:** The project owner decides. Cursor implements the main project. Grok/CODI follows behind as reviewer and design guardian. ChatGPT's role is to provide a second opinion, concrete test cases, and targeted code suggestions—not to claim changes were integrated or tested when they were not.
