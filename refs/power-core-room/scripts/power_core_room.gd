extends Node2D
## Standalone zoomed-in reference room for Grok to integrate into the main station.
## Entire room is drawn from scene geometry; no background image, ocean, or HUD.
## Click the yellow service switch to toggle the generator. Press R to reset.
signal state_changed(generator_running: bool, power_kw: float, core_online: bool)

const C_BG := Color("#101820")
const C_WALL := Color("#35434b")
const C_WALL_HI := Color("#687780")
const C_FLOOR := Color("#222d33")
const C_STEEL := Color("#7c8c92")
const C_DARK := Color("#192329")
const C_YELLOW := Color("#e6b541")
const C_CYAN := Color("#55d9e8")
const C_GREEN := Color("#65d58b")
const C_RED := Color("#ef625c")

var generator_running := true
var core_online := true
var generated_kw := 18.0
var core_draw_kw := 4.0
var service_switch: Area2D

func _ready() -> void:
	_build_room()
	_emit_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		generator_running = true
		core_online = true
		_emit_state()
		queue_redraw()

func _draw() -> void:
	# Clean technical room schematic labels are part of this zoomed-in reference,
	# not a gameplay HUD.
	draw_string(ThemeDB.fallback_font, Vector2(34, 34), "R02 / R01  •  POWER + AI CORE MODULE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#f2f5f5"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 60), "CUTAWAY REFERENCE   |   FRONT WALL REMOVED   |   SCALE: 1 BAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a8b8bf"))
	draw_string(ThemeDB.fallback_font, Vector2(44, 95), "GENERATOR SET  G-01", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_YELLOW)
	draw_string(ThemeDB.fallback_font, Vector2(390, 95), "DISTRIBUTION / SWITCHGEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(760, 95), "AI CORE  C-01", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_CYAN)
	draw_string(ThemeDB.fallback_font, Vector2(46, 416), "FUEL LINE → GENERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e5a05a"))
	draw_string(ThemeDB.fallback_font, Vector2(390, 416), "18 kW RATED  •  BUS A", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#a8b8bf"))
	draw_string(ThemeDB.fallback_font, Vector2(760, 416), "4 kW DEMAND  •  CONTROLLED LOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#a8b8bf"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 526), "INTERLOCK: core load is powered only when generator is running.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#d8e0e3"))
	draw_string(ThemeDB.fallback_font, Vector2(35, 550), "CLICK THE YELLOW SWITCH TO TEST • R TO RESET • NO OCEAN / WATER / HUD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90a5ad"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 462), "GEN: %s" % ("RUNNING" if generator_running else "OFFLINE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_GREEN if generator_running else C_RED)
	draw_string(ThemeDB.fallback_font, Vector2(390, 462), "BUS: %s" % ("ENERGIZED" if generator_running else "DEAD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_GREEN if generator_running else C_RED)
	draw_string(ThemeDB.fallback_font, Vector2(760, 462), "CORE: %s" % ("ONLINE" if core_online else "OFFLINE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_GREEN if core_online else C_RED)

func _build_room() -> void:
	# Outer pressure hull and cut edge
	_poly("HullShadow", [Vector2(20,80),Vector2(1000,80),Vector2(1000,490),Vector2(20,490)], C_DARK, -10)
	_poly("BackBulkhead", [Vector2(28,86),Vector2(992,86),Vector2(992,108),Vector2(28,108)], C_WALL_HI, -8)
	_poly("LeftBulkhead", [Vector2(28,86),Vector2(52,108),Vector2(52,468),Vector2(28,490)], C_WALL, -7)
	_poly("RightBulkhead", [Vector2(968,108),Vector2(992,86),Vector2(992,490),Vector2(968,468)], C_WALL, -7)
	_poly("FloorDeck", [Vector2(28,468),Vector2(52,444),Vector2(968,444),Vector2(992,468),Vector2(992,490),Vector2(28,490)], C_FLOOR, -6)
	_poly("CutawayLip", [Vector2(28,490),Vector2(992,490),Vector2(982,502),Vector2(38,502)], C_STEEL, -5)
	# Floor grating
	for x in range(70, 955, 24):
		_line("Grate_%d" % x, Vector2(x,461), Vector2(x+8,449), Color("#3f5058"), 2.0, -4)
	# Structural posts and overhead cable tray
	for x in [70, 350, 630, 950]:
		_rect("Support_%d" % x, Rect2(x,110,10,330), C_WALL_HI, -3)
		_rect("SupportFoot_%d" % x, Rect2(x-5,430,20,16), C_STEEL, -2)
	_rect("CableTray", Rect2(72,118,866,12), Color("#202c33"), -1)
	for x in range(90, 930, 44):
		_rect("TrayRib_%d" % x, Rect2(x,118,4,12), C_STEEL, 0)
	# Generator assembly left
	_rect("GenSkid", Rect2(70,340,250,92), Color("#29363c"), 1)
	_rect("GenBody", Rect2(92,250,198,86), Color("#58676d"), 2)
	_rect("GenTop", Rect2(104,238,174,14), C_STEEL, 3)
	_rect("GenFace", Rect2(105,264,168,48), Color("#394950"), 4)
	for i in range(6):
		_rect("CoolingFin_%d" % i, Rect2(115+i*22,270,8,34), Color("#19272e"), 5)
	_rect("GenEndCap", Rect2(275,264,22,48), C_YELLOW if generator_running else C_RED, 6)
	# Alternator and exhaust
	_circle("Alternator", Vector2(126,350), 23, C_STEEL, 2)
	_circle("AlternatorHub", Vector2(126,350), 8, C_DARK, 3)
	_pipe([Vector2(250,250),Vector2(250,180),Vector2(220,180),Vector2(220,145)], Color("#7e8c91"), 10, 2)
	_pipe([Vector2(220,145),Vector2(220,135)], Color("#e5a05a"), 4, 3)
	# Fuel service line with valves
	_pipe([Vector2(52,390),Vector2(80,390),Vector2(80,326),Vector2(102,326)], Color("#c17a3d"), 7, 7)
	_circle("FuelValve", Vector2(80,370), 10, C_YELLOW, 8)
	_line("ValveStem", Vector2(73,363), Vector2(87,377), C_DARK, 3, 9)
	# Switchgear cabinet center
	_rect("SwitchSkid", Rect2(385,352,230,72), Color("#26353c"), 1)
	_rect("SwitchCabinet", Rect2(410,192,188,156), Color("#53636a"), 2)
	_rect("SwitchDoor", Rect2(420,202,168,136), Color("#26363e"), 3)
	for i in range(3):
		_rect("Breaker_%d" % i, Rect2(435+i*48,220,34,48), C_STEEL, 4)
		_rect("BreakerLever_%d" % i, Rect2(443+i*48,234,18,5), C_YELLOW if generator_running else C_RED, 5)
		_circle("BusLamp_%d" % i, Vector2(446+i*48,294), 5, C_GREEN if generator_running else C_RED, 5)
	_rect("SwitchDisplay", Rect2(435,310,128,18), Color("#10262c"), 5)
	# Visible cable bus from generator through switchgear to core
	_pipe([Vector2(296,286),Vector2(345,286),Vector2(345,165),Vector2(410,165),Vector2(410,220)], C_YELLOW, 7, 6)
	_pipe([Vector2(598,236),Vector2(680,236),Vector2(680,166),Vector2(750,166),Vector2(750,218)], C_CYAN, 7, 6)
	# AI core cabinet right
	_rect("CoreSkid", Rect2(700,350,245,74), Color("#29373e"), 1)
	_rect("CoreCabinet", Rect2(724,182,196,166), Color("#4d5d64"), 2)
	_rect("CoreInner", Rect2(738,196,168,138), Color("#14252d"), 3)
	_rect("CoreHeader", Rect2(738,196,168,20), Color("#273e47"), 4)
	for i in range(4):
		_rect("CoreRack_%d" % i, Rect2(748+i*38,226,28,88), Color("#344b54"), 4)
		for j in range(4):
			_circle("CoreLED_%d_%d" % (i,j), Vector2(755+i*38,236+j*18), 3, C_CYAN if core_online else C_RED, 5)
	_circle("CoreReactor", Vector2(824,286), 24, Color("#183d48"), 5)
	_circle("CoreGlow", Vector2(824,286), 13, C_CYAN if core_online else C_RED, 6)
	# Cooling loops (dry sealed equipment loop; no ocean or water depiction)
	_pipe([Vector2(718,205),Vector2(692,205),Vector2(692,326),Vector2(718,326)], C_STEEL, 5, 4)
	_pipe([Vector2(920,205),Vector2(944,205),Vector2(944,326),Vector2(920,326)], C_STEEL, 5, 4)
	# Status beacon and physical toggle area
	_rect("BeaconMount", Rect2(309,218,12,24), C_DARK, 6)
	_circle("StatusBeacon", Vector2(315,214), 8, C_GREEN if generator_running else C_RED, 7)
	service_switch = Area2D.new()
	service_switch.name = "GeneratorServiceSwitch"
	service_switch.position = Vector2(302,284)
	add_child(service_switch)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24
	shape.shape = circle
	service_switch.add_child(shape)
	service_switch.input_event.connect(_on_switch_input)
	# Physical switch drawn near generator
	_rect("ServiceSwitchPlate", Rect2(296,267,24,34), Color("#172329"), 8)
	_rect("ServiceSwitchToggle", Rect2(303,273,10,18), C_YELLOW if generator_running else C_RED, 9)
	# Tiny name plates fixed to equipment
	_plate_text("Plate_Generator", Rect2(90,222,170,16), "G-01 / GENERATOR")
	_plate_text("Plate_Switchgear", Rect2(420,174,164,16), "BUS A / SWITCHGEAR")
	_plate_text("Plate_Core", Rect2(742,164,158,16), "C-01 / AI PROCESSOR")
	queue_redraw()

func _on_switch_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		generator_running = not generator_running
		core_online = generator_running
		_emit_state()
		queue_redraw()
		get_viewport().set_input_as_handled()

func _emit_state() -> void:
	state_changed.emit(generator_running, generated_kw if generator_running else 0.0, core_online)

func _poly(n: String, pts: PackedVector2Array, color: Color, z: int) -> void:
	var p := Polygon2D.new()
	p.name=n; p.polygon=pts; p.color=color; p.z_index=z; add_child(p)

func _rect(n: String, r: Rect2, color: Color, z: int) -> void:
	var p := Polygon2D.new()
	p.name=n; p.polygon=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	p.color=color; p.z_index=z; add_child(p)

func _line(n: String, a: Vector2, b: Vector2, color: Color, width: float, z: int) -> void:
	var l := Line2D.new()
	l.name=n; l.points=PackedVector2Array([a,b]); l.default_color=color; l.width=width; l.z_index=z; add_child(l)

func _pipe(points: Array, color: Color, width: float, z: int) -> void:
	var l := Line2D.new()
	l.name="Pipe_%02d" % get_child_count(); l.points=PackedVector2Array(points); l.default_color=color; l.width=width; l.joint_mode=Line2D.LINE_JOINT_ROUND; l.begin_cap_mode=Line2D.LINE_CAP_ROUND; l.end_cap_mode=Line2D.LINE_CAP_ROUND; l.z_index=z; add_child(l)

func _circle(n: String, c: Vector2, radius: float, color: Color, z: int) -> void:
	var p := Polygon2D.new()
	p.name=n
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a),sin(a))*radius)
	p.polygon=pts; p.color=color; p.z_index=z; add_child(p)

func _plate_text(n: String, r: Rect2, label: String) -> void:
	_rect(n, r, Color("#18252b"), 8)
	var t := Label.new()
	t.name=n+"_Text"; t.position=r.position+Vector2(4,0); t.size=Vector2(r.size.x-8,r.size.y)
	t.text=label; t.add_theme_font_size_override("font_size",9); t.add_theme_color_override("font_color",Color("#dbe5e8")); t.z_index=9; add_child(t)
