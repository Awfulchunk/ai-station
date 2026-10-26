extends Node
class_name StationSim
## Authoritative station sim. Update order (this test, no sub/world):
## wear/cooling → power gen + allocate → machines → inventory settle → alerts → HUD bind.

signal state_changed

var clock: SimClock
var power: PowerNet
var inventory: Inventory
var modules: Dictionary = {}  # id -> StationModule
var recipes: Dictionary = {}
var alerts: Array = []
var last_sanity_ok: bool = true

const GENERATOR_RATED_KW := 25.0
const CORE_DEMAND_KW := 2.0
const PROCESSOR_DEMAND_KW := 4.0

func _ready() -> void:
	clock = SimClock.new()
	clock.name = "SimClock"
	add_child(clock)
	clock.tick_advanced.connect(_on_tick)
	power = PowerNet.new()
	inventory = Inventory.new()
	_init_inventory()
	_init_modules()
	_load_recipes()
	# Seed starter stock so processor can run
	inventory.transfer_in("biomass", 80.0)
	inventory.transfer_in("fuel_oil", 40.0)

func _init_inventory() -> void:
	for pair in [
		["biomass", 200.0], ["bio_nutrient", 100.0], ["waste", 100.0],
		["fuel_oil", 100.0], ["scrap", 100.0], ["metal_stock", 50.0],
		["components", 50.0], ["fish", 50.0], ["mixed_ore", 100.0]
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
			}
		}

func _on_tick(_tick: int) -> void:
	_tick_once()
	state_changed.emit()

func _tick_once() -> void:
	alerts.clear()
	# 1) Wear on active modules
	for id in modules.keys():
		var m: StationModule = modules[id]
		if m.mode == StationModule.Mode.RUNNING:
			m.apply_wear(m.wear_per_tick)

	# 2) Power generation + allocate
	var gen: StationModule = modules["generator"]
	var gen_out := 0.0
	if gen.is_operable() and gen.mode != StationModule.Mode.OFF:
		# Fuel factor: consume a little fuel_oil
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
		if m.type == "GENERATOR":
			continue
		var want := 0.0
		if m.mode == StationModule.Mode.RUNNING or m.mode == StationModule.Mode.STANDBY:
			want = m.power_demand
			# Processor demands recipe power when working
			if m.id == "processor" and not m.active_recipe.is_empty():
				want = float(m.active_recipe.get("power_kw", m.power_demand))
		if want > 0.0:
			power.request(id, want, m.priority)
	power.allocate()
	for id in modules.keys():
		modules[id].power_granted = power.granted(id)

	# 3) Machines — processor recipe
	_tick_processor()
	_tick_passive_modules()

	# 4) Inventory settle / sanity
	last_sanity_ok = inventory.assert_sane()
	if not last_sanity_ok:
		alerts.append("INVENTORY SANITY FAIL")

func _tick_passive_modules() -> void:
	for id in ["ai_core", "storage", "organic_intake", "comms", "dock", "refinery", "research", "receiving", "biology", "waste", "walkways"]:
		var m: StationModule = modules[id]
		if m.mode == StationModule.Mode.OFF or m.mode == StationModule.Mode.DESTROYED or m.mode == StationModule.Mode.FAULTED:
			continue
		if m.power_demand <= 0.0:
			continue
		if m.power_granted + 1e-6 < m.power_demand:
			m.set_mode(StationModule.Mode.STANDBY, "insufficient power (granted %.2f / need %.2f)" % [m.power_granted, m.power_demand])
		elif m.mode == StationModule.Mode.STANDBY and m.blocked_reason.begins_with("insufficient power"):
			# Core always wants to run when powered
			if m.id in ["ai_core", "comms", "storage", "dock", "walkways", "receiving", "biology", "waste"]:
				m.set_mode(StationModule.Mode.RUNNING)
				m.blocked_reason = ""

func _tick_processor() -> void:
	var m: StationModule = modules["processor"]
	if m.mode == StationModule.Mode.OFF or m.mode == StationModule.Mode.DESTROYED or m.mode == StationModule.Mode.FAULTED:
		return
	var recipe: Dictionary = recipes.get("biomass_to_nutrients", {})
	if recipe.is_empty():
		m.set_mode(StationModule.Mode.STANDBY, "no recipe")
		return

	# Ensure job
	if m.active_recipe.is_empty():
		# Check inputs + output capacity before starting
		var ok_in := true
		for k in recipe["inputs"].keys():
			if inventory.get_amount(str(k)) < float(recipe["inputs"][k]):
				ok_in = false
				break
		if not ok_in:
			m.set_mode(StationModule.Mode.STANDBY, "waiting for biomass input")
			return
		var ok_out := true
		for k in recipe["outputs"].keys():
			if inventory.free_capacity(str(k)) < float(recipe["outputs"][k]):
				ok_out = false
				break
		if not ok_out:
			m.set_mode(StationModule.Mode.PAUSED, "output full — no silent overflow")
			return
		m.active_recipe = recipe.duplicate(true)
		m.job_duration = float(recipe["duration_s"])
		m.job_progress = 0.0

	var need_pwr := float(m.active_recipe.get("power_kw", PROCESSOR_DEMAND_KW))
	if m.power_granted + 1e-6 < need_pwr:
		m.set_mode(StationModule.Mode.STANDBY, "insufficient power (granted %.2f / need %.2f)" % [m.power_granted, need_pwr])
		return

	m.set_mode(StationModule.Mode.RUNNING)
	m.blocked_reason = ""
	m.job_progress += 1.0 * m.condition_factor()
	if m.job_progress >= m.job_duration:
		# Commit recipe atomically
		if inventory.try_recipe(m.active_recipe["inputs"], m.active_recipe["outputs"]):
			m.active_recipe = {}
			m.job_progress = 0.0
			m.job_duration = 0.0
		else:
			m.set_mode(StationModule.Mode.PAUSED, "recipe commit blocked (input/output)")
			m.active_recipe = {}
			m.job_progress = 0.0

func get_inspect(module_id: String) -> Dictionary:
	if not modules.has(module_id):
		return {"id": module_id, "error": "unknown module"}
	var m: StationModule = modules[module_id]
	var mode_names := ["OFF", "STANDBY", "RUNNING", "PAUSED", "FAULTED", "DESTROYED"]
	return {
		"id": m.id,
		"type": m.type,
		"mode": mode_names[m.mode] if m.mode < mode_names.size() else str(m.mode),
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
		"biomass": snappedf(inventory.get_amount("biomass"), 0.1),
		"bio_nutrient": snappedf(inventory.get_amount("bio_nutrient"), 0.1),
		"waste": snappedf(inventory.get_amount("waste"), 0.1),
		"fuel_oil": snappedf(inventory.get_amount("fuel_oil"), 0.1),
		"sanity_ok": last_sanity_ok,
		"alerts": alerts.duplicate(),
	}
