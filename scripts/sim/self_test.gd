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
	print("SELF_TEST_OK")
	quit()
