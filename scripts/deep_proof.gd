extends Node
## Shots of the pixel station with all six room tabs, then each room panel.

const ROOMS: Array[String] = ["energy", "control", "storage", "mechanics", "life", "sub_bay"]


func run(main: Node) -> void:
	var out := ProjectSettings.globalize_path("res://proof-deepsea")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1600, 720)
	for i in 20:
		await get_tree().process_frame
	var sim: StationSim = main.sim
	sim.set_exterior_lights(true)
	sim.clock.advance_n(4)
	await get_tree().process_frame
	var hud: RoomHud = main.hud
	for room_id in ROOMS:
		hud.show_room(room_id)
		if room_id == "sub_bay":
			if sim.sub_can_depart("shelf_ore"):
				sim.sub_depart("shelf_ore")
			sim.clock.advance_n(2)
			sim.ping_sub()
			await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := await _shot(get_viewport(), out, "room-%s.png" % room_id)
		_write_note(out, room_id, path, sim)
	print("PROOFS_COMPLETE_DEEPSEA")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _write_note(out: String, room_id: String, path: String, sim: StationSim) -> void:
	var snap := sim.snapshot()
	var md5 := FileAccess.get_md5(path)
	var bytes := FileAccess.get_file_as_bytes(path).size()
	var note := "file=room-%s.png md5=%s bytes=%s tick=%s gen=%s air=%s hull=%s sub=%s depth=%s\n" % [
		room_id, md5, bytes, snap["tick"], snap["power_generated"],
		snap["air"], snap["station_hull"], snap["sub_phase"], snap["sub_depth_m"],
	]
	var f := FileAccess.open(out + "/room-%s.md5" % room_id, FileAccess.WRITE)
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
