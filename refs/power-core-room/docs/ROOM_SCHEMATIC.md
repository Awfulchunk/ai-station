# R02 + R01 — Zoomed Room Schematic

**Module:** Power generation + distribution + AI core  
**View:** front cutaway, zoomed in  
**Excluded:** ocean, water effects, station background image, global HUD, crew  
**Orientation:** left = power source, center = distribution, right = AI load

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                         BACK BULKHEAD / CABLE TRAY                           │
│                                                                              │
│  G-01 GENERATOR       BUS A / SWITCHGEAR                 C-01 AI CORE         │
│  ┌─────────────┐      ┌─────────────────┐               ┌───────────────┐     │
│  │ engine block├─────►│ breaker cabinet ├──────────────►│ processor racks│    │
│  │ alternator  │ PWR  │ 3 breakers      │   18 kW bus  │ cyan core      │    │
│  └──────┬──────┘      └─────────────────┘               └───────────────┘     │
│         │                                                                    │
│  fuel service line      status beacon / local service switch                 │
├══════════════════════════════════════════════════════════════════════════════┤
│             STEEL FLOOR GRATING / SKID MOUNTS / CUTAWAY LIP                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Construction layers
1. **Hull shell:** back bulkhead, left/right bulkheads, floor deck, cutaway lip.
2. **Structural frame:** support posts, feet, overhead cable tray and ribs.
3. **Generator assembly:** skid, engine casing, cooling fins, alternator, exhaust and fuel service pipe.
4. **Distribution:** switchgear cabinet, breakers, status lamps, bus display and heavy power cable.
5. **AI core:** cabinet, processor racks, LEDs, core element, sealed dry equipment cooling loop.
6. **Local interaction:** service switch toggles generator output; AI core is online only while the generator is running.

## Functional boundary
- Generator ON: 18 kW generated, AI core ON (4 kW demand is illustrative).
- Generator OFF: 0 kW generated, AI core OFF.
- This isolated sample demonstrates a local module state; it does not yet consume fuel or allocate power through the main game's StationSim.
- Any later simulation integration should bind this room's switch to `StationSim.modules["generator"]` and read actual allocated power for `StationSim.modules["ai_core"]`.
