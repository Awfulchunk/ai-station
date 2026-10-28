extends RefCounted
class_name SubVessel
## Onboard submarine. Cargo stays here until StationSim unloads it at dock.
## Battery is kWh, not a second station electricity bin.

enum Phase { DOCKED, TRAVEL, MINE, RETURN, SURFACE, DISABLED }

const CRUISE_KW := 200.0
const MINE_KW := 350.0
const CHARGE_KW := 4.0
const SPEED_M_PER_S := 10.0
const RESERVE_KWH := 0.5
const BASE_CAPACITY_KWH := 4.0
const CARGO_CAPACITY := 16.0
const BASE_SAFE_DEPTH_M := 90.0

var phase: int = Phase.DOCKED
var depth_m: float = 0.0
var battery_kwh: float = BASE_CAPACITY_KWH
var battery_capacity_kwh: float = BASE_CAPACITY_KWH
var hull: float = 100.0
var cargo: Dictionary = {}
var cargo_capacity: float = CARGO_CAPACITY
var safe_depth_m: float = BASE_SAFE_DEPTH_M
var target_id: String = ""
var nodes: Dictionary = {}
var fail_reason: String = ""


func setup_nodes() -> void:
	nodes = {
		"shelf_ore": {
			"depth_m": 40.0,
			"resource": "mixed_ore",
			"remaining": 24.0,
			"hardness": 1.0,
			"rate": 2.0,
		},
		"shelf_biomass": {
			"depth_m": 20.0,
			"resource": "biomass",
			"remaining": 12.0,
			"hardness": 1.0,
			"rate": 1.5,
		},
	}


func cargo_total() -> float:
	var total := 0.0
	for key in cargo.keys():
		total += float(cargo[key])
	return total


func cargo_free() -> float:
	return maxf(0.0, cargo_capacity - cargo_total())


func phase_name() -> String:
	match phase:
		Phase.DOCKED:
			return "DOCKED"
		Phase.TRAVEL:
			return "TRAVEL"
		Phase.MINE:
			return "MINE"
		Phase.RETURN:
			return "RETURN"
		Phase.SURFACE:
			return "SURFACE"
		Phase.DISABLED:
			return "DISABLED"
		_:
			var _missing := phase
			push_error("SubVessel unhandled phase")
			return "DOCKED"


func status() -> Dictionary:
	return {
		"phase": phase_name(),
		"depth_m": depth_m,
		"battery_kwh": battery_kwh,
		"battery_capacity_kwh": battery_capacity_kwh,
		"hull": hull,
		"cargo": cargo.duplicate(),
		"cargo_total": cargo_total(),
		"target_id": target_id,
		"fail_reason": fail_reason,
		"safe_depth_m": safe_depth_m,
	}


func can_depart(node_id: String) -> bool:
	fail_reason = ""
	if hull <= 0.0:
		phase = Phase.DISABLED
		fail_reason = "Submarine hull is destroyed."
		return false
	if phase != Phase.DOCKED and phase != Phase.SURFACE:
		fail_reason = "Submarine is not docked."
		return false
	if not nodes.has(node_id):
		fail_reason = "Unknown deposit."
		return false
	var node: Dictionary = nodes[node_id]
	if float(node.get("remaining", 0.0)) <= 1e-9:
		fail_reason = "Deposit is empty."
		return false
	var target_depth := float(node.get("depth_m", 0.0))
	if target_depth > safe_depth_m + 1e-6:
		fail_reason = "Target is deeper than the hull rating."
		return false
	if battery_kwh + 1e-9 < _estimate_kwh(node):
		fail_reason = "Insufficient battery for mission."
		return false
	return true


func begin_travel(node_id: String) -> void:
	target_id = node_id
	phase = Phase.TRAVEL
	fail_reason = ""


func order_return() -> bool:
	if phase == Phase.DISABLED:
		fail_reason = "Submarine is disabled."
		return false
	if phase == Phase.DOCKED or phase == Phase.SURFACE or phase == Phase.RETURN:
		return true
	phase = Phase.RETURN
	fail_reason = "Return ordered."
	return true


func recover_to_bay() -> void:
	if phase == Phase.DISABLED or hull <= 0.0:
		phase = Phase.DISABLED
		depth_m = 0.0
		return
	phase = Phase.DOCKED
	depth_m = 0.0
	target_id = ""
	fail_reason = ""


func charge_kwh(amount: float) -> void:
	if amount <= 0.0:
		return
	battery_kwh = minf(battery_capacity_kwh, battery_kwh + amount)


func apply_battery_level(level: int) -> void:
	var cap := BASE_CAPACITY_KWH * (1.0 + 0.3 * float(maxi(level, 0)))
	var gained := cap - battery_capacity_kwh
	battery_capacity_kwh = cap
	if gained > 0.0:
		battery_kwh = minf(cap, battery_kwh + gained)
	else:
		battery_kwh = minf(battery_kwh, cap)


func apply_scanner_level(level: int) -> void:
	safe_depth_m = BASE_SAFE_DEPTH_M + 30.0 * float(maxi(level, 0))


func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	if phase == Phase.DOCKED or phase == Phase.SURFACE or phase == Phase.DISABLED:
		return
	if hull <= 0.0:
		phase = Phase.DISABLED
		fail_reason = "Submarine hull is destroyed."
		return
	if phase != Phase.RETURN and battery_kwh <= RESERVE_KWH + 1e-9:
		phase = Phase.RETURN
		fail_reason = "Battery reserve — returning."
		return
	if phase == Phase.TRAVEL:
		_tick_travel(dt)
		return
	if phase == Phase.MINE:
		_tick_mine(dt)
		return
	if phase == Phase.RETURN:
		_tick_return(dt)
		return
	var _missing := phase
	push_error("SubVessel tick unhandled phase")


func export_state() -> Dictionary:
	var node_out := {}
	for nid in nodes.keys():
		var node: Dictionary = nodes[nid]
		node_out[str(nid)] = {
			"remaining": float(node.get("remaining", 0.0)),
			"depth_m": float(node.get("depth_m", 0.0)),
			"resource": str(node.get("resource", "")),
			"rate": float(node.get("rate", 0.0)),
			"hardness": float(node.get("hardness", 1.0)),
		}
	return {
		"phase": phase_name(),
		"depth_m": depth_m,
		"battery_kwh": battery_kwh,
		"battery_capacity_kwh": battery_capacity_kwh,
		"hull": hull,
		"cargo": cargo.duplicate(),
		"cargo_capacity": cargo_capacity,
		"safe_depth_m": safe_depth_m,
		"target_id": target_id,
		"fail_reason": fail_reason,
		"nodes": node_out,
	}


func import_state(data: Dictionary) -> void:
	phase = _phase_from_name(str(data.get("phase", "DOCKED")))
	depth_m = maxf(0.0, float(data.get("depth_m", 0.0)))
	if data.has("battery_capacity_kwh"):
		battery_capacity_kwh = maxf(0.1, float(data["battery_capacity_kwh"]))
	battery_kwh = clampf(float(data.get("battery_kwh", battery_kwh)), 0.0, battery_capacity_kwh)
	hull = clampf(float(data.get("hull", hull)), 0.0, 100.0)
	if data.has("cargo_capacity"):
		cargo_capacity = maxf(0.0, float(data["cargo_capacity"]))
	if data.has("safe_depth_m"):
		safe_depth_m = maxf(1.0, float(data["safe_depth_m"]))
	target_id = str(data.get("target_id", ""))
	fail_reason = str(data.get("fail_reason", ""))
	cargo.clear()
	var saved_cargo = data.get("cargo", {})
	if typeof(saved_cargo) == TYPE_DICTIONARY:
		for key in saved_cargo.keys():
			var amount := maxf(0.0, float(saved_cargo[key]))
			if amount > 1e-9:
				cargo[str(key)] = amount
	var saved_nodes = data.get("nodes", {})
	if typeof(saved_nodes) != TYPE_DICTIONARY:
		return
	for nid in saved_nodes.keys():
		if not nodes.has(nid):
			continue
		var src = saved_nodes[nid]
		if typeof(src) != TYPE_DICTIONARY:
			continue
		if src.has("remaining"):
			nodes[nid]["remaining"] = maxf(0.0, float(src["remaining"]))


func _tick_travel(dt: float) -> void:
	var node: Dictionary = nodes.get(target_id, {})
	var target_depth := float(node.get("depth_m", 0.0))
	var step := minf(SPEED_M_PER_S * dt, maxf(0.0, target_depth - depth_m))
	depth_m += step
	if _drain(CRUISE_KW, dt):
		phase = Phase.RETURN
		fail_reason = "Battery empty — returning."
		return
	_apply_depth_stress(dt)
	if hull <= 0.0:
		phase = Phase.DISABLED
		fail_reason = "Hull failed under pressure."
		return
	if depth_m + 1e-6 >= target_depth:
		depth_m = target_depth
		phase = Phase.MINE


func _tick_mine(dt: float) -> void:
	if cargo_free() <= 1e-6:
		phase = Phase.RETURN
		fail_reason = "Cargo full — returning."
		return
	if not nodes.has(target_id):
		phase = Phase.RETURN
		fail_reason = "Deposit is missing."
		return
	var node: Dictionary = nodes[target_id]
	var remaining := float(node.get("remaining", 0.0))
	if remaining <= 1e-9:
		phase = Phase.RETURN
		fail_reason = "Deposit is empty."
		return
	var hardness := maxf(1.0, float(node.get("hardness", 1.0)))
	var rate := float(node.get("rate", 1.0)) / hardness
	var mined := minf(rate * dt, remaining)
	mined = minf(mined, cargo_free())
	if mined <= 0.0:
		phase = Phase.RETURN
		return
	var res_id := str(node.get("resource", "mixed_ore"))
	cargo[res_id] = float(cargo.get(res_id, 0.0)) + mined
	node["remaining"] = remaining - mined
	nodes[target_id] = node
	if _drain(MINE_KW, dt):
		phase = Phase.RETURN
		fail_reason = "Battery empty — returning."
		return
	_apply_depth_stress(dt)
	if hull <= 0.0:
		phase = Phase.DISABLED
		fail_reason = "Hull failed under pressure."
		return
	if float(node["remaining"]) <= 1e-9 or cargo_free() <= 1e-6 or battery_kwh <= RESERVE_KWH:
		phase = Phase.RETURN
		if cargo_free() <= 1e-6:
			fail_reason = "Cargo full — returning."
		elif float(node["remaining"]) <= 1e-9:
			fail_reason = "Deposit is empty."


func _tick_return(dt: float) -> void:
	var step := minf(SPEED_M_PER_S * dt, depth_m)
	depth_m = maxf(0.0, depth_m - step)
	_drain(CRUISE_KW, dt)
	if depth_m <= 1e-6:
		depth_m = 0.0
		phase = Phase.SURFACE
		fail_reason = ""


func _drain(kw: float, dt: float) -> bool:
	var used := kw * dt / 3600.0
	battery_kwh = maxf(0.0, battery_kwh - used)
	return battery_kwh <= 1e-9


func _apply_depth_stress(dt: float) -> void:
	if depth_m <= safe_depth_m:
		return
	var ratio := depth_m / safe_depth_m - 1.0
	hull = maxf(0.0, hull - 8.0 * ratio * ratio * dt)


func _estimate_kwh(node: Dictionary) -> float:
	var target_depth := float(node.get("depth_m", 0.0))
	var travel_s := target_depth / SPEED_M_PER_S
	var hardness := maxf(1.0, float(node.get("hardness", 1.0)))
	var rate := float(node.get("rate", 1.0)) / hardness
	var mine_s := 0.0
	if rate > 0.0:
		mine_s = minf(float(node.get("remaining", 0.0)), cargo_free()) / rate
	var cruise := CRUISE_KW / 3600.0
	var mine := MINE_KW / 3600.0
	return travel_s * cruise * 2.0 + mine_s * mine + RESERVE_KWH


func _phase_from_name(name: String) -> int:
	match name:
		"DOCKED":
			return Phase.DOCKED
		"TRAVEL":
			return Phase.TRAVEL
		"MINE":
			return Phase.MINE
		"RETURN":
			return Phase.RETURN
		"SURFACE":
			return Phase.SURFACE
		"DISABLED":
			return Phase.DISABLED
		_:
			push_error("SubVessel unknown phase name")
			return Phase.DOCKED
