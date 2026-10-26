extends Node2D
class_name OilRigAllInOneIntegration
## ALL-IN-ONE INTEGRATION MODULE — Godot 4.x
## Attach this Node2D to the station scene as a child named "IntegratedRigLayer".
## Designed as a mix-in layer: it draws a readable cutaway interior + separated pontoons.
## No full-screen background, ocean, or HUD is drawn. The parent scene owns those.
## Coordinates are local to this node. Default canvas is 1600x700 to match the reference style.

@export var canvas_size := Vector2(1600, 700)
@export var draw_station_deck := true
@export var draw_cutaway_rooms := true
@export var draw_separated_pontoons := true
@export var draw_ai_core := true
@export var animate_lights := true
@export var animate_power_flow := true
@export var pontoon_count := 6
@export_range(0.08, 0.50, 0.01) var pontoon_width_ratio := 0.145
@export_range(0.05, 0.35, 0.01) var pontoon_height_ratio := 0.18
@export var pontoon_bottom_y := 660.0
@export var show_debug_labels := false

const SKY_BLUE := Color("438fca")
const STEEL_DARK := Color("222a2b")
const STEEL_MID := Color("59605a")
const STEEL_LIGHT := Color("8e927e")
const SAFETY_YELLOW := Color("e8b52b")
const WARNING_RED := Color("e14b37")
const ORANGE := Color("f56a12")
const ORANGE_DARK := Color("c74300")
const WATER_BLUE := Color("278bbd")
const CYAN := Color("4dd9e8")
const AI_BLUE := Color("0879f4")
const WHITE := Color("e9eee7")
const BLACK := Color("12191b")

var _phase := 0.0
var _power_on := true
var _selected_machine := "AI_CORE"
var _machine_status := {
	"GENERATOR": true,
	"POWER_BUS": true,
	"AI_CORE": true,
	"COOLING": true,
	"STORAGE": true,
}

func _ready() -> void:
	set_process(animate_lights or animate_power_flow)
	queue_redraw()

func _process(delta: float) -> void:
	_phase += delta
	if _phase > 1000.0:
		_phase = 0.0
	queue_redraw()

func set_power_enabled(enabled: bool) -> void:
	_power_on = enabled
	for key in _machine_status.keys():
		_machine_status[key] = enabled
	queue_redraw()

func toggle_power() -> void:
	set_power_enabled(not _power_on)

func set_machine_status(machine_id: String, enabled: bool) -> void:
	if _machine_status.has(machine_id):
		_machine_status[machine_id] = enabled
		if machine_id == "POWER_BUS" or machine_id == "GENERATOR":
			_power_on = enabled
	queue_redraw()

func get_machine_status(machine_id: String) -> bool:
	return bool(_machine_status.get(machine_id, false))

func _draw() -> void:
	var sx := canvas_size.x / 1600.0
	var sy := canvas_size.y / 700.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	# The sky/water are intentionally omitted; this module is designed to be composited
	# over the game's existing scene. The rig itself starts with its upper deck.
	if draw_station_deck:
		_draw_crane_and_masts()
		_draw_deck_and_frame()
	if draw_cutaway_rooms:
		_draw_interior_floor(0, 290, 1600, 118)
		_draw_interior_floor(1, 414, 1460, 104)
		_draw_upper_machinery()
		_draw_lower_machinery()
	if draw_ai_core:
		_draw_ai_core()
	if draw_separated_pontoons:
		_draw_pontoons()
	if show_debug_labels:
		_draw_debug_labels()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color, true)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(a, b, color, width, true)

func _poly(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)

func _circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius, color)

func _draw_crane_and_masts() -> void:
	# Simplified rig cranes and radio towers echo the existing pixel-clean silhouette.
	for side in [0, 1]:
		var base_x := 145.0 if side == 0 else 1450.0
		_rect(base_x - 13, 205, 28, 32, Color("9c6b10"))
		_rect(base_x - 5, 52, 12, 160, SAFETY_YELLOW)
		_rect(base_x - 22, 45, 42, 11, SAFETY_YELLOW)
		_rect(base_x - 5, 95, 18, 7, WARNING_RED)
		_rect(base_x - 5, 142, 18, 7, WARNING_RED)
		_line(Vector2(base_x + 4, 49), Vector2(base_x - 120, 45), SAFETY_YELLOW, 7)
		_line(Vector2(base_x - 120, 45), Vector2(base_x - 120, 125), BLACK, 2)
		_line(Vector2(base_x + 4, 49), Vector2(base_x + 4, 198), Color("f9d45a"), 2)
		_circle(Vector2(base_x + 4, 27), 5, WARNING_RED)
	for tx in [390.0, 1300.0]:
		_line(Vector2(tx, 20), Vector2(tx - 10, 235), STEEL_DARK, 5)
		_line(Vector2(tx + 12, 20), Vector2(tx + 20, 235), STEEL_DARK, 5)
		for yy in range(40, 225, 35):
			_line(Vector2(tx - 5, yy), Vector2(tx + 17, yy + 28), STEEL_DARK, 3)
			_line(Vector2(tx + 16, yy), Vector2(tx - 7, yy + 28), STEEL_DARK, 3)
			_rect(tx - 7, yy + 5, 24, 6, WARNING_RED)
		_circle(Vector2(tx + 4, 18), 4, WARNING_RED)
	# Satellite dish
	_circle(Vector2(510, 124), 38, Color("aeb9bf"))
	_circle(Vector2(510, 124), 29, Color("68747a"))
	_line(Vector2(510, 124), Vector2(526, 142), Color("d8dedc"), 5)
	_line(Vector2(526, 142), Vector2(526, 220), STEEL_DARK, 7)
	_line(Vector2(526, 220), Vector2(495, 243), STEEL_DARK, 4)
	_line(Vector2(526, 220), Vector2(555, 243), STEEL_DARK, 4)

func _draw_deck_and_frame() -> void:
	# The deck is a narrow structural band; open rooms are visible below it.
	_rect(58, 226, 1485, 48, STEEL_DARK)
	_rect(58, 226, 1485, 11, STEEL_MID)
	_rect(58, 258, 1485, 16, Color("343b37"))
	for xx in range(70, 1540, 42):
		_rect(float(xx), 231, 4, 6, SAFETY_YELLOW)
		_rect(float(xx + 16), 261, 5, 5, STEEL_LIGHT)
	# Front cutaway edge beams and posts
	for xx in [105.0, 345.0, 575.0, 805.0, 1035.0, 1265.0, 1490.0]:
		_rect(xx, 274, 13, 250, Color("555b50"))
		_rect(xx + 2, 274, 4, 250, Color("929582"))
		_rect(xx - 4, 274, 22, 7, SAFETY_YELLOW)
	# Room rear walls and separators
	_rect(106, 282, 1238, 102, Color("1c2426"))
	_rect(106, 408, 1350, 96, Color("1c2426"))
	for xx in [355.0, 590.0, 810.0, 1038.0, 1260.0]:
		_rect(xx, 282, 8, 102, STEEL_MID)
		_rect(xx, 408, 8, 96, STEEL_MID)
	# Exposed cross-sections / structural ribs
	for xx in range(80, 1530, 90):
		_rect(float(xx), 383, 50, 7, STEEL_MID)
		_rect(float(xx), 501, 50, 7, STEEL_MID)
	# Continuous floor grates and yellow edge stripe
	_rect(105, 383, 1350, 7, Color("111718"))
	_rect(105, 501, 1350, 7, Color("111718"))
	_rect(105, 390, 1350, 5, Color("62685c"))
	_rect(105, 508, 1350, 5, Color("62685c"))
	for xx in range(115, 1450, 17):
		_rect(float(xx), 384, 2, 5, Color("a2a58f"))
		_rect(float(xx), 502, 2, 5, Color("a2a58f"))
	# Upper-deck guardrails
	_line(Vector2(72, 216), Vector2(1530, 216), SAFETY_YELLOW, 3)
	_line(Vector2(72, 227), Vector2(1530, 227), Color("a77d22"), 2)
	for xx in range(75, 1530, 38):
		_line(Vector2(float(xx), 216), Vector2(float(xx), 230), SAFETY_YELLOW, 2)

func _draw_interior_floor(floor_index: int, y: float, width: float, height: float) -> void:
	# Room labels are deliberately not baked in; this is the reusable art layer.
	var x := 105.0 if floor_index == 0 else 135.0
	_rect(x, y + height - 13, width, 13, Color("151b1b"))
	_rect(x, y + height - 13, width, 3, STEEL_LIGHT)
	for xx in range(int(x + 4), int(x + width - 4), 16):
		_rect(float(xx), y + height - 10, 2, 5, Color("777d70"))
	for xx in range(int(x + 15), int(x + width - 5), 92):
		_rect(float(xx), y + 10, 3, height - 25, Color("383f3b"))
		_rect(float(xx - 3), y + 10, 9, 4, Color("73796c"))

func _draw_upper_machinery() -> void:
	# Left: generator / flywheel
	_rect(165, 306, 87, 57, Color("414744"))
	_rect(173, 300, 68, 7, Color("9ba092"))
	_circle(Vector2(214, 337), 18, Color("151b1d"))
	_circle(Vector2(214, 337), 12, Color("7c8887"))
	_circle(Vector2(214, 337), 4, Color("22292a"))
	for k in range(8):
		var a := TAU * float(k) / 8.0
		_line(Vector2(214, 337), Vector2(214, 337) + Vector2(cos(a), sin(a)) * 10.0, Color("b5bcb5"), 2)
	_rect(260, 303, 18, 64, Color("737e7e"))
	_rect(285, 302, 17, 65, Color("596b67"))
	_rect(264, 307, 9, 48, Color("a8b4b1"))
	_rect(289, 306, 8, 49, Color("819994"))
	# Center-left: switchgear cabinets
	_rect(366, 302, 55, 63, Color("4a514d"))
	_rect(371, 308, 45, 50, Color("202728"))
	for xx in [376.0, 387.0, 398.0, 409.0]:
		_rect(xx, 314, 7, 35, Color("657d77"))
		_rect(xx + 1, 318, 4, 25, Color("2c3c3b"))
	_rect(433, 301, 27, 64, Color("4c5553"))
	_rect(438, 309, 17, 48, Color("242a2b"))
	for yy in [314.0, 327.0, 340.0]:
		_rect(441, yy, 11, 3, CYAN if _power_on else Color("35494a"))
	# Mid room: pipe-fed workbench and panel
	_rect(610, 307, 160, 55, Color("202728"))
	_rect(618, 314, 144, 41, Color("303b3c"))
	for xx in range(630, 750, 24):
		_rect(float(xx), 322, 15, 3, Color("8b9383"))
	_rect(673, 363, 35, 5, SAFETY_YELLOW)
	_line(Vector2(630, 294), Vector2(740, 294), Color("3a9dbd"), 3)
	_line(Vector2(630, 294), Vector2(630, 313), Color("3a9dbd"), 3)
	_line(Vector2(740, 294), Vector2(740, 313), Color("3a9dbd"), 3)
	# Right: coolant pumps, tanks, storage rack
	_rect(1047, 322, 38, 43, Color("756b59"))
	_rect(1052, 315, 28, 9, Color("9a9079"))
	_rect(1090, 309, 24, 57, Color("7e7770"))
	_rect(1096, 314, 12, 44, Color("b6a58d"))
	_rect(1118, 311, 41, 55, Color("8d602f"))
	for xx in range(1124, 1156, 7):
		_rect(float(xx), 317, 3, 44, Color("c18a43"))
	_line(Vector2(1160, 343), Vector2(1196, 343), Color("c67c28"), 4)
	_circle(Vector2(1207, 343), 9, Color("4c5452"))
	_circle(Vector2(1207, 343), 4, Color("202626"))
	for row in range(3):
		for col in range(3):
			_rect(1280 + col * 25, 294 + row * 22, 20, 16, Color("6c5235"))
			_rect(1283 + col * 25, 297 + row * 22, 14, 10, Color("a17a49"))
	# Visible cable runs connect the equipment instead of floating decorations.
	var wire := CYAN if _power_on else Color("3a5257")
	_line(Vector2(235, 290), Vector2(401, 290), wire, 3)
	_line(Vector2(401, 290), Vector2(401, 302), wire, 3)
	_line(Vector2(460, 320), Vector2(535, 320), wire, 3)
	_line(Vector2(535, 320), Vector2(535, 290), wire, 3)
	_line(Vector2(535, 290), Vector2(632, 290), wire, 3)
	_line(Vector2(1028, 290), Vector2(1028, 322), Color("d68a36"), 3)
	_line(Vector2(1028, 290), Vector2(1118, 290), Color("d68a36"), 3)
	if animate_power_flow and _power_on:
		for i in range(5):
			var px := 242.0 + fmod(_phase * 55.0 + i * 34.0, 365.0)
			_circle(Vector2(px, 290), 3.2, Color("8ffaff"))

func _draw_lower_machinery() -> void:
	# Left: pipe bank and filter assembly
	_rect(140, 431, 25, 57, Color("798986"))
	_rect(145, 437, 15, 44, Color("c1c8bd"))
	for xx in [148.0, 154.0, 160.0]:
		_line(Vector2(xx, 437), Vector2(xx, 480), Color("5d7474"), 2)
	_line(Vector2(165, 459), Vector2(275, 459), Color("398fb2"), 5)
	_line(Vector2(275, 459), Vector2(275, 495), Color("398fb2"), 5)
	_circle(Vector2(214, 459), 8, SAFETY_YELLOW)
	_circle(Vector2(214, 459), 3, Color("3b4240"))
	# Center-left: bio-processing vat and articulated arm
	_rect(366, 426, 170, 64, Color("303735"))
	_poly(PackedVector2Array([Vector2(407, 454), Vector2(430, 444), Vector2(481, 444), Vector2(507, 454), Vector2(481, 466), Vector2(430, 466)]), Color("858044"))
	_line(Vector2(399, 438), Vector2(407, 454), SAFETY_YELLOW, 4)
	_line(Vector2(507, 454), Vector2(516, 431), SAFETY_YELLOW, 4)
	_circle(Vector2(399, 438), 4, Color("aab2a1"))
	_circle(Vector2(516, 431), 4, Color("aab2a1"))
	_rect(534, 432, 9, 56, Color("5d665b"))
	_rect(537, 438, 3, 43, Color("9ba18b"))
	# Mid: sealed sample tanks, clear windows, fill levels
	for i in range(3):
		var xx := 819.0 + float(i) * 52.0
		_rect(xx, 425, 45, 70, Color("7b8a83"))
		_rect(xx + 4, 430, 37, 60, Color("1e3031"))
		_rect(xx + 7, 454 + float((i * 7) % 15), 31, 30 - float((i * 7) % 15), [Color("2b9877"), Color("217e9d"), Color("6c8d2e")][i])
		_rect(xx + 6, 429, 34, 4, Color("c4d0c5"))
		_circle(Vector2(xx + 13, 475), 2, Color("d6e7b5"))
	# Right-middle: tall fluid reservoirs
	for i in range(4):
		var xx := 929.0 + float(i) * 44.0
		var col: Color = [Color("879a86"), Color("9d672c"), Color("718c49"), Color("687b88")][i]
		_rect(xx, 430, 27, 62, col)
		_rect(xx + 3, 434, 21, 53, Color(col.r * 0.68, col.g * 0.68, col.b * 0.68))
		_rect(xx - 2, 428, 31, 6, Color(col.r * 1.15, col.g * 1.15, col.b * 1.1))
		_rect(xx + 4, 437, 3, 42, Color(1, 1, 1, 0.22))
	# Right: tools, compressed gas cylinders and a compact rack
	_rect(1272, 429, 52, 61, Color("464b44"))
	_poly(PackedVector2Array([Vector2(1278, 435), Vector2(1317, 435), Vector2(1305, 455), Vector2(1288, 455)]), Color("777765"))
	_line(Vector2(1336, 451), Vector2(1368, 451), Color("777f7b"), 4)
	for xx in [1385.0, 1414.0]:
		_rect(xx, 446, 17, 44, Color("d2a42c"))
		_rect(xx + 2, 452, 13, 32, BLACK)
		for yy in [455.0, 464.0, 473.0, 482.0]:
			_rect(xx + 2, yy, 13, 3, SAFETY_YELLOW)
	# Utility lines and valve handles
	_line(Vector2(165, 418), Vector2(702, 418), Color("3999bc"), 3)
	_line(Vector2(702, 418), Vector2(702, 441), Color("3999bc"), 3)
	_line(Vector2(702, 418), Vector2(906, 418), Color("3999bc"), 3)
	_line(Vector2(1064, 407), Vector2(1064, 431), Color("d47a29"), 4)
	_line(Vector2(1064, 407), Vector2(1115, 407), Color("d47a29"), 4)
	_circle(Vector2(1064, 407), 6, SAFETY_YELLOW)
	_circle(Vector2(214, 459), 5, SAFETY_YELLOW)
	if animate_power_flow and _power_on:
		for i in range(4):
			var px := 178.0 + fmod(_phase * 48.0 + i * 57.0, 510.0)
			_circle(Vector2(px, 418), 2.5, CYAN)

func _draw_ai_core() -> void:
	# Raised central AI control housing, integrated with the deck structure.
	_rect(805, 189, 216, 106, Color("171f21"))
	_rect(817, 199, 192, 97, Color("293536"))
	_rect(826, 208, 174, 81, Color("111a1e"))
	_rect(830, 212, 166, 9, Color("3e4e4d"))
	for xx in range(831, 994, 23):
		_rect(float(xx), 214, 8, 4, CYAN if _power_on and (not animate_lights or int(_phase * 3.0 + xx) % 3 != 0) else Color("30494b"))
	# Roof and circular AI lens
	_poly(PackedVector2Array([Vector2(810, 190), Vector2(842, 154), Vector2(984, 154), Vector2(1018, 190)]), Color("b9c0bd"))
	_poly(PackedVector2Array([Vector2(835, 166), Vector2(851, 151), Vector2(975, 151), Vector2(992, 166)]), Color("e0e2d7"))
	_circle(Vector2(912, 126), 39, Color("d4d8d5"))
	_circle(Vector2(912, 126), 31, Color("1b2d4b"))
	_circle(Vector2(912, 126), 23, Color("064bb2" if _power_on else "283e50"))
	_circle(Vector2(912, 126), 15, Color("0b8af4" if _power_on else "42575d"))
	_rect(908, 106, 8, 40, Color("a7e7f7"))
	_rect(892, 122, 40, 8, Color("a7e7f7"))
	_circle(Vector2(912, 126), 6, Color("e1ffff" if _power_on else "61777b"))
	# side conduits and mounting feet
	_line(Vector2(838, 190), Vector2(838, 176), SAFETY_YELLOW, 4)
	_line(Vector2(985, 190), Vector2(985, 176), SAFETY_YELLOW, 4)
	_rect(805, 286, 216, 10, STEEL_MID)
	_rect(805, 286, 216, 3, SAFETY_YELLOW)

func _draw_pontoons() -> void:
	# KEY CHANGE: isolated orange buoyancy pods, not a continuous orange slab.
	# The dark keel/water gap remains visible between each pod.
	var count := maxi(3, pontoon_count)
	var usable_left := 34.0
	var usable_right := 1566.0
	var span := usable_right - usable_left
	var pod_w := minf(span / float(count) * pontoon_width_ratio * 6.9, span / float(count) * 0.80)
	var pod_h := canvas_size.y / 700.0 * 126.0 * (pontoon_height_ratio / 0.18)
	var top_y := pontoon_bottom_y - pod_h
	# Exposed steel keel above the buoyancy modules
	_rect(35, 526, 1530, 28, Color("343b3a"))
	_rect(35, 526, 1530, 6, Color("71796d"))
	_rect(35, 548, 1530, 7, Color("202829"))
	for xx in range(45, 1560, 42):
		_rect(float(xx), 532, 5, 13, Color("5b6257"))
	# Drop brackets are separated and align with the pods.
	for i in range(count):
		var center_x := usable_left + (float(i) + 0.5) * span / float(count)
		_rect(center_x - 11, 546, 22, maxf(8.0, top_y - 546.0), Color("343b39"))
		_rect(center_x - 5, 548, 5, maxf(8.0, top_y - 548.0), Color("727a6c"))
		# Orange pod profile with tapered ends and dark lower shadow.
		var x1 := center_x - pod_w * 0.5
		var x2 := center_x + pod_w * 0.5
		var pod := PackedVector2Array([
			Vector2(x1 + 7, top_y), Vector2(x2 - 7, top_y),
			Vector2(x2, top_y + pod_h * 0.20), Vector2(x2 - 7, top_y + pod_h * 0.77),
			Vector2(center_x + pod_w * 0.30, top_y + pod_h * 0.91),
			Vector2(center_x - pod_w * 0.30, top_y + pod_h * 0.91),
			Vector2(x1 + 7, top_y + pod_h * 0.77), Vector2(x1, top_y + pod_h * 0.20)
		])
		_poly(pod, ORANGE_DARK)
		_poly(PackedVector2Array([
			Vector2(x1 + 7, top_y), Vector2(x2 - 7, top_y),
			Vector2(x2 - 2, top_y + pod_h * 0.18), Vector2(x1 + 2, top_y + pod_h * 0.18)
		]), Color("ff7c1b"))
		_line(Vector2(x1 + 8, top_y + 17), Vector2(x2 - 8, top_y + 17), Color("ffb342"), 4)
		_line(Vector2(x1 + 8, top_y + pod_h * 0.45), Vector2(x2 - 8, top_y + pod_h * 0.45), Color("ef5b08"), 3)
		# Small service lights / access marks on each pod
		for light_i in range(3):
			_circle(Vector2(x1 + 14 + light_i * maxf(12.0, (pod_w - 28.0) / 2.0), top_y + 30), 2.1, Color("ffe09a"))
		# Individual pod side panel
		_line(Vector2(center_x, top_y + pod_h * 0.47), Vector2(center_x, top_y + pod_h * 0.78), Color("a63b00"), 2)
	# Thin exposed braces between pods make the gaps visually intentional.
	for i in range(count - 1):
		var x_a := usable_left + (float(i) + 1.0) * span / float(count) - 8.0
		_line(Vector2(x_a, 555), Vector2(x_a - 4, top_y + pod_h * 0.60), Color("243034"), 5)
		_line(Vector2(x_a + 8, 555), Vector2(x_a + 12, top_y + pod_h * 0.60), Color("243034"), 5)

func _draw_debug_labels() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	for item in [
		{"text":"GENERATOR", "pos":Vector2(165, 300)},
		{"text":"POWER BUS", "pos":Vector2(610, 300)},
		{"text":"AI CORE", "pos":Vector2(875, 180)},
		{"text":"FLUID / BIO PROCESSING", "pos":Vector2(365, 423)},
		{"text":"SEPARATED BUOYANCY PODS", "pos":Vector2(640, 645)},
	]:
		draw_string(font, item.pos, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e8e5c9"))

# Suggested integration:
# 1. Copy this file to res://scripts/OilRigAllInOneIntegration.gd
# 2. Add a Node2D child to the existing station scene and attach this script.
# 3. Set position to Vector2.ZERO and keep it behind the interactive HUD.
# 4. If your existing rig already draws the upper station, set draw_station_deck=false
#    and/or draw_cutaway_rooms=false to use only the separated-pontoon redesign.
# 5. For the cleanest use as an overlay on the existing station, set draw_station_deck=false,
#    draw_cutaway_rooms=false, draw_ai_core=false, and leave draw_separated_pontoons=true.
# 6. Call $IntegratedRigLayer.toggle_power() from an existing power button or simulation event.
# 7. For separate interactive equipment, keep the game's existing simulation nodes and map their
#    state changes into set_machine_status("GENERATOR", true/false), etc.
