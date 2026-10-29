extends SceneTree
## godot --headless --path . --script res://scripts/sim/self_test.gd

const RoomPowerScript := preload("res://scripts/cutaway/room_power_readout.gd")

func _initialize() -> void:
	var inv := Inventory.new()
	inv.set_capacity("biomass", 100.0)
	inv.set_capacity("bio_nutrient", 100.0)
	inv.set_capacity("waste", 100.0)
	assert(inv.transfer_in("biomass", 50.0) == 50.0)
	assert(inv.transfer_in("biomass", 60.0) == 50.0)  # capped, no silent overflow of rest into void — remainder refused
	assert(inv.get_amount("biomass") == 100.0)
	assert(inv.transfer_out("biomass", 200.0) == 100.0)  # no overdraw
	assert(inv.get_amount("biomass") == 0.0)
	inv.transfer_in("biomass", 10.0)
	assert(inv.try_recipe({"biomass": 10}, {"bio_nutrient": 6, "waste": 2}))
	assert(inv.get_amount("biomass") == 0.0)
	assert(inv.get_amount("bio_nutrient") == 6.0)
	# overflow refuse
	inv.set_capacity("bio_nutrient", 6.0)
	assert(not inv.try_recipe({}, {"bio_nutrient": 1}))
	assert(inv.get_amount("bio_nutrient") == 6.0)

	var net := PowerNet.new()
	net.set_generation(10.0)
	net.request("ai_core", 2.0, 0)
	net.request("processor", 8.0, 2)
	net.request("research", 5.0, 3)
	net.allocate()
	assert(abs(net.granted("ai_core") - 2.0) < 1e-6)
	assert(abs(net.granted("processor") - 8.0) < 1e-6)
	assert(abs(net.granted("research") - 0.0) < 1e-6)  # starved
	_test_station_authority()
	if _failed:
		return
	_test_standby_power_and_wear()
	if _failed:
		return
	_test_sub_mission_and_chain()
	if _failed:
		return
	_test_pause_save_and_visual()
	if _failed:
		return
	_test_deep_shell()
	if _failed:
		return
	print("SELF_TEST_OK")
	quit()


var _failed := false

func _check(cond: bool, msg: String) -> void:
	if _failed or cond:
		return
	_failed = true
	push_error("SELF_TEST_FAIL " + msg)
	quit(1)


func _test_station_authority() -> void:
	var sim := StationSim.new()
	sim.setup()
	_check(sim.inventory != null, "inventory missing after setup")
	_check(sim.inventory.get_amount("scrap") == StationSim.START_SCRAP, "scrap start")
	_check(sim.inventory.get_amount("electronics") == StationSim.START_ELECTRONICS, "electronics start")
	_check(sim.inventory.get_amount("fuel_oil") == StationSim.START_FUEL_OIL, "fuel_oil start")
	_check(not sim.inventory.stock.has("fuel"), "fuel bin must not exist")
	_check(not sim.inventory.stock.has("electricity"), "electricity bin must not exist")

	var scrap0 := sim.inventory.get_amount("scrap")
	var elec0 := sim.inventory.get_amount("electronics")
	var fuel0 := sim.inventory.get_amount("fuel_oil")
	_check(not sim.try_spend({"scrap": -1.0}), "negative scrap " + sim.last_action_reason)
	_check("Invalid" in sim.last_action_reason, sim.last_action_reason)
	_check(not sim.try_spend({"fuel": 1.0}), "fuel alias must be rejected")
	_check("fuel_oil" in sim.last_action_reason, sim.last_action_reason)
	_check(not sim.try_spend({"scrap": 5.0, "electronics": 10000.0}), "short electronics should fail")
	_check("electronics" in sim.last_action_reason, sim.last_action_reason)
	_check(sim.inventory.get_amount("scrap") == scrap0, "scrap changed on failed spend")
	_check(sim.inventory.get_amount("electronics") == elec0, "electronics changed on failed spend")
	# Bus has not ticked, so a fuel+power spend must refuse both.
	_check(not sim.try_spend({"fuel_oil": 8.0}, 5.0), "power spend before generation")
	_check("power" in sim.last_action_reason.to_lower(), sim.last_action_reason)
	_check(sim.inventory.get_amount("fuel_oil") == fuel0, "fuel spent on failed power check")

	_check(sim.try_spend({"scrap": 1.0, "electronics": 1.0}), sim.last_action_reason)
	_check(sim.last_action_reason == "", "reason not cleared")
	_check(abs(sim.inventory.get_amount("scrap") - (scrap0 - 1.0)) < 1e-6, "scrap spend")
	_check(abs(sim.inventory.get_amount("electronics") - (elec0 - 1.0)) < 1e-6, "electronics spend")

	sim.clock.advance_n(1)
	var fuel_after_tick := sim.inventory.get_amount("fuel_oil")
	_check(fuel_after_tick < fuel0, "generator did not burn fuel_oil")
	var avail := sim.power.available_kw()
	_check(avail > 5.0, "expected spare kW, have %s" % avail)
	_check(sim.try_spend({"fuel_oil": 8.0}, 5.0), sim.last_action_reason)
	_check(abs(sim.inventory.get_amount("fuel_oil") - (fuel_after_tick - 8.0)) < 1e-4, "fuel_oil spend")
	_check(sim.power.available_kw() < avail - 4.0, "reservation did not reduce spare kW")
	var fuel_mid := sim.inventory.get_amount("fuel_oil")
	_check(not sim.try_spend({"fuel_oil": 1.0}, sim.power.available_kw() + 50.0), "oversized power spend should fail")
	_check(abs(sim.inventory.get_amount("fuel_oil") - fuel_mid) < 1e-6, "fuel spent on failed power reservation")
	sim.clock.advance_n(1)
	_check(sim.power.reserved_kw == 0.0, "reservation survived the next tick")
	_check(sim.power.available_kw() > 5.0, "spare kW missing after tick")

	var unbound := OilRigUnderdeckSystems.new()
	_check(not unbound.open_hatch(), "unbound hatch opened")
	_check("not bound" in unbound.get_last_error(), unbound.get_last_error())
	_check(unbound.hatch_state == OilRigUnderdeckSystems.HatchState.CLOSED, "unbound hatch moved")

	var bay := OilRigUnderdeckSystems.new()
	bay.bind_sim(sim)
	var fuel_before_launch := sim.inventory.get_amount("fuel_oil")
	_check(not bay.launch_sub(), "launch with closed hatch")
	_check(sim.inventory.get_amount("fuel_oil") == fuel_before_launch, "fuel spent on refused launch")
	_check("hatch" in bay.get_last_error().to_lower(), bay.get_last_error())
	_check(bay.open_hatch(), bay.get_last_error())
	_check(bay.hatch_state == OilRigUnderdeckSystems.HatchState.UNLOCKING, "hatch did not start unlocking")
	_check(not bay.launch_sub(), "launch during unlock")
	_check(sim.inventory.get_amount("fuel_oil") == fuel_before_launch, "fuel spent during unlock")
	bay.hatch_state = OilRigUnderdeckSystems.HatchState.OPEN
	_check(bay.launch_sub(), bay.get_last_error())
	_check(abs(sim.inventory.get_amount("fuel_oil") - (fuel_before_launch - bay.sub_fuel_cost)) < 1e-4, "launch fuel")
	_check(bay.sub_state == OilRigUnderdeckSystems.SubState.PREPARING, "sub did not enter preparing")

	bay.damage_hatch(0.5)
	var scrap_before_repair := sim.inventory.get_amount("scrap")
	var damage_before := bay.hatch_damage
	_check(bay.repair_hatch(0.25), bay.get_last_error())
	_check(abs(sim.inventory.get_amount("scrap") - (scrap_before_repair - float(bay.repair_scrap_cost))) < 1e-4, "hatch repair scrap")
	_check(bay.hatch_damage < damage_before, "hatch damage not reduced")
	bay.damage_pontoon(1, 0.4)
	var scrap_before_pontoon := sim.inventory.get_amount("scrap")
	_check(bay.repair_pontoon(1, 0.25), bay.get_last_error())
	_check(sim.inventory.get_amount("scrap") < scrap_before_pontoon, "pontoon repair spent nothing")
	var scrap_before_bad_index := sim.inventory.get_amount("scrap")
	_check(not bay.repair_pontoon(9, 0.25), "bad pontoon index succeeded")
	_check(sim.inventory.get_amount("scrap") == scrap_before_bad_index, "bad index spent scrap")

	var elec_before_upgrade := sim.inventory.get_amount("electronics")
	var scrap_before_upgrade := sim.inventory.get_amount("scrap")
	_check(bay.purchase_upgrade("pipe_insulation"), bay.get_last_error())
	_check(int(bay.upgrades["pipe_insulation"]) == 1, "upgrade level")
	_check(sim.inventory.get_amount("scrap") < scrap_before_upgrade, "upgrade spent no scrap")
	_check(sim.inventory.get_amount("electronics") < elec_before_upgrade, "upgrade spent no electronics")
	sim.inventory.transfer_out("scrap", sim.inventory.get_amount("scrap"))
	var elec_starved := sim.inventory.get_amount("electronics")
	var actuator_level := int(bay.upgrades["hatch_actuators"])
	_check(not bay.purchase_upgrade("hatch_actuators"), "upgrade succeeded with no scrap")
	_check(sim.inventory.get_amount("electronics") == elec_starved, "electronics spent on failed upgrade")
	_check(int(bay.upgrades["hatch_actuators"]) == actuator_level, "upgrade level changed on failure")
	_check(bay.get_last_error() != "", "missing upgrade failure reason")

	bay.sub_state = OilRigUnderdeckSystems.SubState.AWAY
	bay.hatch_state = OilRigUnderdeckSystems.HatchState.OPEN
	sim.power.set_generation(0.0)
	_check(not bay.recover_sub(), "recover succeeded with no generation")
	_check(bay.sub_state == OilRigUnderdeckSystems.SubState.AWAY, "recover changed state on failure")
	_check("power" in bay.get_last_error().to_lower(), bay.get_last_error())
	bay.sub_state = OilRigUnderdeckSystems.SubState.DOCKED
	_check(not bay.close_hatch(), "close succeeded with no generation")
	_check(bay.hatch_state == OilRigUnderdeckSystems.HatchState.OPEN, "close moved hatch on failure")
	sim.power.set_generation(StationSim.GENERATOR_RATED_KW)
	sim.power.reserved_kw = 0.0
	_check(bay.close_hatch(), bay.get_last_error())
	_check(bay.hatch_state == OilRigUnderdeckSystems.HatchState.CLOSING, "hatch did not start closing")

	var status := bay.get_system_status()
	_check(not status.has("electricity"), "status still exposes an electricity stock")
	_check(not status.has("fuel"), "status still exposes a second fuel id")
	_check(abs(float(status["scrap"]) - sim.inventory.get_amount("scrap")) < 1e-6, "status scrap drift")
	_check(abs(float(status["fuel_oil"]) - sim.inventory.get_amount("fuel_oil")) < 1e-6, "status fuel drift")
	_check(abs(float(status["electronics"]) - sim.inventory.get_amount("electronics")) < 1e-6, "status electronics drift")
	bay.add_resources(0, 0, 0.0, 5.0)
	_check("live bus" in bay.get_last_error(), bay.get_last_error())
	_check(not sim.inventory.stock.has("electricity"), "power deposit created a bin")
	unbound.free()
	bay.free()
	sim.free()
	_test_room_readouts()


func _test_room_readouts() -> void:
	var sim := StationSim.new()
	sim.setup()
	var scrap0 := sim.inventory.get_amount("scrap")
	var elec0 := sim.inventory.get_amount("electronics")
	sim.clock.advance_n(1)
	var live: RoomPowerReadout = _meter(sim, "ai_core")
	var idle: RoomPowerReadout = _meter(sim, "refinery")
	var held: RoomPowerReadout = _meter(sim, "organic_intake")
	var live_read: Dictionary = live.get_reading()
	var idle_read: Dictionary = idle.get_reading()
	var held_read: Dictionary = held.get_reading()
	_check(str(live_read["feed"]) == "LIVE", "ai_core feed %s" % live_read)
	_check(float(live_read["load"]) > 0.9, "ai_core load %s" % live_read)
	_check(str(idle_read["feed"]) == "IDLE", "refinery feed %s" % idle_read)
	_check(float(idle_read["load"]) == 0.0, "refinery load %s" % idle_read)
	_check(str(held_read["feed"]) == "STARVED", "intake feed %s" % held_read)
	_check(float(live_read["fuel"]) > 0.3 and float(live_read["fuel"]) < 0.45, "fuel fraction %s" % live_read)
	_check(live.bulb_color().g > idle.bulb_color().g + 0.25, "live lamp not distinct from idle")
	_check(sim.inventory.get_amount("scrap") == scrap0, "readout spent scrap")
	_check(sim.inventory.get_amount("electronics") == elec0, "readout spent electronics")
	live.get_parent().free()
	idle.get_parent().free()
	held.get_parent().free()
	sim.free()


func _meter(sim: StationSim, module_id: String) -> RoomPowerReadout:
	var host := Node2D.new()
	var tap := Node2D.new()
	tap.name = "BusTap"
	host.add_child(tap)
	var needle := Polygon2D.new()
	needle.name = "NeedleLoad"
	needle.polygon = PackedVector2Array([
		Vector2(-0.7, 28.0), Vector2(0.0, 22.0), Vector2(0.7, 28.0),
	])
	tap.add_child(needle)
	var fill := Polygon2D.new()
	fill.name = "LoadFill"
	var span := Rect2(0.0, 10.0, 4.0, 16.0)
	fill.set_meta("span", span)
	fill.polygon = PackedVector2Array([
		Vector2(0, 10), Vector2(4, 10), Vector2(4, 26), Vector2(0, 26),
	])
	tap.add_child(fill)
	var lamp := Node2D.new()
	lamp.name = "LiveLamp"
	tap.add_child(lamp)
	var bulb := Polygon2D.new()
	bulb.name = "Bulb"
	bulb.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4),
	])
	lamp.add_child(bulb)
	var readout = RoomPowerScript.new()
	readout.module_id = module_id
	host.add_child(readout)
	readout.capture(host)
	readout.bind_sim(sim)
	return readout


func _test_standby_power_and_wear() -> void:
	var lone := StationModule.new()
	lone.set_mode(StationModule.Mode.RUNNING)
	lone.condition = 50.0
	lone.apply_wear(40.0)
	_check(lone.mode == StationModule.Mode.FAULTED, "wear skipped FAULTED mode=%s cond=%s" % [lone.mode, lone.condition])
	_check(lone.condition > 0.0, "fault clamped condition to zero")
	_check(abs(lone.condition - StationModule.FAULT_CONDITION) < 1e-6, "fault condition %s" % lone.condition)
	lone.apply_wear(lone.condition)
	_check(lone.mode == StationModule.Mode.DESTROYED, "second wear did not destroy")
	_check(lone.condition <= 0.0, "destroyed module still has condition")

	var sim := StationSim.new()
	sim.setup()
	var research: StationModule = sim.modules["research"]
	research.set_mode(StationModule.Mode.STANDBY)
	research.power_demand = 8.0
	sim.clock.advance_n(1)
	var idle_req := float(sim.power.requests.get("research", -1.0))
	_check(idle_req > 0.0, "standby requested no power")
	_check(idle_req < research.power_demand, "standby draw %s is not below full %s" % [idle_req, research.power_demand])
	research.set_mode(StationModule.Mode.RUNNING)
	sim.clock.advance_n(1)
	var full_req := float(sim.power.requests.get("research", -1.0))
	_check(abs(full_req - research.power_demand) < 1e-6, "running draw %s" % full_req)

	var comms: StationModule = sim.modules["comms"]
	comms.set_mode(StationModule.Mode.RUNNING)
	comms.condition = 40.0
	comms.apply_wear(40.0)
	_check(comms.mode == StationModule.Mode.FAULTED, "comms did not fault")
	var scrap_before := sim.inventory.get_amount("scrap")
	var elec_before := sim.inventory.get_amount("electronics")
	_check(sim.try_repair_module("comms"), sim.last_action_reason)
	_check(comms.mode == StationModule.Mode.STANDBY, "repair left mode %s" % comms.mode)
	_check(comms.condition > StationModule.FAULT_CONDITION, "repair did not clear the fault line")
	_check(sim.inventory.get_amount("scrap") < scrap_before, "repair spent no scrap")
	_check(sim.inventory.get_amount("electronics") < elec_before, "repair spent no electronics")
	comms.condition = 0.0
	comms.set_mode(StationModule.Mode.DESTROYED, "condition zero")
	var scrap_dead := sim.inventory.get_amount("scrap")
	_check(not sim.try_repair_module("comms"), "destroyed module was repaired")
	_check(abs(sim.inventory.get_amount("scrap") - scrap_dead) < 1e-6, "destroyed repair spent scrap")
	_check(comms.mode == StationModule.Mode.DESTROYED, "destroyed mode changed")
	sim.free()


func _test_sub_mission_and_chain() -> void:
	var sim := StationSim.new()
	sim.setup()
	_check(sim.sub != null, "sub vessel missing")
	var ore0 := sim.inventory.get_amount("mixed_ore")
	sim.sub.nodes["shelf_ore"]["remaining"] = 0.0
	_check(not sim.sub_depart("shelf_ore"), "empty deposit launched")
	_check("empty" in sim.sub_fail_reason().to_lower(), sim.sub_fail_reason())
	_check(sim.sub_status()["phase"] == "DOCKED", "empty depart left phase %s" % sim.sub_status()["phase"])
	_check(abs(sim.inventory.get_amount("mixed_ore") - ore0) < 1e-6, "empty depart minted ore")

	sim.sub.nodes["shelf_ore"]["remaining"] = 10.0
	sim.sub.nodes["shelf_ore"]["depth_m"] = 40.0
	sim.sub.safe_depth_m = 30.0
	_check(not sim.sub_depart("shelf_ore"), "over-depth depart succeeded")
	_check("depth" in sim.sub_fail_reason().to_lower() or "hull" in sim.sub_fail_reason().to_lower(), sim.sub_fail_reason())

	sim.sub.safe_depth_m = 90.0
	sim.sub.battery_kwh = 0.01
	_check(not sim.sub_depart("shelf_ore"), "low battery depart succeeded")
	_check("battery" in sim.sub_fail_reason().to_lower(), sim.sub_fail_reason())
	_check(sim.sub.cargo_total() == 0.0, "failed depart collected cargo")

	sim.sub.hull = 0.0
	sim.sub.battery_kwh = sim.sub.battery_capacity_kwh
	_check(not sim.sub_depart("shelf_ore"), "destroyed hull departed")
	_check(sim.sub_status()["phase"] == "DISABLED", "hull failure phase %s" % sim.sub_status()["phase"])
	sim.sub.hull = 100.0
	sim.sub.phase = SubVessel.Phase.DOCKED

	sim.sub.cargo_capacity = 5.0
	sim.sub.nodes["shelf_ore"]["remaining"] = 10.0
	sim.sub.nodes["shelf_ore"]["rate"] = 2.0
	sim.sub.nodes["shelf_ore"]["depth_m"] = 10.0
	sim.sub.battery_kwh = sim.sub.battery_capacity_kwh
	var battery0: float = sim.sub.battery_kwh
	_check(sim.sub_depart("shelf_ore"), sim.sub_fail_reason())
	sim.clock.advance_n(1)
	_check(sim.sub_status()["phase"] == "MINE", "expected MINE after travel, got %s" % sim.sub_status()["phase"])
	_check(abs(float(sim.sub_status()["depth_m"]) - 10.0) < 1e-6, "depth %s" % sim.sub_status()["depth_m"])
	_check(sim.sub.cargo_total() == 0.0, "mined during the travel tick")
	_check(abs(sim.inventory.get_amount("mixed_ore") - ore0) < 1e-6, "ore reached the station during travel")
	sim.clock.advance_n(3)
	_check(abs(sim.sub.cargo_total() - 5.0) < 1e-6, "cargo %s" % sim.sub.cargo_total())
	_check(abs(float(sim.sub.nodes["shelf_ore"]["remaining"]) - 5.0) < 1e-6, "node remaining %s" % sim.sub.nodes["shelf_ore"]["remaining"])
	_check(sim.sub_status()["phase"] == "RETURN", "full cargo phase %s" % sim.sub_status()["phase"])
	_check(float(sim.sub_status()["battery_kwh"]) < battery0, "battery did not drain")
	_check(abs(sim.inventory.get_amount("mixed_ore") - ore0) < 1e-6, "ore entered station inventory before dock")
	var early := sim.unload_sub()
	_check(early.is_empty(), "unload while returning moved cargo")
	_check(abs(sim.sub.cargo_total() - 5.0) < 1e-6, "early unload changed cargo")
	sim.clock.advance_n(1)
	_check(sim.sub_status()["phase"] == "SURFACE", "surface phase %s depth %s" % [sim.sub_status()["phase"], sim.sub_status()["depth_m"]])
	_check(abs(float(sim.sub_status()["depth_m"])) < 1e-6, "depth not zero at surface")
	var moved: Dictionary = sim.unload_sub()
	_check(abs(float(moved.get("mixed_ore", 0.0)) - 5.0) < 1e-6, "unloaded %s" % moved)
	_check(abs(sim.inventory.get_amount("mixed_ore") - 5.0) < 1e-6, "station ore %s" % sim.inventory.get_amount("mixed_ore"))
	_check(sim.sub.cargo_total() == 0.0, "cargo remained aboard after unload")
	_check(sim.sub_status()["phase"] == "DOCKED", "phase after unload %s" % sim.sub_status()["phase"])

	sim.inventory.set_capacity("mixed_ore", 2.0)
	sim.inventory.stock["mixed_ore"] = 2.0
	sim.sub.cargo = {"mixed_ore": 4.0}
	sim.sub.phase = SubVessel.Phase.SURFACE
	var partial: Dictionary = sim.unload_sub()
	_check(abs(float(partial.get("mixed_ore", 0.0))) < 1e-6, "full bin accepted ore %s" % partial)
	_check(abs(sim.inventory.get_amount("mixed_ore") - 2.0) < 1e-6, "full bin stock changed")
	_check(abs(float(sim.sub.cargo.get("mixed_ore", 0.0)) - 4.0) < 1e-6, "rejected ore left the sub")
	sim.inventory.set_capacity("mixed_ore", 100.0)

	# Battery reserve stops mining and returns with the cargo already aboard.
	sim.sub.cargo = {}
	sim.sub.phase = SubVessel.Phase.DOCKED
	sim.sub.depth_m = 0.0
	sim.sub.cargo_capacity = 20.0
	sim.sub.nodes["shelf_ore"]["remaining"] = 20.0
	sim.sub.nodes["shelf_ore"]["depth_m"] = 10.0
	sim.sub.battery_kwh = sim.sub.battery_capacity_kwh
	_check(sim.sub_depart("shelf_ore"), sim.sub_fail_reason())
	sim.clock.advance_n(1)
	sim.sub.battery_kwh = SubVessel.RESERVE_KWH
	var held: float = sim.sub.cargo_total()
	sim.clock.advance_n(1)
	_check(sim.sub_status()["phase"] == "RETURN", "reserve did not return, phase %s" % sim.sub_status()["phase"])
	_check(abs(sim.sub.cargo_total() - held) < 1e-6, "mining continued on battery reserve")

	# Sub cargo feeds the refinery chain into metal stock. No second ledger.
	sim.inventory.stock["mixed_ore"] = 0.0
	sim.sub.phase = SubVessel.Phase.DOCKED
	sim.sub.depth_m = 0.0
	sim.sub.cargo = {}
	sim.sub.cargo_capacity = 16.0
	sim.sub.battery_kwh = sim.sub.battery_capacity_kwh
	sim.sub.nodes["shelf_ore"]["remaining"] = 16.0
	sim.sub.nodes["shelf_ore"]["rate"] = 4.0
	sim.sub.nodes["shelf_ore"]["depth_m"] = 10.0
	_check(sim.sub_depart("shelf_ore"), sim.sub_fail_reason())
	sim.clock.advance_n(6)
	_check(sim.sub.cargo_total() > 0.0, "sortie collected nothing")
	sim.sub_order_return()
	sim.clock.advance_n(4)
	_check(sim.sub_status()["phase"] == "SURFACE" or sim.sub_status()["phase"] == "DOCKED", sim.sub_status()["phase"])
	var delivered: Dictionary = sim.unload_sub()
	var delivered_ore := float(delivered.get("mixed_ore", 0.0))
	_check(delivered_ore > 0.0, "dock did not deliver ore")
	var ore_after_dock := sim.inventory.get_amount("mixed_ore")
	_check(abs(ore_after_dock - delivered_ore) < 1e-4, "dock delivery did not match station stock")
	sim.modules["processor"].set_mode(StationModule.Mode.OFF)
	sim.inventory.stock["bio_nutrient"] = 0.0
	sim.modules["refinery"].set_mode(StationModule.Mode.STANDBY)
	sim.clock.advance_n(12)
	_check(sim.inventory.get_amount("metal_stock") == 0.0, "refinery ran without bio_nutrient")
	_check(abs(sim.inventory.get_amount("mixed_ore") - ore_after_dock) < 1e-4, "ore consumed without the catalyst")
	sim.inventory.transfer_in("bio_nutrient", 6.0)
	sim.modules["refinery"].set_mode(StationModule.Mode.STANDBY)
	sim.modules["refinery"].active_recipe = {}
	sim.modules["refinery"].job_progress = 0.0
	sim.clock.advance_n(24)
	_check(sim.inventory.get_amount("metal_stock") >= 3.0, "metal stock %s" % sim.inventory.get_amount("metal_stock"))
	_check(sim.inventory.get_amount("mixed_ore") < ore_after_dock, "ore was not consumed")
	_check(sim.inventory.get_amount("bio_nutrient") < 6.0, "catalyst was not consumed")
	_check(sim.inventory.assert_sane(), "inventory insane after chain")
	sim.free()


func _test_pause_save_and_visual() -> void:
	var sim := StationSim.new()
	sim.setup()
	var bay := OilRigUnderdeckSystems.new()
	bay.bind_sim(sim)
	bay.hatch_state = OilRigUnderdeckSystems.HatchState.OPENING
	bay._hatch_progress = 0.2
	sim.clock.paused = true
	bay.advance_visual(0.5)
	_check(abs(bay._hatch_progress - 0.2) < 1e-6, "hatch moved while paused %s" % bay._hatch_progress)
	bay.sub_state = OilRigUnderdeckSystems.SubState.DEPLOYING
	bay._sub_progress = 0.3
	bay.advance_visual(0.5)
	_check(abs(bay._sub_progress - 0.3) < 1e-6, "sub moved while paused %s" % bay._sub_progress)
	_check(bay.sub_state == OilRigUnderdeckSystems.SubState.DEPLOYING, "sub state changed while paused")
	sim.clock.paused = false
	sim.clock.set_speed(1.0)
	bay.advance_visual(0.05)
	var hatch_slow: float = bay._hatch_progress
	_check(hatch_slow > 0.2, "hatch did not advance when running")
	sim.clock.set_speed(4.0)
	bay.advance_visual(0.05)
	var hatch_fast: float = bay._hatch_progress
	_check(hatch_fast - hatch_slow > (hatch_slow - 0.2) * 3.0, "4x did not speed the hatch")

	sim.clock.advance_n(4)
	sim.clock.paused = true
	sim.clock.set_speed(2.0)
	sim.clock.set_accum(0.35)
	var proc: StationModule = sim.modules["processor"]
	proc.set_mode(StationModule.Mode.RUNNING)
	proc.condition = 88.5
	proc.job_progress = 3.5
	proc.job_duration = 10.0
	proc.blocked_reason = "holding"
	proc.active_recipe = sim.recipes["biomass_to_nutrients"].duplicate(true)
	sim.sub.phase = SubVessel.Phase.MINE
	sim.sub.depth_m = 22.0
	sim.sub.battery_kwh = 3.1
	sim.sub.hull = 96.0
	sim.sub.target_id = "shelf_ore"
	sim.sub.cargo = {"mixed_ore": 4.0}
	sim.sub.nodes["shelf_ore"]["remaining"] = 11.0
	sim.inventory.stock["scrap"] = 123.0
	var blob: Dictionary = sim.export_state()
	var sim2 := StationSim.new()
	sim2.setup()
	sim2.clock.advance_n(2)
	sim2.inventory.stock["scrap"] = 1.0
	_check(not sim2.load_state("nope"), "malformed save accepted")
	_check(abs(sim2.inventory.get_amount("scrap") - 1.0) < 1e-6, "malformed save changed stock")
	_check(not sim2.load_state({"version": 99}), "future save accepted")
	_check(sim2.load_state(blob), sim2.last_action_reason)
	_check(sim2.clock.tick == sim.clock.tick, "tick %s vs %s" % [sim2.clock.tick, sim.clock.tick])
	_check(sim2.clock.paused == true, "pause not restored")
	_check(abs(sim2.clock.speed - 2.0) < 1e-6, "speed %s" % sim2.clock.speed)
	_check(abs(sim2.clock.accum_seconds() - 0.35) < 1e-6, "accum %s" % sim2.clock.accum_seconds())
	_check(abs(sim2.inventory.get_amount("scrap") - 123.0) < 1e-6, "scrap %s" % sim2.inventory.get_amount("scrap"))
	_check(abs(sim2.inventory.get_amount("fuel_oil") - sim.inventory.get_amount("fuel_oil")) < 1e-4, "fuel drift on load")
	var proc2: StationModule = sim2.modules["processor"]
	_check(proc2.mode == StationModule.Mode.RUNNING, "processor mode %s" % proc2.mode)
	_check(abs(proc2.condition - 88.5) < 1e-4, "condition %s" % proc2.condition)
	_check(abs(proc2.job_progress - 3.5) < 1e-4, "job progress %s" % proc2.job_progress)
	_check(str(proc2.active_recipe.get("id", "")) == "biomass_to_nutrients", "recipe not restored")
	_check(proc2.blocked_reason == "holding", proc2.blocked_reason)
	var st: Dictionary = sim2.sub_status()
	_check(st["phase"] == "MINE", st["phase"])
	_check(abs(float(st["depth_m"]) - 22.0) < 1e-6, "loaded depth")
	_check(abs(float(st["battery_kwh"]) - 3.1) < 1e-6, "loaded battery")
	_check(abs(float(st["hull"]) - 96.0) < 1e-6, "loaded hull")
	_check(abs(float(st["cargo"].get("mixed_ore", 0.0)) - 4.0) < 1e-6, "loaded cargo")
	_check(abs(float(sim2.sub.nodes["shelf_ore"]["remaining"]) - 11.0) < 1e-6, "deposit respawned on load")

	# Winch recovery unloads into the same inventory. Cargo does not duplicate.
	sim.sub.phase = SubVessel.Phase.RETURN
	sim.sub.depth_m = 12.0
	sim.sub.cargo = {"mixed_ore": 4.0}
	sim.inventory.stock["mixed_ore"] = 0.0
	sim.inventory.set_capacity("mixed_ore", 100.0)
	bay.sub_state = OilRigUnderdeckSystems.SubState.RECOVERING
	bay._sub_progress = 0.99
	bay.hatch_state = OilRigUnderdeckSystems.HatchState.OPEN
	sim.clock.paused = false
	sim.clock.set_speed(1.0)
	bay.advance_visual(1.0)
	_check(bay.sub_state == OilRigUnderdeckSystems.SubState.DOCKED, "recovery did not dock")
	_check(abs(sim.inventory.get_amount("mixed_ore") - 4.0) < 1e-4, "winch did not unload")
	_check(sim.sub.cargo_total() == 0.0, "cargo duplicated aboard")
	var reading_sim := StationSim.new()
	reading_sim.setup()
	reading_sim.clock.advance_n(2)
	var engine := EngineRoomStatus.new()
	engine.bind_sim(reading_sim)
	_check(engine.get_visual_status() == "RUNNING", "engine visual %s" % engine.get_visual_status())
	var status: Dictionary = bay.get_system_status()
	_check(not status.has("electricity"), "status grew an electricity ledger")
	_check(status.has("depth_m"), "status missing depth")
	_check(status.has("battery_kwh"), "status missing battery")
	_check(status.has("sub_cargo"), "status missing sub cargo")
	bay.free()
	engine.free()
	reading_sim.free()
	sim2.free()
	sim.free()


func _test_deep_shell() -> void:
	var main_text := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_check(main_text.contains("pixel_station.gd"), "main scene is not the pixel station")
	_check(not main_text.contains("oil_rig.tscn"), "main scene still instances the oil rig")
	var legacy_text := FileAccess.get_file_as_string("res://scenes/legacy_main.tscn")
	_check(legacy_text.contains("oil_rig.tscn"), "legacy scene lost the cutaway")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_check(main.get_node_or_null("PixelStation") != null, "pixel station node missing")
	_check(main.get_node_or_null("OilRig") == null, "oil rig instanced in the main scene")
	_check(main.get_node_or_null("HUD") is RoomHud, "hud is not the six-room panel")
	main.free()

	var sim := StationSim.new()
	sim.setup()
	sim.clock.advance_n(1)
	var rows: Array = sim.shell.bus_rows(sim)
	_check(rows.size() == 6, "room bus %s" % rows.size())
	var summed := float(sim.shell.other_load(sim)["granted"])
	for row in rows:
		summed += float(row["granted"])
	_check(abs(summed - sim.power.granted_total) < 1e-3, "room grants %s vs bus %s" % [summed, sim.power.granted_total])
	_check(sim.modules["exterior_lights"].mode == StationModule.Mode.OFF, "lights started on")
	_check(float(sim.power.requests.get("exterior_lights", 0.0)) == 0.0, "lights drew power while off")
	var spare := sim.power.available_kw()
	_check(spare > 5.0, "life support ate the spare bus %s" % spare)
	sim.set_exterior_lights(true)
	sim.clock.advance_n(1)
	_check(abs(float(sim.power.requests.get("exterior_lights", 0.0)) - ShellOps.LIGHTS_KW) < 1e-6, "lights request")
	_check(sim.modules["exterior_lights"].power_granted + 1e-6 >= ShellOps.LIGHTS_KW, "lights were not fed")

	var plain := StationSim.new()
	plain.setup()
	var boosted := StationSim.new()
	boosted.setup()
	plain.clock.advance_n(1)
	boosted.clock.advance_n(1)
	_arm_processor(plain)
	_arm_processor(boosted)
	_check(boosted.set_divert("processor", 4.0), boosted.last_action_reason)
	plain.clock.advance_n(1)
	boosted.clock.advance_n(1)
	var plain_job: float = plain.modules["processor"].job_progress
	var fast_job: float = boosted.modules["processor"].job_progress
	_check(fast_job > plain_job + 0.5, "divert did not speed work %s vs %s" % [fast_job, plain_job])
	_check(boosted.shell.divert_applied_kw > 3.0, "divert did not reserve kW %s" % boosted.shell.divert_applied_kw)
	_check(not boosted.set_divert("ai_core", 4.0), "divert accepted a non-craft target")

	var life := StationSim.new()
	life.setup()
	var air0: float = life.shell.life.air
	life.clock.advance_n(3)
	_check(life.shell.life.air + 1e-6 >= air0, "powered plant lost air")
	_check(life.shell.life.powered, "plant reported unpowered")
	life.modules["life_support"].set_mode(StationModule.Mode.OFF)
	var air1: float = life.shell.life.air
	var hull1: float = life.shell.life.hull
	life.clock.advance_n(4)
	_check(life.shell.life.air < air1 - 0.5, "air held with the plant off")
	_check(life.shell.life.hull < hull1, "station hull held with the plant off")
	_check(abs(life.shell.life.sea_pressure_bar() - LifeSupport.pressure_bar(ShellOps.STATION_DEPTH_M)) < 1e-6, "station sea pressure")

	var ping := StationSim.new()
	ping.setup()
	_check(not ping.ping_sub(), "ping succeeded before generation")
	ping.clock.advance_n(1)
	_check(ping.ping_sub(), ping.last_action_reason)
	_check(abs(float(ping.shell.last_ping["depth_pressure_bar"]) - LifeSupport.pressure_bar(0.0)) < 1e-6, "docked depth pressure")
	_check(abs(float(ping.shell.last_ping["equipment_pressure_bar"]) - ping.shell.life.sea_pressure_bar()) < 1e-6, "docked equipment pressure")
	_check(ping.sub_depart("shelf_biomass"), ping.sub_fail_reason())
	ping.clock.advance_n(1)
	_check(abs(ping.sub.depth_m - 10.0) < 1e-6, "travel depth %s" % ping.sub.depth_m)
	_check(ping.ping_sub(), ping.last_action_reason)
	_check(abs(float(ping.shell.last_ping["depth_pressure_bar"]) - LifeSupport.pressure_bar(10.0)) < 1e-6, "travel pressure")
	_check(abs(float(ping.shell.last_ping["equipment_pressure_bar"]) - LifeSupport.pressure_bar(10.0)) < 1e-6, "travel equipment pressure")
	_check(ping.power.reserved_kw + 1e-6 >= ShellOps.PING_KW, "ping did not reserve bus kW")

	var gear := StationSim.new()
	gear.setup()
	var cap0: float = gear.sub.battery_capacity_kwh
	var elec0: float = gear.inventory.get_amount("electronics")
	_check(gear.upgrade_gear("battery"), gear.last_action_reason)
	_check(int(gear.shell.gear_levels["battery"]) == 1, "battery level")
	_check(gear.sub.battery_capacity_kwh > cap0 + 0.5, "battery capacity")
	_check(gear.inventory.get_amount("electronics") < elec0, "gear spent no electronics")
	var cargo_cap: float = gear.sub.cargo_capacity
	_check(not gear.upgrade_gear("cargo"), "cargo rack crafted without metal_stock")
	_check(abs(gear.sub.cargo_capacity - cargo_cap) < 1e-6, "failed craft changed cargo capacity")
	gear.shell.life.hull = 70.0
	var scrap0: float = gear.inventory.get_amount("scrap")
	_check(gear.seal_station_hull(), gear.last_action_reason)
	_check(gear.shell.life.hull > 70.0, "seal did not restore hull")
	_check(gear.inventory.get_amount("scrap") < scrap0, "seal spent no scrap")
	gear.prioritize_room("processor")
	_check(gear.modules["processor"].priority == 0, "processor was not prioritized")
	_check(gear.modules["ai_core"].priority == 2, "prioritize left the core tied at tier 0")

	sim.free()
	plain.free()
	boosted.free()
	life.free()
	ping.free()
	gear.free()


func _arm_processor(sim: StationSim) -> void:
	var proc: StationModule = sim.modules["processor"]
	proc.active_recipe = sim.recipes["biomass_to_nutrients"].duplicate(true)
	proc.job_duration = 10.0
	proc.job_progress = 0.0
	proc.condition = 100.0
	proc.set_mode(StationModule.Mode.RUNNING, "")
