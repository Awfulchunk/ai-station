extends Node2D
class_name DeepMain
## Playable shell. Six HUD rooms over a pixel sub-station.
## The 10-bay oil-rig cutaway boots only when legacy_cutaway is set or --legacy-cutaway is passed.

@export var legacy_cutaway: bool = false

@onready var camera: Camera2D = $Camera2D
@onready var station: PixelStation = $PixelStation
@onready var sim: StationSim = $StationSim
@onready var hud: RoomHud = $HUD


func skips_boot() -> bool:
	return legacy_cutaway or DeepMain.wants_legacy()


static func wants_legacy() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--legacy-cutaway") or args.has("legacy-cutaway"):
		return true
	return bool(ProjectSettings.get_setting("ai_station/legacy_cutaway", false))


func _ready() -> void:
	if skips_boot():
		get_tree().change_scene_to_file("res://scenes/legacy_main.tscn")
		return
	camera.enabled = true
	camera.make_current()
	camera.position = Vector2(800, 360)
	camera.zoom = Vector2.ONE
	hud.bind(sim)
	station.bind(sim)
	hud.speed_changed.connect(_on_speed)
	hud.pause_toggled.connect(_on_pause)
	print("Deep station shell ready. rooms=6 legacy_cutaway=false")
	var args := OS.get_cmdline_user_args()
	if args.has("--proof") or args.has("proof"):
		var cap = load("res://scripts/deep_proof.gd").new()
		add_child(cap)
		cap.run(self)


func _on_speed(speed: float) -> void:
	sim.clock.set_speed(speed)
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			hud.show_room("energy")
		elif event.keycode == KEY_F2:
			hud.show_room("control")
		elif event.keycode == KEY_F3:
			hud.show_room("storage")
		elif event.keycode == KEY_F4:
			hud.show_room("mechanics")
		elif event.keycode == KEY_F5:
			hud.show_room("life")
		elif event.keycode == KEY_F6:
			hud.show_room("sub_bay")
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
