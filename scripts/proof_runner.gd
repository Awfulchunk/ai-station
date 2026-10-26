extends SceneTree
## Headless/xvfb proof capture. Usage:
##   godot --path . --script res://scripts/proof_runner.gd
## Or via main user arg: godot --path . -- --proof

const OUT := "/workspace/game/requests/ai-station/proof-fixedcam"
const SIZE := Vector2i(1600, 720)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Change to main scene
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await process_frame
	var main := root.get_child(root.get_child_count() - 1)
	# Give nodes time
	for i in 10:
		await process_frame

	var vp := root.get_viewport()
	DisplayServer.window_set_size(SIZE)

	# 01 plate
	await _shot(vp, "01-plate.png")

	# 02 hotspot inspect — select processor
	if main.has_method("_on_hotspot"):
		main._on_hotspot("processor")
	await process_frame
	await process_frame
	await _shot(vp, "02-hotspot-inspect.png")

	# 03 FX loops — already running; wait so animations advance
	for i in 30:
		await process_frame
	await _shot(vp, "03-fx-loops.png")

	# 04 sim running — advance many ticks at 4x
	if main.get("sim"):
		var sim: StationSim = main.sim
		sim.clock.set_speed(4.0)
		sim.clock.paused = false
		# Force 30 ticks immediately for deterministic proof
		sim.clock.advance_n(30)
		# Also let a few real frames pass for HUD refresh
		for i in 20:
			await process_frame
		if main.get("hud"):
			main.hud.show_module("processor")
			main.hud._refresh()
		await process_frame
		await _shot(vp, "04-sim-running.png")
		# Sanity check 100 ticks
		sim.clock.advance_n(100)
		var snap = sim.snapshot()
		var ok = sim.inventory.assert_sane() and float(snap["biomass"]) >= 0.0
		var report = "tick=%s gen=%s req=%s granted=%s biomass=%s nutrient=%s sanity=%s\n" % [
			snap["tick"], snap["power_generated"], snap["power_requested"],
			snap["power_granted"], snap["biomass"], snap["bio_nutrient"], ok
		]
		var f := FileAccess.open(OUT + "/sim-sanity.txt", FileAccess.WRITE)
		f.store_string(report)
		f.close()
		print("SANITY ", report)

	print("PROOFS DONE -> ", OUT)
	quit()

func _shot(vp: Viewport, name: String) -> void:
	await process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		push_error("null image for " + name)
		return
	# Viewport texture may be flipped in some backends
	img.flip_y()
	var path := OUT + "/" + name
	var err := img.save_png(path)
	print("saved ", path, " err=", err, " size=", img.get_width(), "x", img.get_height())
