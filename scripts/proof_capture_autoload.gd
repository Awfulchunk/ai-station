extends Node
## Sub-bay proofs: closed hatch, open deploy, and the denser cutaway rooms.

func run(main: Node) -> void:
	var out := ProjectSettings.globalize_path("res://proof-fixedcam")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1600, 720)
	for i in 30:
		await get_tree().process_frame

	main.hud.visible = false
	var cc = main.oil_rig.get_node_or_null("CutawayController")
	if cc and cc.has_method("set_cutaway"):
		cc.set_cutaway(true)
	var front: Node = main.oil_rig.get_node_or_null("FrontWall")
	for c in main.hotspots.get_children():
		if c.has_method("_on_exit"):
			c._on_exit()
		for ch in c.get_children():
			if ch is Label:
				ch.visible = false
			if ch is Polygon2D:
				ch.color = Color(0, 0, 0, 0)

	await get_tree().process_frame
	await get_tree().process_frame
	var under: Node = main.oil_rig.get_node_or_null("UnderdeckSystems")
	var sim_boot: StationSim = main.sim
	sim_boot.clock.advance_n(4)
	await get_tree().process_frame
	var closed_path := await _shot(get_viewport(), out, "14-subbay-closed.png")
	var closed_tail := _status_tail(main, front, under, false, false)
	var density_path := await _shot(get_viewport(), out, "15-density-rooms.png")
	var density_tail := _status_tail(main, front, under, false, false)

	var opened := false
	var launched := false
	if under and under.has_method("open_hatch"):
		opened = under.call("open_hatch")
	var waited := 0.0
	while waited < 4.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if under and under.has_method("get_system_status"):
			var st: Dictionary = under.call("get_system_status")
			if str(st.get("hatch_state", "")) == "OPEN":
				break
	if under and under.has_method("launch_sub"):
		launched = under.call("launch_sub")
	waited = 0.0
	while waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if under and under.has_method("get_system_status"):
			var st2: Dictionary = under.call("get_system_status")
			var sub_name := str(st2.get("sub_state", ""))
			if sub_name == "DEPLOYING" or sub_name == "AWAY":
				if sub_name == "DEPLOYING":
					await get_tree().create_timer(0.25).timeout
				break
	var deploy_path := await _shot(get_viewport(), out, "14-subbay-open-deploy.png")
	var sim0: StationSim = main.sim
	sim0.clock.advance_n(5)
	await get_tree().process_frame
	var engine_path := await _shot(get_viewport(), out, "16-engine-room.png")
	var deploy_tail := _status_tail(main, front, under, opened, launched)
	var engine_tail := _status_tail(main, front, under, opened, launched)
	_write_md5(out, "14-subbay-closed.png", closed_path, closed_tail)
	_write_md5(out, "14-subbay-open-deploy.png", deploy_path, deploy_tail)
	_write_md5(out, "15-density-rooms.png", density_path, density_tail)
	_write_md5(out, "16-engine-room.png", engine_path, engine_tail)
	print("PROOFS_COMPLETE_SUBBAY")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _status_tail(main: Node, front: Node, under: Node, opened: bool, launched: bool) -> String:
	var sim0: StationSim = main.sim
	var snap = sim0.snapshot()
	var ok = sim0.inventory.assert_sane()
	var hidden := true
	if front:
		hidden = not front.visible
	var status := {}
	if under and under.has_method("get_system_status"):
		status = under.call("get_system_status")
	var engine_status := ""
	var engine_mode := ""
	var requested: float = float(snap.get("power_requested", 0))
	var fuel: float = float(snap.get("fuel_oil", 0))
	var engine := main.oil_rig.find_child("EngineRoomStatus", true, false) as Node
	if engine and engine.has_method("get_engine_reading"):
		var reading: Dictionary = engine.call("get_engine_reading")
		engine_status = str(reading.get("status", ""))
		engine_mode = str(reading.get("mode", ""))
		requested = reading.get("power_requested", requested)
		fuel = reading.get("fuel_oil", fuel)
	return "front_wall_hidden=%s open_hatch=%s launch_sub=%s hatch=%s sub=%s tick=%s gen=%s req=%s fuel=%s engine=%s gen_mode=%s sanity=%s err=%s\n" % [
		hidden, opened, launched,
		status.get("hatch_state", ""), status.get("sub_state", ""),
		snap["tick"], snap["power_generated"], requested, fuel,
		engine_status, engine_mode, ok, status.get("last_error", ""),
	]


func _write_md5(out: String, shot: String, path: String, tail: String) -> void:
	var md5 := FileAccess.get_md5(path)
	var byte_size := FileAccess.get_file_as_bytes(path).size()
	var note := "file=%s md5=%s bytes=%s %s" % [shot, md5, byte_size, tail]
	var stem := shot.trim_suffix(".png")
	var f := FileAccess.open(out + "/" + stem + ".md5", FileAccess.WRITE)
	f.store_string(note)
	f.close()
	print("PROOF_MD5 ", note)

func _shot(vp: Viewport, out: String, name: String) -> String:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path := out + "/" + name
	if img == null:
		push_error("null image " + name)
		return path
	var err := img.save_png(path)
	print("PROOF_SAVED ", path, " ", img.get_width(), "x", img.get_height(), " err=", err)
	return path
