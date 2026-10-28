extends Node
class_name StationSim
## Authoritative station sim: inventory, power bus, recipes, and the submarine.
## Underdeck reads this state. Sub cargo is onboard until unload_sub() at dock.
## Update order: wear → recipe intent → power → machines → sub → alerts.

signal state_changed

var clock: SimClock
var power: PowerNet
var inventory: Inventory
var modules: Dictionary = {}  # id -> StationModule
var recipes: Dictionary = {}
var alerts: Array = []
var last_sanity_ok: bool = true
## Empty after a successful try_spend. Set when a spend is refused.
var last_action_reason: String = ""
var sub: SubVessel

const SAVE_VERSION := 2
const MODULE_REPAIR_SCRAP := 8.0
const MODULE_REPAIR_ELECTRONICS := 2.0
const MODULE_REPAIR_CONDITION := 40.0
const _AUTO_RUN := ["ai_core", "storage", "organic_intake", "comms", "dock", "receiving", "biology", "waste", "walkways"]

const GENERATOR_RATED_KW := 25.0
const CORE_DEMAND_KW := 2.0
const PROCESSOR_DEMAND_KW := 4.0
## Former underdeck starting pile, granted once here. Not a second ledger.
const START_SCRAP := 150.0
const START_ELECTRONICS := 80.0
const START_FUEL_OIL := 40.0

func _ready() -> void:
	setup()

## Idempotent boot. Tests call this without waiting on the scene tree.
func setup() -> void:
	if clock != null:
		return
	clock = SimClock.new()
	clock.name = "SimClock"
	add_child(clock)
	clock.tick_advanced.connect(_on_tick)
	power = PowerNet.new()
	inventory = Inventory.new()
	sub = SubVessel.new()
	sub.setup_nodes()
	_init_inventory()
	_init_modules()
	_load_recipes()
	# Seed starter stock so processor can run, plus the only scrap/electronics grant.
	inventory.transfer_in("biomass", 80.0)
	inventory.transfer_in("fuel_oil", START_FUEL_OIL)
	inventory.transfer_in("scrap", START_SCRAP)
	inventory.transfer_in("electronics", START_ELECTRONICS)

func _init_inventory() -> void:
	# scrap cap was 100, which cannot hold START_SCRAP. electronics is new.
	# Fuel is fuel_oil only — do not add a second "fuel" bin.
	for pair in [
		["biomass", 200.0], ["bio_nutrient", 100.0], ["waste", 100.0],
		["fuel_oil", 100.0], ["scrap", 400.0], ["metal_stock", 50.0],
		["components", 50.0], ["fish", 50.0], ["mixed_ore", 100.0],
		["electronics", 300.0], ["refined_mineral", 80.0]
	]:
		inventory.set_capacity(pair[0], pair[1])

func _init_modules() -> void:
	# Blueprint rooms R01–R10 mapped to module ids
	_add_mod("ai_core", "AI_CORE", 0, CORE_DEMAND_KW)           # R01 D2
	_add_mod("generator", "GENERATOR", 0, 0.0)                  # R02 B2
	_add_mod("organic_intake", "WATER_INTAKE", 2, 1.5)           # R03 A2/A3
	_add_mod("refinery", "REFINERY", 2, 5.0)                    # R04 E2
	_add_mod("dock", "SUB_DOCK", 1, 2.0)                        # R05 B3
	_add_mod("receiving", "RECEIVING", 2, 1.0)                  # R06 C3 stub
	_add_mod("biology", "BIOLOGY", 2, 2.5)                      # R07 D3 stub
	_add_mod("storage", "STORAGE", 3, 0.5)                      # R08 F2/E3
	_add_mod("waste", "WASTE", 3, 1.0)                          # R09 F3 stub
	_add_mod("walkways", "WALKWAYS", 3, 0.2)                    # R10 C2
	_add_mod("processor", "PROCESSOR", 2, PROCESSOR_DEMAND_KW)  # recipe machine (E3/product flow)
	_add_mod("comms", "COMMS", 3, 1.0)                          # C1 dish
	_add_mod("research", "RESEARCH", 3, 3.0)                    # kept for Extreme Spec
	# Intent modes
	modules["ai_core"].set_mode(StationModule.Mode.RUNNING)
	modules["generator"].set_mode(StationModule.Mode.RUNNING)
	modules["processor"].set_mode(StationModule.Mode.STANDBY)
	modules["storage"].set_mode(StationModule.Mode.STANDBY)
	modules["organic_intake"].set_mode(StationModule.Mode.STANDBY)
	modules["refinery"].set_mode(StationModule.Mode.OFF)
	modules["research"].set_mode(StationModule.Mode.OFF)
	modules["comms"].set_mode(StationModule.Mode.STANDBY)
	modules["dock"].set_mode(StationModule.Mode.STANDBY)
	modules["receiving"].set_mode(StationModule.Mode.STANDBY)
	modules["biology"].set_mode(StationModule.Mode.STANDBY)
	modules["waste"].set_mode(StationModule.Mode.STANDBY)
	modules["walkways"].set_mode(StationModule.Mode.RUNNING)

func _add_mod(id: String, typ: String, prio: int, demand: float) -> void:
	var m := StationModule.new()
	m.id = id
	m.type = typ
	m.priority = prio
	m.power_demand = demand
	modules[id] = m

func _load_recipes() -> void:
	var f := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			recipes = data
	else:
		recipes = {
			"biomass_to_nutrients": {
				"id": "biomass_to_nutrients",
				"duration_s": 10,
				"power_kw": 4.0,
				"inputs": {"biomass": 10},
				"outputs": {"bio_nutrient": 6, "waste": 2}
			},
			"ore_to_refined": {
				"id": "ore_to_refined",
				"duration_s": 8,
				"power_kw": 5.0,
				"inputs": {"mixed_ore": 8, "bio_nutrient": 2},
				"outputs": {"refined_mineral": 5, "waste": 1}
			},
			"refined_to_stock": {
				"id": "refined_to_stock",
				"duration_s": 8,
				"power_kw": 4.0,
				"inputs": {"refined_mineral": 4},
				"outputs": {"metal_stock": 3, "waste": 1}
			}
		}

func _on_tick(_tick: int) -> void:
	_tick_once()
	state_changed.emit()

func _tick_once() -> void:
	alerts.clear()
	for id in modules.keys():
		var worn: StationModule = modules[id]
		if worn.mode == StationModule.Mode.RUNNING:
			worn.apply_wear(worn.wear_per_tick)
	_prepare_recipe_modules()
	var gen: StationModule = modules["generator"]
	var gen_out := 0.0
	if gen.is_operable() and gen.mode != StationModule.Mode.OFF:
		var fuel_ok := inventory.get_amount("fuel_oil") >= 0.05
		if fuel_ok:
			inventory.transfer_out("fuel_oil", 0.05)
			gen_out = GENERATOR_RATED_KW * gen.condition_factor()
			if gen.mode != StationModule.Mode.RUNNING:
				gen.set_mode(StationModule.Mode.RUNNING)
		else:
			gen.set_mode(StationModule.Mode.STANDBY, "no fuel_oil")
			alerts.append("Generator starved: no fuel_oil")
	power.set_generation(gen_out)
	power.clear_requests()
	for id in modules.keys():
		var m: StationModule = modules[id]
		var want := _requested_kw(m)
		if want > 0.0:
			power.request(id, want, m.priority)
	power.allocate()
	for id in modules.keys():
		modules[id].power_granted = power.granted(id)
	_tick_recipe_module("processor")
	_tick_recipe_module("refinery")
	_tick_passive_modules()
	_tick_sub()
	last_sanity_ok = inventory.assert_sane()
	if not last_sanity_ok:
		alerts.append("INVENTORY SANITY FAIL")

func _requested_kw(m: StationModule) -> float:
	if m.type == "GENERATOR":
		return 0.0
	match m.mode:
		StationModule.Mode.OFF, StationModule.Mode.FAULTED, StationModule.Mode.DESTROYED:
			return 0.0
		StationModule.Mode.RUNNING:
			return _running_demand(m)
		StationModule.Mode.STANDBY, StationModule.Mode.PAUSED:
			return m.idle_power()
		_:
			var _missing := m.mode
			push_error("StationSim unhandled module mode")
			return 0.0

func _running_demand(m: StationModule) -> float:
	if not m.active_recipe.is_empty():
		return float(m.active_recipe.get("power_kw", m.power_demand))
	if m.id == "processor":
		var recipe: Dictionary = recipes.get("biomass_to_nutrients", {})
		if not recipe.is_empty():
			return float(recipe.get("power_kw", m.power_demand))
	return m.power_demand

func _prepare_recipe_modules() -> void:
	for module_id in ["processor", "refinery"]:
		var m: StationModule = modules[module_id]
		if m.mode == StationModule.Mode.OFF or m.mode == StationModule.Mode.FAULTED or m.mode == StationModule.Mode.DESTROYED or m.mode == StationModule.Mode.PAUSED:
			continue
		var recipe := m.active_recipe
		if recipe.is_empty():
			recipe = _pick_recipe(module_id)
		if recipe.is_empty():
			continue
		if m.active_recipe.is_empty() and (not _inputs_ok(recipe) or not _outputs_ok(recipe)):
			continue
		if m.mode == StationModule.Mode.STANDBY:
			m.set_mode(StationModule.Mode.RUNNING, "")

func _tick_passive_modules() -> void:
	for id in _AUTO_RUN:
		var m: StationModule = modules[id]
		if m.mode == StationModule.Mode.OFF or m.mode == StationModule.Mode.DESTROYED or m.mode == StationModule.Mode.FAULTED:
			continue
		if m.power_demand <= 0.0:
			continue
		var full := m.power_demand
		var idle := m.idle_power()
		if m.mode == StationModule.Mode.RUNNING:
			if m.power_granted + 1e-6 < full:
				m.set_mode(StationModule.Mode.STANDBY, "insufficient power (granted %.2f / need %.2f)" % [m.power_granted, full])
			continue
		if m.mode != StationModule.Mode.STANDBY and m.mode != StationModule.Mode.PAUSED:
			continue
		if m.power_granted + 1e-6 < idle:
			m.set_mode(StationModule.Mode.STANDBY, "insufficient power (granted %.2f / need %.2f)" % [m.power_granted, idle])
			continue
		if m.mode == StationModule.Mode.STANDBY and m.power_granted + power.available_kw() + 1e-6 >= full:
			m.set_mode(StationModule.Mode.RUNNING, "")

func _tick_recipe_module(module_id: String) -> void:
	var m: StationModule = modules[module_id]
	if m.mode == StationModule.Mode.OFF or m.mode == StationModule.Mode.DESTROYED or m.mode == StationModule.Mode.FAULTED:
		return
	if m.active_recipe.is_empty():
		var recipe := _pick_recipe(module_id)
		if recipe.is_empty():
			if m.mode != StationModule.Mode.PAUSED:
				m.set_mode(StationModule.Mode.STANDBY, _recipe_block_reason(module_id))
			return
		if not _inputs_ok(recipe):
			m.set_mode(StationModule.Mode.STANDBY, _recipe_block_reason(module_id))
			return
		if not _outputs_ok(recipe):
			m.set_mode(StationModule.Mode.PAUSED, "output full — no silent overflow")
			return
		m.active_recipe = recipe.duplicate(true)
		m.job_duration = float(recipe.get("duration_s", 1.0))
		m.job_progress = 0.0
	var need_pwr := float(m.active_recipe.get("power_kw", m.power_demand))
	if m.power_granted + 1e-6 < need_pwr:
		m.set_mode(StationModule.Mode.STANDBY, "insufficient power (granted %.2f / need %.2f)" % [m.power_granted, need_pwr])
		return
	m.set_mode(StationModule.Mode.RUNNING)
	m.blocked_reason = ""
	m.job_progress += 1.0 * m.condition_factor()
	if m.job_progress < m.job_duration:
		return
	if inventory.try_recipe(m.active_recipe["inputs"], m.active_recipe["outputs"]):
		m.active_recipe = {}
		m.job_progress = 0.0
		m.job_duration = 0.0
	else:
		m.set_mode(StationModule.Mode.PAUSED, "recipe commit blocked (input/output)")
		m.active_recipe = {}
		m.job_progress = 0.0

func _pick_recipe(module_id: String) -> Dictionary:
	if module_id == "processor":
		return recipes.get("biomass_to_nutrients", {})
	if module_id == "refinery":
		var waiting_on_output: Dictionary = {}
		# Downstream stock runs before another ore batch when both are ready.
		for recipe_id in ["refined_to_stock", "ore_to_refined"]:
			var recipe: Dictionary = recipes.get(recipe_id, {})
			if recipe.is_empty():
				continue
			if _inputs_ok(recipe) and _outputs_ok(recipe):
				return recipe
			if _inputs_ok(recipe) and not _outputs_ok(recipe):
				waiting_on_output = recipe
		return waiting_on_output
	return {}

func _recipe_block_reason(module_id: String) -> String:
	if module_id == "processor":
		return "waiting for biomass input"
	if module_id == "refinery":
		return "waiting for input"
	return "no recipe"

func _inputs_ok(recipe: Dictionary) -> bool:
	if not recipe.has("inputs"):
		return false
	for key in recipe["inputs"].keys():
		if inventory.get_amount(str(key)) + 1e-9 < float(recipe["inputs"][key]):
			return false
	return true

func _outputs_ok(recipe: Dictionary) -> bool:
	if not recipe.has("outputs"):
		return true
	for key in recipe["outputs"].keys():
		if inventory.free_capacity(str(key)) + 1e-9 < float(recipe["outputs"][key]):
			return false
	return true

func _tick_sub() -> void:
	if sub.phase == SubVessel.Phase.DOCKED or sub.phase == SubVessel.Phase.SURFACE:
		# Charge from surplus only. Do not hold reserved_kw — that bus lock is for
		# one-shot hatch/launch spends and must be clear at the end of the tick.
		if sub.battery_kwh + 1e-6 < sub.battery_capacity_kwh and power.available_kw() > 6.0:
			var take := minf(SubVessel.CHARGE_KW, power.available_kw() - 6.0)
			sub.charge_kwh(take / 3600.0)
		return
	sub.tick(SimClock.TICK_SECONDS)

## Atomic inventory spend plus an optional kW reservation on the live bus.
## power_kw is not an inventory id and is not stored charge.
## On false, inventory and reservations are unchanged and last_action_reason is set.
func try_spend(costs: Dictionary, power_kw: float = 0.0) -> bool:
	last_action_reason = ""
	if power_kw < 0.0:
		last_action_reason = "Invalid power cost."
		return false
	for key in costs.keys():
		var res_id := str(key)
		var amount := float(costs[key])
		if res_id == "fuel" or res_id == "electricity" or res_id == "power_kw":
			last_action_reason = "Resource '%s' is not a station bin. Use fuel_oil, and pass bus power as power_kw." % res_id
			return false
		if amount < 0.0:
			last_action_reason = "Invalid cost for %s." % res_id
			return false
		if not inventory.can_remove(res_id, amount):
			last_action_reason = "Not enough %s (have %.2f, need %.2f)." % [res_id, inventory.get_amount(res_id), amount]
			return false
	if power_kw > 0.0 and not power.can_reserve(power_kw):
		last_action_reason = "Insufficient station power (available %.2f kW, need %.2f kW)." % [power.available_kw(), power_kw]
		return false
	if not costs.is_empty() and not inventory.try_recipe(costs, {}):
		last_action_reason = "Spend blocked; inventory unchanged."
		return false
	if power_kw > 0.0 and not power.reserve(power_kw):
		for key in costs.keys():
			inventory.transfer_in(str(key), float(costs[key]))
		last_action_reason = "Insufficient station power (available %.2f kW, need %.2f kW)." % [power.available_kw(), power_kw]
		return false
	state_changed.emit()
	return true

func try_repair_module(module_id: String) -> bool:
	if not modules.has(module_id):
		last_action_reason = "Unknown module."
		return false
	var m: StationModule = modules[module_id]
	if m.mode == StationModule.Mode.DESTROYED or m.condition <= 0.0:
		last_action_reason = "Module is destroyed."
		return false
	if m.mode != StationModule.Mode.FAULTED:
		last_action_reason = "Module is not faulted."
		return false
	if not try_spend({"scrap": MODULE_REPAIR_SCRAP, "electronics": MODULE_REPAIR_ELECTRONICS}):
		return false
	m.condition = minf(100.0, m.condition + MODULE_REPAIR_CONDITION)
	if m.condition > StationModule.FAULT_CONDITION:
		m.set_mode(StationModule.Mode.STANDBY, "")
	return true

func sub_status() -> Dictionary:
	return sub.status()

func sub_fail_reason() -> String:
	return sub.fail_reason

func sub_default_target() -> String:
	if sub.nodes.has("shelf_ore"):
		var preferred: Dictionary = sub.nodes["shelf_ore"]
		if float(preferred.get("remaining", 0.0)) > 1e-9 and float(preferred.get("depth_m", 0.0)) <= sub.safe_depth_m + 1e-6:
			return "shelf_ore"
	for nid in sub.nodes.keys():
		var node: Dictionary = sub.nodes[nid]
		if float(node.get("remaining", 0.0)) <= 1e-9:
			continue
		if float(node.get("depth_m", 0.0)) > sub.safe_depth_m + 1e-6:
			continue
		return str(nid)
	return ""

func sub_can_depart(node_id: String) -> bool:
	var ok := sub.can_depart(node_id)
	if not ok:
		last_action_reason = sub.fail_reason
	return ok

func sub_depart(node_id: String) -> bool:
	if not sub.can_depart(node_id):
		last_action_reason = sub.fail_reason
		return false
	sub.begin_travel(node_id)
	last_action_reason = ""
	return true

func sub_order_return() -> bool:
	var ok := sub.order_return()
	if not ok:
		last_action_reason = sub.fail_reason
	return ok

## Cargo moves into station bins only from DOCKED or SURFACE. Remainder stays aboard.
func unload_sub() -> Dictionary:
	if sub.phase != SubVessel.Phase.DOCKED and sub.phase != SubVessel.Phase.SURFACE:
		last_action_reason = "Submarine is not docked."
		return {}
	var moved := {}
	var keys: Array = sub.cargo.keys()
	for key in keys:
		var res_id := str(key)
		var have := float(sub.cargo[key])
		var got := inventory.transfer_in(res_id, have)
		var left := have - got
		if left <= 1e-8:
			sub.cargo.erase(key)
		else:
			sub.cargo[key] = left
			last_action_reason = "Storage full for %s." % res_id
		if got > 0.0:
			moved[res_id] = got
	if sub.phase == SubVessel.Phase.SURFACE:
		sub.phase = SubVessel.Phase.DOCKED
		sub.depth_m = 0.0
	state_changed.emit()
	return moved

func finish_recovery() -> Dictionary:
	sub.recover_to_bay()
	return unload_sub()

func export_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"clock": clock.export_state(),
		"inventory": inventory.export_state(),
		"modules": _export_modules(),
		"sub": sub.export_state(),
	}

func load_state(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		last_action_reason = "Save is not a dictionary."
		return false
	if not data.has("version"):
		last_action_reason = "Save is missing a version."
		return false
	var version := int(data["version"])
	if version < 1 or version > SAVE_VERSION:
		last_action_reason = "Unsupported save version."
		return false
	var clock_data = data.get("clock", {})
	if typeof(clock_data) == TYPE_DICTIONARY:
		clock.import_state(clock_data)
	var inv_data = data.get("inventory", {})
	if typeof(inv_data) == TYPE_DICTIONARY:
		inventory.import_state(inv_data)
	var mods = data.get("modules", {})
	if typeof(mods) == TYPE_DICTIONARY:
		_apply_module_state(mods)
	var sub_data = data.get("sub", {})
	if typeof(sub_data) == TYPE_DICTIONARY and version >= 2:
		sub.import_state(sub_data)
	last_sanity_ok = inventory.assert_sane()
	last_action_reason = ""
	state_changed.emit()
	return true

func _export_modules() -> Dictionary:
	var out := {}
	for id in modules.keys():
		var m: StationModule = modules[id]
		out[id] = {
			"mode": m.mode_name(),
			"condition": m.condition,
			"blocked_reason": m.blocked_reason,
			"job_progress": m.job_progress,
			"job_duration": m.job_duration,
			"recipe_id": str(m.active_recipe.get("id", "")),
			"level": m.level,
		}
	return out

func _apply_module_state(saved: Dictionary) -> void:
	for id in saved.keys():
		if not modules.has(str(id)):
			continue
		var src = saved[id]
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var m: StationModule = modules[str(id)]
		m.mode = StationModule.mode_from_name(str(src.get("mode", m.mode_name())))
		m.condition = clampf(float(src.get("condition", m.condition)), 0.0, 100.0)
		m.blocked_reason = str(src.get("blocked_reason", ""))
		m.job_progress = maxf(0.0, float(src.get("job_progress", 0.0)))
		m.job_duration = maxf(0.0, float(src.get("job_duration", 0.0)))
		if src.has("level"):
			m.level = maxi(int(src["level"]), 1)
		var recipe_id := str(src.get("recipe_id", ""))
		if recipe_id != "" and recipes.has(recipe_id):
			m.active_recipe = (recipes[recipe_id] as Dictionary).duplicate(true)
		else:
			m.active_recipe = {}
			if recipe_id != "":
				m.job_progress = 0.0
				m.job_duration = 0.0

func get_inspect(module_id: String) -> Dictionary:
	if not modules.has(module_id):
		return {"id": module_id, "error": "unknown module"}
	var m: StationModule = modules[module_id]
	return {
		"id": m.id,
		"type": m.type,
		"mode": m.mode_name(),
		"condition": snappedf(m.condition, 0.1),
		"power_demand": m.power_demand,
		"power_granted": snappedf(m.power_granted, 0.01),
		"priority": m.priority,
		"blocked_reason": m.blocked_reason,
		"job_progress": snappedf(m.job_progress, 0.1),
		"job_duration": m.job_duration,
		"recipe": str(m.active_recipe.get("id", "")),
	}

func snapshot() -> Dictionary:
	return {
		"tick": clock.tick,
		"paused": clock.paused,
		"speed": clock.speed,
		"power_generated": snappedf(power.generated, 0.01),
		"power_requested": snappedf(power.requested, 0.01),
		"power_granted": snappedf(power.granted_total, 0.01),
		"power_available": snappedf(power.available_kw(), 0.01),
		"power_reserved": snappedf(power.reserved_kw, 0.01),
		"biomass": snappedf(inventory.get_amount("biomass"), 0.1),
		"bio_nutrient": snappedf(inventory.get_amount("bio_nutrient"), 0.1),
		"waste": snappedf(inventory.get_amount("waste"), 0.1),
		"fuel_oil": snappedf(inventory.get_amount("fuel_oil"), 0.1),
		"scrap": snappedf(inventory.get_amount("scrap"), 0.1),
		"electronics": snappedf(inventory.get_amount("electronics"), 0.1),
		"mixed_ore": snappedf(inventory.get_amount("mixed_ore"), 0.1),
		"metal_stock": snappedf(inventory.get_amount("metal_stock"), 0.1),
		"sub_phase": sub.phase_name(),
		"sub_depth_m": snappedf(sub.depth_m, 0.1),
		"sub_battery_kwh": snappedf(sub.battery_kwh, 0.001),
		"sub_cargo_total": snappedf(sub.cargo_total(), 0.1),
		"sub_hull": snappedf(sub.hull, 0.1),
		"sanity_ok": last_sanity_ok,
		"alerts": alerts.duplicate(),
	}
