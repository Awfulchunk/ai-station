extends SceneTree
## godot --headless --path . --script res://scripts/sim/self_test.gd

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
