extends Node2D
## Fixed-cam AI Station — REV02 PASS1 via Godot OilRig pack hierarchy.
## FrontWall hidden; Interior Polygon2D floors/bulkheads/rooms visible.
## NO schematic layers, NO labels, NO grid.

@onready var camera: Camera2D = $Camera2D
@onready var oil_rig: Node2D = $OilRig
@onready var station_root: Node2D = $StationRoot
@onready var plate: Sprite2D = $StationRoot/Plate
@onready var room_layers: Node2D = $StationRoot/RoomLayers
@onready var hotspots: Node2D = $StationRoot/Hotspots
@onready var fx_layer: Node2D = $StationRoot/FxLayer
@onready var hud: HudInspect = $HUD
@onready var sim: StationSim = $StationSim

const PLATE_SIZE := Vector2(1600, 720)

# Hotspots kept for sim (labels hidden). Coords match CUT zone A2–F3.
const HOTSPOTS := {
	"ai_core": {"rect": Rect2(800, 255, 233, 145), "label": "R01"},
	"generator": {"rect": Rect2(333, 255, 233, 145), "label": "R02"},
	"organic_intake": {"rect": Rect2(100, 255, 233, 290), "label": "R03"},
	"refinery": {"rect": Rect2(1033, 255, 233, 145), "label": "R04"},
	"dock": {"rect": Rect2(333, 400, 233, 145), "label": "R05"},
	"receiving": {"rect": Rect2(566, 400, 233, 145), "label": "R06"},
	"biology": {"rect": Rect2(800, 400, 233, 145), "label": "R07"},
	"storage": {"rect": Rect2(1266, 255, 233, 145), "label": "R08"},
	"waste": {"rect": Rect2(1266, 400, 233, 145), "label": "R09"},
	"walkways": {"rect": Rect2(566, 255, 233, 145), "label": "R10"},
	"processor": {"rect": Rect2(1033, 400, 233, 145), "label": "E3"},
	"comms": {"rect": Rect2(560, 90, 140, 90), "label": "C1"},
}

func _ready() -> void:
	station_root.visible = false
	room_layers.visible = false
	fx_layer.visible = false
	_setup_camera()
	_setup_hotspots_hidden()
	hud.bind_sim(sim)
	hud.visible = false
	hud.show_module("ai_core")
	hud.speed_changed.connect(_on_speed)
	hud.pause_toggled.connect(_on_pause)
	# Ensure cutaway on
	var cc = oil_rig.get_node_or_null("CutawayController")
	if cc and cc.has_method("set_cutaway"):
		cc.set_cutaway(true)
	var engine := oil_rig.find_child("EngineRoomStatus", true, false) as Node
	if engine and engine.has_method("bind_sim"):
		engine.bind_sim(sim)
	for node in oil_rig.find_children("RoomPowerReadout", "", true, false):
		if node.has_method("bind_sim"):
			node.bind_sim(sim)
	var under := oil_rig.find_child("UnderdeckSystems", true, false) as Node
	if under and under.has_method("bind_sim"):
		under.bind_sim(sim)
	print("AI Station coherent hull ready. plate=", PLATE_SIZE)
	if "--proof" in OS.get_cmdline_user_args() or "proof" in OS.get_cmdline_user_args():
		var cap = load("res://scripts/proof_capture_autoload.gd").new()
		add_child(cap)
		cap.run(self)

func _setup_camera() -> void:
	camera.enabled = true
	camera.make_current()
	camera.position = PLATE_SIZE * 0.5
	camera.zoom = Vector2.ONE
	camera.position_smoothing_enabled = false

func _setup_hotspots_hidden() -> void:
	# Keep click targets for sim; hide all overlay labels/highlights for PASS1 look.
	for child in hotspots.get_children():
		child.queue_free()
	# Reparent hotspots under OilRig so they sit over cutaway (still invisible labels)
	hotspots.get_parent().remove_child(hotspots)
	oil_rig.add_child(hotspots)
	hotspots.z_index = 20
	for id in HOTSPOTS.keys():
		var info: Dictionary = HOTSPOTS[id]
		var hs := ModuleHotspot.new()
		hs.name = "HS_%s" % id
		hotspots.add_child(hs)
		hs.setup(id, info["rect"], "")
		hs.hotspot_clicked.connect(_on_hotspot)
		for ch in hs.get_children():
			if ch is Label:
				ch.visible = false
			if ch is Polygon2D:
				ch.color = Color(0, 0, 0, 0)

func _on_hotspot(module_id: String) -> void:
	hud.show_module(module_id)
	print("inspect ", module_id)

func _on_speed(s: float) -> void:
	sim.clock.set_speed(s)
	hud._refresh()

func _on_pause() -> void:
	sim.clock.toggle_pause()
	hud._refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_pause"):
		_on_pause()
	elif event.is_action_pressed("speed_1"):
		_on_speed(1.0)
	elif event.is_action_pressed("speed_2"):
		_on_speed(2.0)
	elif event.is_action_pressed("speed_4"):
		_on_speed(4.0)
	# C key toggles cutaway for debug (not shown in PASS1 proof)
	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		var cc = oil_rig.get_node_or_null("CutawayController")
		if cc and cc.has_method("toggle_cutaway"):
			cc.toggle_cutaway()
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
