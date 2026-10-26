extends RefCounted
class_name BayDressing
## Extra cutaway dressing: rear windows, cable runs, furniture, and a StationSim
## bus tap. Drawn with Polygon2D. No labels, no grid, no local resource ledger.
## Backdrop is added before each room kit so machines occlude it.
## Foreground is added before the bus tap so the meter capture can see LEDs.

const RoomPowerScript := preload("res://scripts/cutaway/room_power_readout.gd")

const MODULE := {
	"WaterIntakeRoom": "organic_intake",
	"ServiceCorridor": "walkways",
	"AICoreRoom": "ai_core",
	"RefineryRoom": "refinery",
	"StorageRoom": "storage",
	"OceanIntake": "organic_intake",
	"SubmarineBay": "dock",
	"ResourceSortingRoom": "receiving",
	"BiologyRoom": "biology",
	"ProductReserves": "processor",
	"RecyclingRoom": "waste",
}

const ACCENT := {
	"WaterIntakeRoom": Color(0.25, 0.55, 0.72),
	"PowerRoom": Color(0.85, 0.55, 0.18),
	"ServiceCorridor": Color(0.75, 0.62, 0.22),
	"AICoreRoom": Color(0.30, 0.75, 0.86),
	"RefineryRoom": Color(0.72, 0.42, 0.16),
	"StorageRoom": Color(0.55, 0.48, 0.32),
	"OceanIntake": Color(0.20, 0.58, 0.70),
	"SubmarineBay": Color(0.70, 0.62, 0.24),
	"ResourceSortingRoom": Color(0.62, 0.50, 0.22),
	"BiologyRoom": Color(0.30, 0.62, 0.42),
	"ProductReserves": Color(0.55, 0.40, 0.18),
	"RecyclingRoom": Color(0.48, 0.50, 0.36),
}

const WINDOW_SHIFT := {
	"WaterIntakeRoom": 0.0,
	"PowerRoom": 8.0,
	"ServiceCorridor": -6.0,
	"AICoreRoom": 5.0,
	"RefineryRoom": -4.0,
	"StorageRoom": 11.0,
	"OceanIntake": 3.0,
	"SubmarineBay": -8.0,
	"ResourceSortingRoom": 7.0,
	"BiologyRoom": -10.0,
	"ProductReserves": 2.0,
	"RecyclingRoom": 13.0,
}

const STEEL := Color(0.55, 0.58, 0.52)
const STEEL_DK := Color(0.22, 0.24, 0.25)
const INK := Color(0.06, 0.06, 0.07)


static func add_backdrop(host: Node2D, size: Vector2, room_name: String) -> void:
	var g := _group(host, "RearServices")
	var w := size.x
	var h := size.y
	var accent: Color = ACCENT.get(room_name, Color(0.45, 0.55, 0.58))
	var glass := Color(0.95, 0.78, 0.42)
	if room_name in ["AICoreRoom", "WaterIntakeRoom", "OceanIntake", "BiologyRoom"]:
		glass = Color(0.42, 0.74, 0.82)
	var rx := 10.0
	while rx < w - 8.0:
		_rect(g, rx, 6.0, 2.2, 2.2, Color(0.62, 0.64, 0.58))
		rx += 14.0
	_rect(g, 8.0, 10.0, w - 16.0, 5.0, Color(0.16, 0.18, 0.20))
	_rect(g, 8.0, 11.0, w - 16.0, 1.5, accent)
	_rect(g, 6.0, h - 16.0, w - 12.0, 3.4, INK)
	_rect(g, 6.0, h - 15.2, w - 12.0, 1.2, Color(0.78, 0.62, 0.18))
	_pipe_h(g, 6.0, h * 0.58, w - 12.0, 4.6, Color(0.22, 0.42, 0.50))
	var hanger := 16.0
	while hanger < w - 14.0:
		_rect(g, hanger, h * 0.58 - 5.0, 1.6, 5.0, STEEL_DK)
		hanger += 26.0
	var shift := float(WINDOW_SHIFT.get(room_name, 0.0))
	var vx := clampf(w * 0.15 + shift, 12.0, w - 24.0)
	_pipe_v(g, vx, 14.0, h * 0.58 - 16.0, 3.4, INK)
	_rect(g, vx, 14.0, 1.2, h * 0.58 - 16.0, Color(0.82, 0.66, 0.16))
	_pipe_v(g, vx + 5.0, 16.0, h * 0.40, 2.6, accent)
	_round_window(g, _ix(w * 0.22 + shift, 12.0, w), 34.0, glass)
	_round_window(g, _ix(w * 0.62 - shift * 0.35, 12.0, w), 42.0, glass)
	_slit_window(g, _ix(w * 0.42 + shift * 0.5, 20.0, w), 16.0, glass)


static func add_foreground(host: Node2D, size: Vector2, room_name: String) -> void:
	match room_name:
		"WaterIntakeRoom":
			_water_manifold(host, size)
		"PowerRoom":
			pass
		"ServiceCorridor":
			_speaker(host, size)
		"AICoreRoom":
			_core_furniture(host, size)
		"RefineryRoom":
			_sample_can(host, size)
		"StorageRoom":
			_center_stores(host, size)
		"OceanIntake":
			_grate_mesh(host, size)
		"SubmarineBay":
			_bay_tools(host, size)
		"ResourceSortingRoom":
			_sort_rail(host, size)
		"BiologyRoom":
			_lab_shelf(host, size)
		"ProductReserves":
			_tank_rail(host, size)
		"RecyclingRoom":
			_scrap_pile(host, size)
		_:
			push_warning("BayDressing: no foreground for %s" % room_name)


static func add_bus_tap(host: Node2D, size: Vector2, room_name: String) -> void:
	var module_id := str(MODULE.get(room_name, ""))
	if module_id == "":
		return
	var pos := _meter_pos(room_name, size)
	var g := _group(host, "BusTap")
	_ellipse(g, pos.x, pos.y, 7.2, 7.2, INK)
	_ellipse(g, pos.x, pos.y, 5.8, 5.8, Color(0.72, 0.78, 0.70))
	_rect(g, pos.x - 5.5, pos.y - 6.4, 1.6, 2.2, Color(0.75, 0.22, 0.16))
	_rect(g, pos.x + 3.6, pos.y - 5.6, 1.6, 2.2, Color(0.25, 0.62, 0.32))
	_needle(g, pos, 4.8)
	var span := Rect2(pos.x - 12.0, pos.y - 6.0, 4.0, 16.0)
	_rect(g, span.position.x - 1.0, span.position.y - 1.0, span.size.x + 2.0, span.size.y + 2.0, INK)
	var fill := Polygon2D.new()
	fill.name = "LoadFill"
	fill.antialiased = false
	fill.set_meta("span", span)
	g.add_child(fill)
	var lamp := _group(g, "LiveLamp")
	var ly := pos.y + 8.0
	_rect(lamp, pos.x - 4.0, ly + 4.0, 8.0, 2.0, STEEL_DK)
	var bulb := Polygon2D.new()
	bulb.name = "Bulb"
	bulb.antialiased = false
	bulb.color = Color(0.16, 0.15, 0.14)
	bulb.polygon = PackedVector2Array([
		Vector2(pos.x - 3.0, ly),
		Vector2(pos.x + 3.0, ly),
		Vector2(pos.x + 3.0, ly + 4.0),
		Vector2(pos.x - 3.0, ly + 4.0),
	])
	lamp.add_child(bulb)
	var readout = RoomPowerScript.new()
	readout.name = "RoomPowerReadout"
	readout.module_id = module_id
	host.add_child(readout)


static func _meter_pos(room_name: String, size: Vector2) -> Vector2:
	var w := size.x
	var pos := Vector2(w - 18.0, 28.0)
	match room_name:
		"WaterIntakeRoom":
			pos = Vector2(w * 0.50, 30.0)
		"ServiceCorridor":
			pos = Vector2(w - 20.0, 36.0)
		"AICoreRoom":
			pos = Vector2(w * 0.46, 48.0)
		"RefineryRoom":
			pos = Vector2(w * 0.60, 26.0)
		"StorageRoom":
			pos = Vector2(w * 0.52, 32.0)
		"OceanIntake":
			pos = Vector2(w * 0.66, 18.0)
		"SubmarineBay":
			pos = Vector2(w * 0.56, 16.0)
		"ResourceSortingRoom":
			pos = Vector2(40.0, 30.0)
		"BiologyRoom":
			pos = Vector2(w * 0.52, 14.0)
		"ProductReserves":
			pos = Vector2(w * 0.86, 28.0)
		"RecyclingRoom":
			pos = Vector2(76.0, 26.0)
		_:
			pos = Vector2(w - 18.0, 28.0)
	pos.x = clampf(pos.x, 18.0, w - 14.0)
	pos.y = clampf(pos.y, 16.0, size.y - 26.0)
	return pos


static func _water_manifold(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "HeaderManifold")
	var x := size.x * 0.16
	_pipe_h(g, x, 16.0, size.x * 0.30, 5.0, Color(0.22, 0.48, 0.62))
	_valve(g, x + 14.0, 18.0, 4.2)
	_valve(g, x + size.x * 0.18, 18.0, 4.2)
	_pipe_v(g, x + 6.0, 18.0, 12.0, 3.2, Color(0.22, 0.48, 0.62))


static func _speaker(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "BaySpeaker")
	var x := size.x - 86.0
	var y := 52.0
	_plate(g, x, y, 14.0, 16.0, Color(0.28, 0.30, 0.28))
	var yy := y + 3.0
	while yy < y + 13.0:
		_rect(g, x + 2.0, yy, 10.0, 1.2, INK)
		yy += 2.8
	var board := _group(host, "ToolBoard")
	_plate(board, 56.0, 20.0, 26.0, 28.0, Color(0.30, 0.33, 0.30))
	_rect(board, 60.0, 24.0, 2.0, 18.0, Color(0.72, 0.74, 0.70))
	_rect(board, 64.0, 28.0, 12.0, 2.0, Color(0.72, 0.74, 0.70))
	_rect(board, 74.0, 24.0, 2.0, 16.0, Color(0.55, 0.32, 0.16))
	_rect(board, 80.0, 30.0, 6.0, 2.0, Color(0.78, 0.62, 0.18))
	_rect(board, 62.0, 40.0, 16.0, 3.0, Color(0.20, 0.45, 0.52))


static func _core_furniture(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "CoreFurniture")
	var floor_y := size.y - 13.0
	var cx := size.x * 0.22
	_rect(g, cx, floor_y - 14.0, 3.0, 10.0, STEEL_DK)
	_rect(g, cx - 1.0, floor_y - 16.0, 12.0, 3.0, Color(0.30, 0.34, 0.38))
	_rect(g, cx + 1.0, floor_y - 10.0, 2.0, 8.0, STEEL_DK)
	_rect(g, cx + 7.0, floor_y - 10.0, 2.0, 8.0, STEEL_DK)
	var kx := size.x * 0.38
	for i in 5:
		_rect(g, kx + float(i) * 5.0, floor_y - 8.0, 3.0, 2.0, Color(0.78, 0.80, 0.74))
	var core := _group(host, "CoreColumn")
	var column_x := size.x * 0.34
	_rect(core, column_x, 12.0, 18.0, 36.0, Color(0.08, 0.16, 0.20))
	_rect(core, column_x + 3.0, 16.0, 12.0, 28.0, Color(0.22, 0.70, 0.84))
	_rect(core, column_x, 18.0, 18.0, 2.0, STEEL)
	_rect(core, column_x, 30.0, 18.0, 2.0, STEEL)
	_rect(core, column_x, 42.0, 18.0, 2.0, STEEL)
	_ellipse(core, column_x + 9.0, 28.0, 4.0, 4.0, Color(0.75, 0.95, 1.0))
	var leds := _group(host, "CoreLeds")
	for i in 4:
		var led := Polygon2D.new()
		led.name = "Led%d" % i
		led.antialiased = false
		led.color = Color(0.10, 0.12, 0.13)
		var ly := 30.0 + float(i) * 6.0
		led.polygon = PackedVector2Array([
			Vector2(14.0, ly), Vector2(20.0, ly), Vector2(20.0, ly + 3.0), Vector2(14.0, ly + 3.0),
		])
		leds.add_child(led)


static func _sample_can(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "SampleCan")
	var x := size.x * 0.685
	var floor_y := size.y - 14.0
	_vessel(g, x, floor_y - 24.0, 11.0, 20.0, Color(0.62, 0.40, 0.16))
	_rect(g, x + 3.0, floor_y - 30.0, 3.0, 8.0, Color(0.72, 0.40, 0.12))


static func _center_stores(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "CenterStores")
	var x := size.x * 0.46
	var floor_y := size.y - 14.0
	_rect(g, x, floor_y - 4.0, 28.0, 4.0, Color(0.42, 0.34, 0.20))
	_crate(g, x + 1.0, floor_y - 16.0, 14.0, 12.0, Color(0.50, 0.34, 0.16))
	_crate(g, x + 13.0, floor_y - 14.0, 13.0, 10.0, Color(0.32, 0.38, 0.30))
	_crate(g, x + 4.0, floor_y - 28.0, 12.0, 12.0, Color(0.58, 0.48, 0.20))
	var cab := size.x * 0.66
	_plate(g, cab, 8.0, 42.0, 36.0, Color(0.26, 0.30, 0.28))
	_rect(g, cab + 3.0, 16.0, 36.0, 2.0, STEEL_DK)
	_rect(g, cab + 3.0, 28.0, 36.0, 2.0, STEEL_DK)
	_crate(g, cab + 4.0, 18.0, 14.0, 8.0, Color(0.50, 0.34, 0.16))
	_crate(g, cab + 22.0, 18.0, 14.0, 8.0, Color(0.34, 0.40, 0.32))
	_crate(g, cab + 6.0, 31.0, 16.0, 8.0, Color(0.55, 0.46, 0.18))


static func _grate_mesh(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "GrateMesh")
	var y := 20.0
	while y < size.y - 22.0:
		_rect(g, 8.0, y, 24.0, 1.6, Color(0.48, 0.54, 0.52))
		y += 7.0
	var cx := size.x * 0.55
	var cy := size.y * 0.24
	_ellipse(g, cx, cy, 6.5, 6.5, Color(0.86, 0.42, 0.12))
	_ellipse(g, cx, cy, 2.4, 2.4, Color(0.28, 0.16, 0.08))
	var pump_x := size.x * 0.74
	var floor_y := size.y - 16.0
	_plate(g, pump_x, 20.0, 38.0, floor_y - 26.0, Color(0.24, 0.32, 0.34))
	_ellipse(g, pump_x + 14.0, 38.0, 10.0, 10.0, Color(0.38, 0.46, 0.48))
	_ellipse(g, pump_x + 14.0, 38.0, 4.0, 4.0, STEEL_DK)
	_pipe_v(g, pump_x + 28.0, 22.0, floor_y - 40.0, 5.0, Color(0.22, 0.48, 0.62))
	_rect(g, pump_x + 4.0, floor_y - 22.0, 26.0, 8.0, Color(0.16, 0.20, 0.22))


static func _bay_tools(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "BayTools")
	var floor_y := size.y - 16.0
	_plate(g, 6.0, floor_y - 16.0, 22.0, 14.0, Color(0.62, 0.28, 0.14))
	_rect(g, 8.0, floor_y - 14.0, 18.0, 2.0, Color(0.85, 0.72, 0.28))
	_rect(g, 14.0, floor_y - 20.0, 3.0, 6.0, STEEL)
	_ellipse(g, size.x * 0.30, 22.0, 7.0, 7.0, INK)
	_ellipse(g, size.x * 0.30, 22.0, 3.2, 3.2, Color(0.45, 0.48, 0.40))
	_rect(g, size.x * 0.30 - 1.0, 12.0, 2.0, 8.0, STEEL)
	_vessel(g, 30.0, floor_y - 28.0, 8.0, 16.0, Color(0.55, 0.58, 0.56))
	_rect(g, 16.0, 4.0, size.x - 36.0, 7.0, Color(0.74, 0.58, 0.16))
	_rect(g, 16.0, 11.0, size.x - 36.0, 2.0, STEEL_DK)
	var hoist := size.x * 0.46
	_rect(g, hoist, 12.0, 16.0, 10.0, Color(0.28, 0.30, 0.32))
	_rect(g, hoist + 7.0, 22.0, 2.0, 16.0, INK)
	_rect(g, hoist + 3.0, 36.0, 10.0, 3.0, STEEL)


static func _sort_rail(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "SortRail")
	var w := size.x
	_rect(g, 18.0, 5.0, w - 46.0, 7.0, Color(0.78, 0.62, 0.18))
	_rect(g, 18.0, 12.0, w - 46.0, 2.0, STEEL_DK)
	var cab := w * 0.68
	_plate(g, cab, 16.0, 36.0, 30.0, Color(0.30, 0.32, 0.28))
	for i in 3:
		_rect(g, cab + 3.0, 20.0 + float(i) * 8.0, 30.0, 5.0, Color(0.14, 0.15, 0.14))
	var hx := w * 0.28
	_rect(g, hx, 8.0, 12.0, 7.0, Color(0.30, 0.32, 0.34))
	_rect(g, hx + 5.0, 15.0, 2.0, 12.0, INK)
	_rect(g, hx + 1.0, 26.0, 10.0, 3.0, STEEL)
	var belt_y := size.y - 33.0
	_crate(g, w * 0.12, belt_y - 8.0, 12.0, 8.0, Color(0.36, 0.42, 0.34))
	_crate(g, w * 0.60, belt_y - 9.0, 11.0, 8.0, Color(0.50, 0.34, 0.18))
	var sx := w * 0.64
	_poly(g, PackedVector2Array([
		Vector2(sx, belt_y - 18.0),
		Vector2(sx + 22.0, belt_y - 18.0),
		Vector2(sx + 30.0, belt_y - 2.0),
		Vector2(sx + 6.0, belt_y - 2.0),
	]), Color(0.34, 0.36, 0.38))


static func _lab_shelf(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "LabShelf")
	var x := 16.0
	_rect(g, x, 14.0, 72.0, 3.0, STEEL)
	_rect(g, x, 2.0, 2.0, 15.0, STEEL_DK)
	_rect(g, x + 70.0, 2.0, 2.0, 15.0, STEEL_DK)
	var colors: Array[Color] = [
		Color(0.30, 0.62, 0.40), Color(0.20, 0.48, 0.64), Color(0.72, 0.40, 0.18),
		Color(0.58, 0.30, 0.48), Color(0.78, 0.72, 0.36),
	]
	for i in colors.size():
		_rect(g, x + 6.0 + float(i) * 12.0, 4.0, 6.0, 10.0, colors[i])
		_rect(g, x + 7.0 + float(i) * 12.0, 2.0, 4.0, 3.0, Color(0.80, 0.82, 0.78))
	var floor_y := size.y - 14.0
	var sx := size.x * 0.50
	_rect(g, sx, floor_y - 12.0, 12.0, 3.0, Color(0.34, 0.38, 0.36))
	_rect(g, sx + 1.0, floor_y - 9.0, 2.0, 8.0, STEEL_DK)
	_rect(g, sx + 8.0, floor_y - 9.0, 2.0, 8.0, STEEL_DK)


static func _tank_rail(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "TankCatwalk")
	var y := size.y * 0.34
	var x0 := 8.0
	var x1 := size.x - 24.0
	_rect(g, x0, y, x1 - x0, 3.0, Color(0.82, 0.66, 0.20))
	_rect(g, x0, y + 3.0, x1 - x0, 1.6, STEEL_DK)
	var x := x0
	while x < x1:
		_rect(g, x, y + 3.0, 2.0, 10.0, Color(0.40, 0.42, 0.40))
		x += 20.0


static func _scrap_pile(host: Node2D, size: Vector2) -> void:
	var g := _group(host, "ScrapPile")
	var x := size.x * 0.30
	var y := size.y - 30.0
	_poly(g, PackedVector2Array([
		Vector2(x, y + 10.0), Vector2(x + 16.0, y + 4.0),
		Vector2(x + 14.0, y + 14.0), Vector2(x + 2.0, y + 14.0),
	]), Color(0.46, 0.48, 0.42))
	_poly(g, PackedVector2Array([
		Vector2(x + 10.0, y + 6.0), Vector2(x + 26.0, y + 2.0),
		Vector2(x + 24.0, y + 12.0), Vector2(x + 12.0, y + 14.0),
	]), Color(0.66, 0.50, 0.20))
	_poly(g, PackedVector2Array([
		Vector2(x + 18.0, y + 8.0), Vector2(x + 32.0, y + 7.0),
		Vector2(x + 28.0, y + 16.0), Vector2(x + 16.0, y + 14.0),
	]), Color(0.30, 0.32, 0.34))
	var hood := size.x * 0.50
	_plate(g, hood, 6.0, 44.0, 28.0, Color(0.32, 0.30, 0.26))
	_rect(g, hood + 4.0, 10.0, 36.0, 4.0, Color(0.16, 0.16, 0.14))
	_rect(g, hood + 6.0, 16.0, 10.0, 12.0, Color(0.20, 0.46, 0.36))
	_rect(g, hood + 20.0, 16.0, 10.0, 12.0, Color(0.70, 0.42, 0.16))
	_pipe_v(g, hood + 36.0, 8.0, 28.0, 4.0, STEEL)


static func _round_window(parent: Node2D, cx: float, cy: float, glass: Color) -> void:
	_ellipse(parent, cx, cy, 11.0, 11.0, STEEL)
	_ellipse(parent, cx, cy, 8.0, 8.0, glass)
	_ellipse(parent, cx - 2.4, cy - 2.6, 2.4, 1.6, Color(1, 1, 1, 0.45))
	_rect(parent, cx - 8.0, cy - 0.8, 16.0, 1.6, STEEL_DK)
	_rect(parent, cx - 0.8, cy - 8.0, 1.6, 16.0, STEEL_DK)
	_ellipse(parent, cx - 7.0, cy - 7.0, 1.4, 1.4, Color(0.85, 0.82, 0.70))
	_ellipse(parent, cx + 7.0, cy - 7.0, 1.4, 1.4, Color(0.85, 0.82, 0.70))
	_ellipse(parent, cx - 7.0, cy + 7.0, 1.4, 1.4, Color(0.85, 0.82, 0.70))
	_ellipse(parent, cx + 7.0, cy + 7.0, 1.4, 1.4, Color(0.85, 0.82, 0.70))


static func _slit_window(parent: Node2D, cx: float, cy: float, glass: Color) -> void:
	_rect(parent, cx - 16.0, cy - 6.0, 32.0, 14.0, STEEL)
	_rect(parent, cx - 14.0, cy - 4.0, 13.0, 10.0, glass)
	_rect(parent, cx + 1.0, cy - 4.0, 13.0, 10.0, glass)
	_rect(parent, cx - 1.0, cy - 6.0, 2.0, 14.0, STEEL_DK)
	_rect(parent, cx - 12.0, cy - 3.0, 5.0, 1.4, Color(1, 1, 1, 0.40))
	_rect(parent, cx + 3.0, cy - 3.0, 5.0, 1.4, Color(1, 1, 1, 0.40))


static func _ix(x: float, margin: float, w: float) -> float:
	return clampf(x, margin, w - margin)


static func _needle(parent: Node2D, pivot: Vector2, length: float) -> void:
	var needle := Polygon2D.new()
	needle.name = "NeedleLoad"
	needle.antialiased = false
	needle.color = Color(0.08, 0.08, 0.09)
	var tip := pivot + Vector2(0.0, -length)
	needle.polygon = PackedVector2Array([
		pivot + Vector2(-0.7, 0.0), tip, pivot + Vector2(0.7, 0.0),
	])
	parent.add_child(needle)


static func _group(parent: Node2D, group_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = group_name
	parent.add_child(n)
	return n


static func _poly(parent: Node2D, pts: PackedVector2Array, color: Color) -> void:
	if parent == null or pts.size() < 3:
		return
	var p := Polygon2D.new()
	p.name = "p%d" % parent.get_child_count()
	p.antialiased = false
	p.color = color
	p.polygon = pts
	parent.add_child(p)


static func _rect(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	if w < 0.4 or h < 0.4:
		return
	_poly(parent, PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
	]), color)


static func _ellipse(parent: Node2D, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	if rx < 0.6 or ry < 0.6:
		return
	var steps := 10
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * float(i) / float(steps)
		pts.append(Vector2(cx + cos(t) * rx, cy + sin(t) * ry))
	_poly(parent, pts, color)


static func _pipe_h(parent: Node2D, x: float, y: float, length: float, thick: float, color: Color) -> void:
	if length < 1.0:
		return
	_rect(parent, x, y + 1.0, length, thick, Color(0, 0, 0, 0.25))
	_rect(parent, x, y, length, thick, color)
	_rect(parent, x, y, length, maxf(1.0, thick * 0.28), Color(color.r + 0.18, color.g + 0.18, color.b + 0.16, color.a))


static func _pipe_v(parent: Node2D, x: float, y: float, length: float, thick: float, color: Color) -> void:
	if length < 1.0:
		return
	_rect(parent, x + 1.0, y, thick, length, Color(0, 0, 0, 0.25))
	_rect(parent, x, y, thick, length, color)
	_rect(parent, x, y, maxf(1.0, thick * 0.28), length, Color(color.r + 0.16, color.g + 0.16, color.b + 0.14, color.a))


static func _plate(parent: Node2D, x: float, y: float, w: float, h: float, fill: Color) -> void:
	_rect(parent, x - 1.0, y - 1.0, w + 2.0, h + 2.0, INK)
	_rect(parent, x, y, w, h, fill)
	_rect(parent, x, y, w, maxf(1.0, h * 0.16), Color(fill.r + 0.14, fill.g + 0.14, fill.b + 0.12, fill.a))


static func _valve(parent: Node2D, cx: float, cy: float, r: float) -> void:
	_ellipse(parent, cx, cy, r, r, Color(0.78, 0.62, 0.16))
	_ellipse(parent, cx, cy, r * 0.4, r * 0.4, Color(0.28, 0.22, 0.12))
	_rect(parent, cx - r * 1.3, cy - 1.2, r * 2.6, 2.4, STEEL)


static func _crate(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	_plate(parent, x, y, w, h, color)
	_rect(parent, x + 2.0, y + h * 0.45, maxf(1.0, w - 4.0), 1.2, Color(color.r - 0.14, color.g - 0.14, color.b - 0.12, color.a))


static func _vessel(parent: Node2D, x: float, y: float, w: float, h: float, body: Color) -> void:
	if h < 8.0 or w < 6.0:
		return
	var rx := w * 0.5
	_rect(parent, x, y, w, h, body)
	_rect(parent, x + w * 0.65, y, w * 0.35, h, Color(body.r - 0.10, body.g - 0.10, body.b - 0.08, body.a))
	_ellipse(parent, x + rx, y, rx, maxf(2.0, w * 0.16), Color(body.r + 0.08, body.g + 0.08, body.b + 0.06, body.a))
	_ellipse(parent, x + rx, y + h, rx, maxf(2.0, w * 0.14), Color(body.r - 0.08, body.g - 0.08, body.b - 0.06, body.a))
