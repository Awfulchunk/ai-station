extends RefCounted
class_name ShellOps
## HUD-facing operations on the live StationSim.
## Meters read PowerNet, Inventory, SubVessel, and LifeSupport. They do not store a second bus.

const LIGHTS_KW := 3.0
const LIFE_KW := 1.0
const PING_KW := 1.5
const DIVERT_MAX_KW := 8.0
const STATION_DEPTH_M := 42.0
const SEAL_SCRAP := 12.0
const SEAL_HULL := 14.0
const ROOM_LEVEL_MAX := 4

const ROOM_SPECS: Array = [
	{"id": "energy", "room": "Energy", "primary": "generator", "feed": "exterior_lights", "modules": ["generator", "exterior_lights"]},
	{"id": "control", "room": "Control", "primary": "ai_core", "feed": "ai_core", "modules": ["ai_core", "comms"]},
	{"id": "storage", "room": "Storage", "primary": "storage", "feed": "storage", "modules": ["storage"]},
	{"id": "mechanics", "room": "Mechanics", "primary": "processor", "feed": "processor", "modules": ["processor", "refinery"]},
	{"id": "life", "room": "Life Support", "primary": "life_support", "feed": "life_support", "modules": ["life_support"]},
	{"id": "sub_bay", "room": "Sub bay", "primary": "dock", "feed": "dock", "modules": ["dock"]},
]

const GEAR: Dictionary = {
	"battery": {"scrap": 18.0, "electronics": 10.0, "max": 3},
	"scanner": {"scrap": 14.0, "electronics": 16.0, "max": 3},
	"cargo": {"scrap": 22.0, "metal_stock": 2.0, "max": 2},
}

var life: LifeSupport
var lights_on: bool = false
var divert_target: String = ""
var divert_kw: float = 0.0
var divert_applied_kw: float = 0.0
var gear_levels: Dictionary = {"battery": 0, "scanner": 0, "cargo": 0}
var last_ping: Dictionary = {}


func bind(sim: StationSim) -> void:
	life = LifeSupport.new()
	life.station_depth_m = STATION_DEPTH_M
	_apply_light_mode(sim)


func begin_tick() -> void:
	divert_applied_kw = 0.0


func after_allocate(sim: StationSim) -> void:
	life.tick(sim.modules["life_support"])


## Extra surplus kW speeds a craft job that is already fully powered.
## Level 1 is the baseline rate the rest of the sim was tuned for.
func job_speed(sim: StationSim, module_id: String, need_pwr: float) -> float:
	var worker: StationModule = sim.modules[module_id]
	var level: int = worker.level
	var speed := 1.0 + 0.15 * float(maxi(level, 1) - 1)
	if divert_target != module_id or divert_kw <= 0.0:
		return speed
	var take := minf(divert_kw, sim.power.available_kw())
	if take <= 0.0 or not sim.power.reserve(take):
		return speed
	divert_applied_kw = take
	return speed * (1.0 + take / maxf(need_pwr, 0.1))


func set_lights(sim: StationSim, on: bool) -> void:
	lights_on = on
	_apply_light_mode(sim)
	sim.last_action_reason = ""
	sim.state_changed.emit()


func set_life_mode(sim: StationSim, mode: int) -> bool:
	match mode:
		StationModule.Mode.OFF, StationModule.Mode.STANDBY, StationModule.Mode.RUNNING:
			pass
		StationModule.Mode.PAUSED, StationModule.Mode.FAULTED, StationModule.Mode.DESTROYED:
			sim.last_action_reason = "Life support mode is not available."
			sim.state_changed.emit()
			return false
		_:
			var _missing := mode
			push_error("ShellOps unhandled life mode")
			sim.last_action_reason = "Life support mode is not available."
			sim.state_changed.emit()
			return false
	var plant: StationModule = sim.modules["life_support"]
	if plant.mode == StationModule.Mode.FAULTED or plant.mode == StationModule.Mode.DESTROYED:
		sim.last_action_reason = "Life support is faulted."
		sim.state_changed.emit()
		return false
	plant.set_mode(mode, "")
	sim.last_action_reason = ""
	sim.state_changed.emit()
	return true


func set_divert(sim: StationSim, target: String, kw: float) -> bool:
	if target != "" and target != "processor" and target != "refinery":
		sim.last_action_reason = "Divert only speeds the processor or the refinery."
		sim.state_changed.emit()
		return false
	divert_target = target
	divert_kw = 0.0 if target == "" else clampf(kw, 0.0, DIVERT_MAX_KW)
	sim.last_action_reason = ""
	sim.state_changed.emit()
	return true


## Tier 0 is fed first. The chosen room's primary module takes tier 0.
## Any other tier-0 load (except the generator) steps back so the choice matters.
func prioritize_room(sim: StationSim, module_id: String) -> bool:
	if not _is_primary(module_id) and module_id != "exterior_lights":
		sim.last_action_reason = "That load is not on a room bus."
		sim.state_changed.emit()
		return false
	for id in sim.modules.keys():
		var m: StationModule = sim.modules[id]
		if id == module_id:
			m.priority = 0
		elif id != "generator" and m.priority == 0:
			m.priority = 2
	sim.last_action_reason = ""
	sim.state_changed.emit()
	return true


func ping(sim: StationSim) -> bool:
	if not sim.try_spend({}, PING_KW):
		last_ping = {}
		return false
	last_ping = {
		"tick": sim.clock.tick,
		"phase": sim.sub.phase_name(),
		"depth_m": sim.sub.depth_m,
		"target_id": sim.sub.target_id,
		"track_m": track_m(sim.sub),
		"depth_pressure_bar": LifeSupport.pressure_bar(sim.sub.depth_m),
		"station_pressure_bar": life.interior_bar,
		"station_sea_bar": life.sea_pressure_bar(),
		"equipment_pressure_bar": equipment_pressure_bar(sim),
	}
	sim.state_changed.emit()
	return true


func upgrade_gear(sim: StationSim, kind: String) -> bool:
	if not GEAR.has(kind):
		sim.last_action_reason = "Unknown dive gear."
		sim.state_changed.emit()
		return false
	var spec: Dictionary = GEAR[kind]
	var level: int = int(gear_levels[kind])
	if level >= int(spec["max"]):
		sim.last_action_reason = "Gear is already maxed."
		sim.state_changed.emit()
		return false
	var costs: Dictionary = {}
	for key in spec.keys():
		if key == "max":
			continue
		costs[key] = float(spec[key])
	if not sim.try_spend(costs):
		sim.state_changed.emit()
		return false
	gear_levels[kind] = level + 1
	_apply_gear(sim)
	sim.state_changed.emit()
	return true


func upgrade_room(sim: StationSim, module_id: String) -> bool:
	if not _is_primary(module_id):
		sim.last_action_reason = "That module is not a room upgrade."
		sim.state_changed.emit()
		return false
	var m: StationModule = sim.modules[module_id]
	if m.level >= ROOM_LEVEL_MAX:
		sim.last_action_reason = "Room upgrade is maxed."
		sim.state_changed.emit()
		return false
	var costs: Dictionary = {"scrap": 16.0 * float(m.level), "electronics": 6.0 * float(m.level)}
	if not sim.try_spend(costs):
		sim.state_changed.emit()
		return false
	m.level += 1
	m.wear_per_tick = 0.01 / float(m.level)
	sim.state_changed.emit()
	return true


func seal_hull(sim: StationSim) -> bool:
	if life.hull >= 99.5:
		sim.last_action_reason = "Hull is intact."
		sim.state_changed.emit()
		return false
	if not sim.try_spend({"scrap": SEAL_SCRAP}):
		sim.state_changed.emit()
		return false
	life.hull = minf(100.0, life.hull + SEAL_HULL)
	sim.state_changed.emit()
	return true


func bus_rows(sim: StationSim) -> Array:
	var rows: Array = []
	for spec in ROOM_SPECS:
		var demand := 0.0
		var granted := 0.0
		var names: PackedStringArray = PackedStringArray()
		var mods: Array = spec["modules"]
		for id in mods:
			var module_id := str(id)
			names.append(module_id)
			demand += sim.module_request_kw(module_id)
			granted += sim.modules[module_id].power_granted
		var feed_id := str(spec["feed"])
		rows.append({
			"room": str(spec["room"]),
			"room_id": str(spec["id"]),
			"modules": " ".join(names),
			"primary": str(spec["primary"]),
			"feed": feed_id,
			"demand": demand,
			"granted": granted,
			"priority": sim.modules[feed_id].priority,
		})
	return rows


func other_load(sim: StationSim) -> Dictionary:
	var known := {}
	for spec in ROOM_SPECS:
		for id in spec["modules"]:
			known[str(id)] = true
	var demand := 0.0
	var granted := 0.0
	for id in sim.modules.keys():
		if known.has(str(id)):
			continue
		demand += sim.module_request_kw(str(id))
		granted += sim.modules[id].power_granted
	return {"demand": demand, "granted": granted}


func equipment_pressure_bar(sim: StationSim) -> float:
	# Gear on the boat sees the sub's depth. Gear in the lock sees the station's sea pressure.
	if sim.sub.phase == SubVessel.Phase.DOCKED:
		return life.sea_pressure_bar()
	return LifeSupport.pressure_bar(sim.sub.depth_m)


static func track_m(sub: SubVessel) -> float:
	# The vessel model moves on depth only, so bay-relative track is that depth.
	match sub.phase:
		SubVessel.Phase.DOCKED:
			return 0.0
		SubVessel.Phase.SURFACE:
			return 0.0
		SubVessel.Phase.TRAVEL, SubVessel.Phase.MINE, SubVessel.Phase.RETURN, SubVessel.Phase.DISABLED:
			return sub.depth_m
		_:
			var _missing := sub.phase
			push_error("ShellOps unhandled sub phase")
			return sub.depth_m


func snapshot(sim: StationSim) -> Dictionary:
	var ping_tick := int(last_ping.get("tick", -1))
	return {
		"lights_on": lights_on,
		"divert_target": divert_target,
		"divert_kw": divert_kw,
		"divert_applied_kw": divert_applied_kw,
		"air": life.air,
		"heat_c": life.heat_c,
		"station_hull": life.hull,
		"cabin_bar": life.interior_bar,
		"station_sea_bar": life.sea_pressure_bar(),
		"life_powered": life.powered,
		"gear_battery": int(gear_levels["battery"]),
		"gear_scanner": int(gear_levels["scanner"]),
		"gear_cargo": int(gear_levels["cargo"]),
		"depth_pressure_bar": LifeSupport.pressure_bar(sim.sub.depth_m),
		"equipment_pressure_bar": equipment_pressure_bar(sim),
		"track_m": track_m(sim.sub),
		"sub_target": sim.sub.target_id,
		"sub_safe_depth_m": sim.sub.safe_depth_m,
		"ping_tick": ping_tick,
		"life_mode": sim.modules["life_support"].mode_name(),
		"life_granted": sim.modules["life_support"].power_granted,
		"lights_granted": sim.modules["exterior_lights"].power_granted,
	}


func export_state() -> Dictionary:
	return {
		"lights_on": lights_on,
		"divert_target": divert_target,
		"divert_kw": divert_kw,
		"gear": gear_levels.duplicate(),
		"life": life.export_state(),
		"ping": last_ping.duplicate(true),
	}


func import_state(sim: StationSim, data: Dictionary) -> void:
	lights_on = bool(data.get("lights_on", lights_on))
	var target := str(data.get("divert_target", ""))
	if target != "" and target != "processor" and target != "refinery":
		target = ""
	divert_target = target
	divert_kw = 0.0 if target == "" else clampf(float(data.get("divert_kw", 0.0)), 0.0, DIVERT_MAX_KW)
	var gear = data.get("gear", {})
	if typeof(gear) == TYPE_DICTIONARY:
		for kind in ["battery", "scanner", "cargo"]:
			if gear.has(kind):
				gear_levels[kind] = maxi(int(gear[kind]), 0)
	var life_data = data.get("life", {})
	if typeof(life_data) == TYPE_DICTIONARY and not life_data.is_empty():
		life.import_state(life_data)
	var ping = data.get("ping", {})
	if typeof(ping) == TYPE_DICTIONARY:
		last_ping = ping.duplicate(true)
	_apply_light_mode(sim)


func _apply_gear(sim: StationSim) -> void:
	sim.sub.apply_battery_level(int(gear_levels["battery"]))
	sim.sub.apply_scanner_level(int(gear_levels["scanner"]))
	sim.sub.cargo_capacity = SubVessel.CARGO_CAPACITY + 4.0 * float(gear_levels["cargo"])


func _apply_light_mode(sim: StationSim) -> void:
	var lights: StationModule = sim.modules["exterior_lights"]
	if lights.mode == StationModule.Mode.FAULTED or lights.mode == StationModule.Mode.DESTROYED:
		return
	if lights_on:
		lights.set_mode(StationModule.Mode.RUNNING, "")
	else:
		lights.set_mode(StationModule.Mode.OFF, "")


func _is_primary(module_id: String) -> bool:
	for spec in ROOM_SPECS:
		if str(spec["primary"]) == module_id:
			return true
	return false
