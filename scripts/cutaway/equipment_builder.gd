extends RefCounted
class_name EquipmentBuilder
## PASS2 — visual industrial equipment for the cutaway bays.
## Polygon2D / Node2D only. No gameplay, no HUD labels, no grid.
## Fractions below are layout keys shared with the infrastructure routes.
## CUT / door numbers must stay in sync with interior_builder.gd.

const CUT_POS := Vector2(120, 268)
const CUT_SIZE := Vector2(1360, 262)
const COLS := 6

const PWR_B := 0.30
const PWR_D := 0.18
const PWR_E := 0.22
const H2O_A := 0.14
const FUEL_E := 0.10

const EngineStatusScript := preload("res://scripts/cutaway/engine_room_status.gd")
const BayDress := preload("res://scripts/cutaway/bay_dressing.gd")

const STEEL := Color(0.46, 0.48, 0.46)
const STEEL_DK := Color(0.22, 0.24, 0.25)
const STEEL_LT := Color(0.70, 0.72, 0.66)
const YELLOW := Color(0.86, 0.64, 0.14)
const WATER := Color(0.22, 0.48, 0.62)
const FUEL := Color(0.72, 0.40, 0.12)
const CYAN := Color(0.35, 0.82, 0.86)
const BIO := Color(0.28, 0.62, 0.40)
const CRUDE := Color(0.18, 0.14, 0.10)
const INK := Color(0.05, 0.05, 0.06)
const SHADOW := Color(0.02, 0.02, 0.03, 0.45)

static func build(interior: Node2D) -> void:
	var rooms := interior.get_node_or_null("Rooms") as Node2D
	var machinery := interior.get_node_or_null("Machinery") as Node2D
	var rig := interior.get_parent()
	var infra: Node2D = null
	if rig != null:
		infra = rig.get_node_or_null("Infrastructure") as Node2D
	if rooms == null:
		push_error("EquipmentBuilder: Interior/Rooms missing")
		return
	for room in rooms.get_children():
		var sz: Variant = room.get("room_size")
		if sz == null:
			continue
		var old := room.get_node_or_null("Equipment")
		if old:
			old.free()
		var host := Node2D.new()
		host.name = "Equipment"
		room.add_child(host)
		_equip_room(host, str(room.name), sz as Vector2)
	if infra != null:
		_routes(infra, rooms)
	_lower_works(interior)
	if machinery != null:
		_bilge_pump(machinery)
	var polys := _count_polys(interior)
	if infra != null:
		polys += _count_polys(infra)
	print("EquipmentBuilder PASS2 visual geometry polygons=", polys)


static func add_hatch_leaf(parent: Node2D, id: String, x: float, door_top: float, door_bot: float, thick: float, swing_left: bool) -> void:
	var opening_h := door_bot - door_top
	if opening_h < 28.0:
		return
	var leaf_h := minf(opening_h - 10.0, 46.0)
	var leaf_w := 8.0
	var y := door_bot - leaf_h - 3.0
	var px := x - leaf_w - 1.0
	if not swing_left:
		px = x + thick + 1.0
	var g := _group(parent, "HatchLeaf_%s" % id)
	_plate(g, px, y, leaf_w, leaf_h, Color(0.40, 0.42, 0.38))
	_rect(g, px, y + 4.0, leaf_w, 3.0, YELLOW)
	_rect(g, px + 2.0, y + 14.0, leaf_w - 4.0, leaf_h - 22.0, Color(0.08, 0.10, 0.12))
	var hx := x
	if not swing_left:
		hx = x + thick - 3.0
	_rect(g, hx, door_top + 6.0, 3.0, 5.0, STEEL_LT)
	_rect(g, hx, door_bot - 12.0, 3.0, 5.0, STEEL_LT)


static func _equip_room(host: Node2D, room_name: String, size: Vector2) -> void:
	_grate(host, size)
	BayDress.add_backdrop(host, size, room_name)
	match room_name:
		"WaterIntakeRoom":
			_water_intake(host, size)
		"PowerRoom":
			_power_room(host, size)
		"ServiceCorridor":
			_corridor(host, size)
		"AICoreRoom":
			_ai_core(host, size)
		"RefineryRoom":
			_refinery(host, size)
		"StorageRoom":
			_storage(host, size)
		"OceanIntake":
			_ocean_intake(host, size)
		"SubmarineBay":
			_sub_bay(host, size)
		"ResourceSortingRoom":
			_sorting(host, size)
		"BiologyRoom":
			_biology(host, size)
		"ProductReserves":
			_reserves(host, size)
		"RecyclingRoom":
			_recycling(host, size)
		_:
			push_warning("EquipmentBuilder: no kit for %s" % room_name)
	# The power bay has its own engine kit. The shared pass would cover the turbine.
	# Foreground props land before the bus tap so the meter can bind LEDs and glass.
	BayDress.add_foreground(host, size, room_name)
	if room_name != "PowerRoom":
		_density_pass(host, size)
		BayDress.add_bus_tap(host, size, room_name)


static func _density_pass(host: Node2D, size: Vector2) -> void:
	# Extra service geometry on every bay. No numeric labels — those would
	# disagree with StationSim if they were painted as fixed readouts.
	var w := size.x
	var h := size.y
	var g := _group(host, "ServiceDensity")
	_pipe_h(g, 6.0, 2.0, w - 14.0, 3.0, Color(0.22, 0.50, 0.58))
	var clamp_x := 10.0
	while clamp_x < w - 16.0:
		_rect(g, clamp_x, 0.5, 2.0, 6.0, STEEL)
		clamp_x += 22.0
	_pipe_v(g, w - 7.0, 8.0, h - 22.0, 3.2, Color(0.72, 0.48, 0.16))
	_rect(g, 4.0, h - 7.0, w * 0.42, 2.4, Color(0.55, 0.32, 0.12))
	_rect(g, w * 0.46, h - 7.0, w * 0.28, 2.2, CYAN)
	# Left service manifold. The live meter is BayDressing's bus tap, not a painted face.
	_pipe_v(g, 4.0, 8.0, h - 18.0, 3.0, Color(0.28, 0.30, 0.32))
	_pipe_h(g, 4.0, h * 0.55, w * 0.34, 3.2, Color(0.18, 0.36, 0.42))
	_valve(g, w * 0.18, h * 0.55 + 2.0, 4.0)
	_flange(g, w * 0.30, h * 0.55 - 2.0, 6.0, 8.0, STEEL)
	var box := _group(g, "Breaker")
	_plate(box, 8.0, 18.0, 16.0, 28.0, Color(0.22, 0.24, 0.26))
	_rect(box, 11.0, 22.0, 3.0, 8.0, Color(0.72, 0.55, 0.16))
	_rect(box, 16.0, 22.0, 3.0, 8.0, Color(0.20, 0.62, 0.38))
	_rect(box, 11.0, 34.0, 8.0, 2.0, STEEL_LT)
	_ellipse(box, 15.0, 40.0, 3.0, 3.0, Color(0.15, 0.55, 0.42))


static func _water_intake(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 12.0
	var g := _group(host, "HullPipe")
	_pipe_h(g, 0.0, floor_y - 28.0, w * 0.28, 7.0, WATER)
	_flange(g, w * 0.20, floor_y - 32.0, 8.0, 15.0, STEEL)
	_valve(g, w * H2O_A + 8.0, floor_y - 24.0, 7.0)
	_pipe_v(g, w * H2O_A, 2.0, floor_y - 30.0, 5.0, WATER)
	var pump := _group(host, "Pump")
	var px := w * 0.30
	var py := floor_y - 40.0
	_shadow(pump, px - 2.0, floor_y - 4.0, 62.0, 6.0)
	_rect(pump, px - 4.0, floor_y - 6.0, 70.0, 5.0, STEEL_DK)
	_ellipse(pump, px + 22.0, py + 16.0, 16.0, 16.0, INK)
	_ellipse(pump, px + 22.0, py + 16.0, 14.0, 14.0, Color(0.40, 0.44, 0.46))
	_ellipse(pump, px + 22.0, py + 16.0, 6.0, 6.0, STEEL_DK)
	_rect(pump, px + 34.0, py + 12.0, 16.0, 7.0, WATER)
	_motor_h(pump, px + 18.0, py - 16.0, 40.0, 14.0, Color(0.32, 0.34, 0.36))
	_fins(pump, px + 24.0, py - 16.0, 28.0, 14.0, 5, Color(0.18, 0.20, 0.22))
	_lamp(pump, px + 52.0, py - 20.0, YELLOW)
	_pipe_h(pump, px + 36.0, py + 8.0, w * 0.22, 5.0, WATER)
	var filters := _group(host, "Filters")
	_vessel(filters, w * 0.66, 16.0, 22.0, floor_y - 22.0, Color(0.52, 0.56, 0.58))
	_vessel(filters, w * 0.82, 22.0, 20.0, floor_y - 28.0, Color(0.42, 0.50, 0.48))
	_rect(filters, w * 0.66, 30.0, 22.0, 4.0, Color(0.20, 0.24, 0.28))
	_rect(filters, w * 0.82, 36.0, 20.0, 4.0, Color(0.20, 0.24, 0.28))
	_pipe_h(filters, w * 0.66, floor_y - 26.0, w * 0.20, 4.0, WATER)
	_panel(host, w * 0.46, 8.0)
	_lamp(host, w * 0.58, 14.0, Color(0.2, 0.85, 0.45))


static func _power_room(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var rcx := w * 0.36
	var rcy := floor_y * 0.46
	# Skid and hold-down bolts under the whole set.
	var skid := _group(host, "EngineSkid")
	_shadow(skid, 4.0, floor_y - 1.0, w - 10.0, 5.0)
	_rect(skid, 3.0, floor_y - 5.0, w - 8.0, 5.0, STEEL_DK)
	_rect(skid, 3.0, floor_y - 5.0, w - 8.0, 1.4, STEEL_LT)
	var bolt := 8.0
	while bolt < w - 10.0:
		_ellipse(skid, bolt, floor_y - 2.5, 1.6, 1.6, STEEL_LT)
		bolt += 16.0
	# Intake plenum on the port wall.
	var intake := _group(host, "Intake")
	_rect(intake, 4.0, 6.0, 16.0, floor_y - 14.0, Color(0.24, 0.28, 0.30))
	_rect(intake, 4.0, 6.0, 3.0, floor_y - 14.0, STEEL_LT)
	_vent_slots(intake, 7.0, 10.0, 11.0, 8)
	_ellipse(intake, 20.0, rcy, 6.0, 10.0, Color(0.16, 0.20, 0.22))
	_ellipse(intake, 20.0, rcy, 3.0, 6.0, Color(0.45, 0.62, 0.70))
	_pipe_h(intake, 18.0, rcy - 2.0, 14.0, 4.0, Color(0.34, 0.40, 0.42))
	# Turbine casing, rotor, and combustor cans.
	var turbine := _group(host, "Turbine")
	_plate(turbine, 30.0, rcy - 24.0, 58.0, 46.0, Color(0.38, 0.40, 0.38))
	_ellipse(turbine, rcx, rcy, 20.0, 20.0, Color(0.12, 0.13, 0.14))
	_ellipse(turbine, rcx, rcy, 16.0, 16.0, Color(0.46, 0.48, 0.46))
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x)
		_poly(turbine, PackedVector2Array([
			Vector2(rcx, rcy) + side * 2.2,
			Vector2(rcx, rcy) + dir * 14.0 + side * 1.4,
			Vector2(rcx, rcy) + dir * 14.0 - side * 1.4,
		]), Color(0.78, 0.80, 0.74))
	_ellipse(turbine, rcx, rcy, 5.5, 5.5, STEEL_DK)
	_ellipse(turbine, rcx, rcy, 2.2, 2.2, YELLOW)
	var block := _group(host, "EngineBlock")
	_plate(block, 34.0, rcy + 16.0, 52.0, floor_y - rcy - 22.0, Color(0.30, 0.28, 0.26))
	_fins(block, 38.0, rcy + 18.0, 44.0, 6.0, 7, Color(0.55, 0.42, 0.28))
	_ellipse(block, 46.0, floor_y - 16.0, 7.0, 8.0, Color(0.26, 0.20, 0.16))
	_ellipse(block, 68.0, floor_y - 16.0, 7.0, 8.0, Color(0.26, 0.20, 0.16))
	_rect(block, 44.0, floor_y - 18.0, 4.0, 6.0, STEEL_DK)
	_rect(block, 66.0, floor_y - 18.0, 4.0, 6.0, STEEL_DK)
	# Heat sits on the cans and the stack. The status node recolors it from sim kW.
	var heat := _group(host, "HeatGlow")
	_ellipse(heat, 46.0, floor_y - 16.0, 9.0, 10.0, Color(1.0, 0.42, 0.08, 0.08))
	_ellipse(heat, 68.0, floor_y - 16.0, 9.0, 10.0, Color(1.0, 0.42, 0.08, 0.08))
	# Exhaust header into a short stack. It stays inside the bay.
	var exhaust := _group(host, "Exhaust")
	_pipe_h(exhaust, rcx + 8.0, rcy - 20.0, 28.0, 5.0, Color(0.32, 0.28, 0.24))
	_pipe_v(exhaust, rcx + 32.0, 2.0, rcy - 18.0, 7.0, Color(0.28, 0.24, 0.22))
	_ellipse(exhaust, rcx + 35.0, 4.0, 6.0, 3.0, Color(0.18, 0.16, 0.14))
	_ellipse(heat, rcx + 35.0, 5.0, 8.0, 5.0, Color(1.0, 0.35, 0.06, 0.08))
	_rect(exhaust, rcx + 30.0, rcy - 24.0, 11.0, 4.0, STEEL)
	# Day tank, sight glass, and injector lines.
	var fuel := _group(host, "FuelSystem")
	var tank_x := w * 0.56
	_vessel(fuel, tank_x, 14.0, 14.0, floor_y - 28.0, Color(0.42, 0.36, 0.28))
	var flow := _group(fuel, "FuelFlow")
	_rect(flow, tank_x + 5.0, 28.0, 3.0, floor_y - 48.0, FUEL)
	_pipe_h(flow, 40.0, floor_y - 14.0, tank_x - 36.0, 3.2, FUEL)
	_pipe_v(flow, tank_x + 3.0, floor_y - 28.0, 14.0, 3.0, FUEL)
	_valve(fuel, tank_x - 6.0, floor_y - 12.0, 3.5)
	# Alternator on the skid, coupled to the turbine shaft. Stops short of the gauges.
	var alt := _group(host, "Alternator")
	var alt_x := w * 0.68
	_rect(alt, rcx + 16.0, rcy - 3.0, alt_x - rcx - 14.0, 6.0, STEEL_DK)
	_motor_h(alt, alt_x, rcy - 8.0, 22.0, 16.0, Color(0.30, 0.34, 0.36))
	_fins(alt, alt_x + 2.0, rcy - 12.0, 16.0, 4.0, 4, STEEL_DK)
	_ellipse(alt, alt_x + 22.0, rcy, 3.5, 3.5, YELLOW)
	# Output bus meets the room's existing power riser at PWR_B.
	var bus := _group(host, "BusGlow")
	_rect(bus, w * PWR_B, 0.0, 4.0, 14.0, Color(0.20, 0.32, 0.34))
	_rect(bus, w * PWR_B, 12.0, w * 0.68 - w * PWR_B, 3.0, Color(0.20, 0.32, 0.34))
	_flange(host, w * PWR_B - 2.0, 0.0, 8.0, 4.0, STEEL)
	# Two gauge faces. Needles are moved by EngineRoomStatus from real sim values.
	var gauges := _group(host, "Gauges")
	_plate(gauges, w - 32.0, 6.0, 28.0, floor_y - 14.0, Color(0.16, 0.18, 0.18))
	var kw_pivot := Vector2(w - 18.0, 22.0)
	var fuel_pivot := Vector2(w - 18.0, 44.0)
	_ellipse(gauges, kw_pivot.x, kw_pivot.y, 8.0, 8.0, Color(0.06, 0.07, 0.08))
	_ellipse(gauges, kw_pivot.x, kw_pivot.y, 6.4, 6.4, Color(0.72, 0.74, 0.68))
	_ellipse(gauges, fuel_pivot.x, fuel_pivot.y, 7.0, 7.0, Color(0.06, 0.07, 0.08))
	_ellipse(gauges, fuel_pivot.x, fuel_pivot.y, 5.6, 5.6, Color(0.55, 0.42, 0.22))
	_needle(gauges, "NeedleKw", kw_pivot, 5.5)
	_needle(gauges, "NeedleFuel", fuel_pivot, 4.8)
	var lamps := _group(host, "StatusLamps")
	_ellipse(lamps, w - 18.0, floor_y - 18.0, 5.0, 3.5, Color(0.15, 0.15, 0.15, 0.35))
	_rect(lamps, w - 20.0, floor_y - 19.0, 4.0, 4.0, Color(0.25, 0.25, 0.25))
	var status: Node = EngineStatusScript.new()
	status.name = "EngineRoomStatus"
	host.add_child(status)
	status.capture(host)


static func _needle(parent: Node2D, needle_name: String, pivot: Vector2, length: float) -> void:
	var needle := Polygon2D.new()
	needle.name = needle_name
	needle.antialiased = false
	needle.color = Color(0.92, 0.93, 0.88)
	var tip := pivot + Vector2(0.0, -length)
	needle.polygon = PackedVector2Array([
		pivot + Vector2(-0.7, 0.0), tip, pivot + Vector2(0.7, 0.0),
	])
	parent.add_child(needle)


static func _corridor(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var land_y := floor_y * 0.50
	var shaft := _group(host, "LadderShaft")
	_rect(shaft, 2.0, 4.0, 50.0, floor_y, Color(0.05, 0.06, 0.07))
	_rect(shaft, 2.0, 4.0, 4.0, floor_y, STEEL)
	_rect(shaft, 48.0, 4.0, 4.0, floor_y, STEEL_LT)
	_rect(shaft, 10.0, 6.0, 4.5, floor_y - 8.0, Color(0.78, 0.64, 0.22))
	_rect(shaft, 34.0, 6.0, 4.5, floor_y - 8.0, Color(0.78, 0.64, 0.22))
	var ry := 11.0
	while ry < floor_y - 6.0:
		if absf(ry - land_y) > 5.0:
			_rect(shaft, 10.0, ry, 28.5, 3.2, STEEL_LT)
		ry += 9.0
	for hy in [16.0, 38.0, 60.0]:
		if float(hy) > floor_y - 18.0:
			continue
		_rect(shaft, 6.0, hy, 42.0, 2.2, Color(0.62, 0.66, 0.60))
		_rect(shaft, 6.0, hy, 2.2, 9.0, Color(0.62, 0.66, 0.60))
		_rect(shaft, 46.0, hy, 2.2, 9.0, Color(0.62, 0.66, 0.60))
	_rect(shaft, 4.0, land_y, 52.0, 5.0, STEEL)
	_rect(shaft, 4.0, land_y, 52.0, 2.0, YELLOW)
	_rect(shaft, 8.0, land_y + 5.0, 3.0, floor_y - land_y - 6.0, STEEL_DK)
	_rect(shaft, 44.0, land_y + 5.0, 3.0, floor_y - land_y - 6.0, STEEL_DK)
	_pipe_v(shaft, 42.0, 8.0, floor_y - 14.0, 3.2, Color(0.20, 0.46, 0.55))
	var tray := _group(host, "CableTray")
	_rect(tray, 56.0, 5.0, w - 64.0, 3.0, Color(0.32, 0.36, 0.38))
	_rect(tray, 56.0, 15.0, w - 64.0, 3.0, Color(0.32, 0.36, 0.38))
	_pipe_h(tray, 58.0, 7.0, w - 70.0, 3.2, INK)
	_rect(tray, 58.0, 7.6, w - 70.0, 1.3, YELLOW)
	_pipe_h(tray, 58.0, 11.0, w - 70.0, 2.6, Color(0.10, 0.22, 0.30))
	_rect(tray, 58.0, 11.4, w - 70.0, 1.1, CYAN)
	var drop := 68.0
	while drop < w - 78.0:
		_rect(tray, drop, 5.0, 2.0, 13.0, STEEL_DK)
		_pipe_v(tray, drop, 17.0, 18.0, 2.6, INK)
		_rect(tray, drop, 18.0, 2.6, 1.1, YELLOW)
		drop += 26.0
	var win := _group(host, "Porthole")
	var wx := w * 0.50
	var wy := 38.0
	_ellipse(win, wx, wy, 12.0, 12.0, STEEL)
	_ellipse(win, wx, wy, 9.0, 9.0, Color(0.55, 0.78, 0.86))
	_ellipse(win, wx - 3.0, wy - 3.0, 3.0, 2.2, Color(0.85, 0.95, 1.0, 0.70))
	_rect(win, wx - 9.0, wy - 1.0, 18.0, 2.0, STEEL_DK)
	_rect(win, wx - 1.0, wy - 9.0, 2.0, 18.0, STEEL_DK)
	_ellipse(win, wx - 8.0, wy - 8.0, 1.5, 1.5, STEEL_LT)
	_ellipse(win, wx + 8.0, wy - 8.0, 1.5, 1.5, STEEL_LT)
	_ellipse(win, wx - 8.0, wy + 8.0, 1.5, 1.5, STEEL_LT)
	_ellipse(win, wx + 8.0, wy + 8.0, 1.5, 1.5, STEEL_LT)
	var locker := _group(host, "ToolLocker")
	var lx := w - 70.0
	_cabinet(locker, lx, 26.0, 28.0, floor_y - 32.0, Color(0.34, 0.38, 0.34))
	_rect(locker, lx + 12.0, 40.0, 3.0, 12.0, YELLOW)
	_rect(locker, lx + 4.0, 32.0, 2.0, 16.0, Color(0.72, 0.28, 0.16))
	_rect(locker, lx + 8.0, 34.0, 2.0, 14.0, STEEL_LT)
	_rect(locker, lx + 20.0, 36.0, 2.0, 12.0, Color(0.20, 0.45, 0.55))
	var hatch := _group(host, "FloorHatch")
	var hx := 78.0
	_rect(hatch, hx, floor_y - 8.0, 36.0, 10.0, Color(0.04, 0.05, 0.06))
	_rect(hatch, hx, floor_y - 8.0, 36.0, 2.0, YELLOW)
	_rect(hatch, hx, floor_y, 36.0, 2.0, STEEL)
	_rect(hatch, hx, floor_y - 8.0, 2.0, 10.0, STEEL)
	_rect(hatch, hx + 34.0, floor_y - 8.0, 2.0, 10.0, STEEL)
	_ellipse(hatch, hx + 18.0, floor_y - 3.0, 2.2, 2.2, STEEL_LT)
	_vessel(host, 56.0, floor_y - 34.0, 9.0, 24.0, Color(0.74, 0.16, 0.12))
	_rect(host, 58.0, floor_y - 36.0, 5.0, 3.0, STEEL_LT)
	var stool := _group(host, "Stool")
	_rect(stool, 66.0, floor_y - 16.0, 12.0, 3.0, Color(0.45, 0.36, 0.22))
	_rect(stool, 68.0, floor_y - 13.0, 2.0, 10.0, STEEL_DK)
	_rect(stool, 76.0, floor_y - 13.0, 2.0, 10.0, STEEL_DK)


static func _ai_core(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var left := _group(host, "ProcessorCabinetL")
	_cabinet(left, 6.0, 14.0, 34.0, floor_y - 16.0, Color(0.18, 0.26, 0.34))
	_pipe_v(left, w * PWR_D, 0.0, 16.0, 4.0, INK)
	_rect(left, w * PWR_D, 0.0, 4.0, 1.2, YELLOW)
	var right := _group(host, "ProcessorCabinetR")
	_cabinet(right, w - 40.0, 14.0, 32.0, floor_y - 16.0, Color(0.16, 0.24, 0.32))
	var loop := _group(host, "CoolingLoop")
	_pipe_h(loop, 20.0, 18.0, w - 48.0, 4.0, CYAN)
	_pipe_h(loop, 20.0, 36.0, w - 48.0, 3.0, Color(0.16, 0.40, 0.55))
	_ellipse(loop, 20.0, 20.0, 4.0, 4.0, CYAN)
	_ellipse(loop, w - 28.0, 20.0, 4.0, 4.0, CYAN)
	_plate(loop, w * 0.46, 22.0, 16.0, 12.0, STEEL)
	_lamp(loop, w * 0.46 + 8.0, 24.0, CYAN)
	var console := _group(host, "Console")
	var cx := w * 0.30
	var cy := floor_y - 32.0
	_shadow(console, cx, floor_y - 3.0, w * 0.40, 5.0)
	_poly(console, PackedVector2Array([
		Vector2(cx + 6.0, cy),
		Vector2(cx + w * 0.38, cy),
		Vector2(cx + w * 0.42, floor_y - 4.0),
		Vector2(cx, floor_y - 4.0),
	]), Color(0.28, 0.32, 0.36))
	_rect(console, cx + 4.0, cy, w * 0.34, 3.0, STEEL_LT)
	_plate(console, cx + 10.0, cy + 6.0, w * 0.26, 12.0, Color(0.08, 0.12, 0.16))
	_named_rect(console, "EnergyGlass", cx + 12.0, cy + 8.0, w * 0.22, 8.0, Color(0.25, 0.70, 0.82, 0.95))
	_rect(console, cx + 14.0, cy + 10.0, w * 0.08, 1.5, Color(0.7, 0.95, 1.0))
	_lamp(console, cx + 12.0, floor_y - 10.0, CYAN)
	_lamp(console, cx + 20.0, floor_y - 10.0, Color(0.3, 0.9, 0.5))
	var trunk := _group(host, "DataTrunk")
	_pipe_h(trunk, 8.0, 46.0, w - 16.0, 2.5, Color(0.10, 0.12, 0.16))
	_rect(trunk, 8.0, 47.0, w - 16.0, 1.0, CYAN)
	_panel(host, w * 0.30, 4.0)


static func _refinery(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var vessels := _group(host, "Vessels")
	_vessel(vessels, 6.0, 10.0, 28.0, floor_y - 16.0, Color(0.55, 0.50, 0.40))
	_rect(vessels, 6.0, 28.0, 28.0, 5.0, FUEL)
	_vessel(vessels, 40.0, 24.0, 24.0, floor_y - 30.0, Color(0.48, 0.46, 0.42))
	_pipe_h(vessels, 18.0, 40.0, 28.0, 4.0, FUEL)
	_valve(vessels, 32.0, 42.0, 5.0)
	_pipe_v(vessels, w * FUEL_E, floor_y - 18.0, 16.0, 4.0, FUEL)
	_pipe_v(vessels, w * PWR_E, 0.0, 14.0, 3.5, INK)
	var hx := _group(host, "HeatExchanger")
	var ex := w * 0.40
	_shadow(hx, ex, floor_y - 3.0, 58.0, 5.0)
	_plate(hx, ex, 30.0, 54.0, floor_y - 36.0, Color(0.42, 0.36, 0.30))
	_fins(hx, ex + 4.0, 34.0, 46.0, floor_y - 46.0, 8, Color(0.62, 0.48, 0.28))
	_pipe_h(hx, ex - 10.0, 36.0, 14.0, 4.0, FUEL)
	_pipe_h(hx, ex + 50.0, floor_y - 28.0, 16.0, 4.0, WATER)
	_ellipse(hx, ex + 27.0, 26.0, 10.0, 6.0, Color(0.85, 0.40, 0.12, 0.35))
	var pump := _group(host, "TransferPump")
	var ppx := w * 0.78
	_shadow(pump, ppx, floor_y - 3.0, 36.0, 5.0)
	_rect(pump, ppx, floor_y - 6.0, 38.0, 5.0, STEEL_DK)
	_ellipse(pump, ppx + 14.0, floor_y - 20.0, 12.0, 12.0, Color(0.36, 0.32, 0.28))
	_ellipse(pump, ppx + 14.0, floor_y - 20.0, 5.0, 5.0, STEEL_DK)
	_motor_h(pump, ppx + 8.0, floor_y - 38.0, 26.0, 12.0, STEEL_DK)
	_pipe_h(pump, ex + 54.0, floor_y - 24.0, ppx - ex - 40.0, 4.0, FUEL)
	_hazard_bar(host, 4.0, floor_y - 5.0, w - 8.0, 3.0)
	_lamp(host, w * 0.72, 12.0, Color(0.9, 0.22, 0.14))
	_panel(host, w * 0.56, 8.0)


static func _storage(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var rack := _group(host, "Racks")
	var rx := 4.0
	var rw := w * 0.40
	_rect(rack, rx, 12.0, 3.0, floor_y - 14.0, STEEL_DK)
	_rect(rack, rx + rw, 12.0, 3.0, floor_y - 14.0, STEEL_DK)
	for i in 3:
		var sy := 18.0 + float(i) * ((floor_y - 28.0) / 3.0)
		_rect(rack, rx, sy, rw, 3.0, STEEL)
		var cw := 16.0 + float(i % 2) * 6.0
		var crate_color := Color(0.45, 0.32, 0.18)
		if i == 1:
			crate_color = Color(0.32, 0.36, 0.30)
		_crate(rack, rx + 6.0, sy - 12.0, cw, 12.0, crate_color)
		_crate(rack, rx + 28.0, sy - 10.0, 18.0, 10.0, Color(0.40, 0.42, 0.38))
	var bins := _group(host, "Bins")
	_bin(bins, w * 0.62, floor_y - 28.0, 18.0, 22.0, Color(0.36, 0.40, 0.34))
	_bin(bins, w * 0.74, floor_y - 34.0, 18.0, 28.0, Color(0.42, 0.38, 0.28))
	_bin(bins, w * 0.86, floor_y - 24.0, 16.0, 18.0, Color(0.30, 0.34, 0.38))
	var arm := _group(host, "RobotArm")
	var shoulder := Vector2(w * 0.50, 10.0)
	_ellipse(arm, shoulder.x, shoulder.y, 5.0, 5.0, STEEL_DK)
	_rect(arm, shoulder.x - 8.0, 4.0, 16.0, 4.0, STEEL)
	var elbow := _arm(arm, shoulder, 50.0, 36.0, 4.0, YELLOW)
	var wrist := _arm(arm, elbow, 95.0, 30.0, 3.5, Color(0.72, 0.56, 0.16))
	_rect(arm, wrist.x - 1.0, wrist.y, 2.0, 8.0, STEEL_LT)
	_rect(arm, wrist.x - 6.0, wrist.y + 6.0, 5.0, 3.0, STEEL)
	_rect(arm, wrist.x + 2.0, wrist.y + 6.0, 5.0, 3.0, STEEL)
	_lamp(host, w * 0.50, 6.0, YELLOW)
	_panel(host, w * 0.62, 8.0)


static func _ocean_intake(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var mouth := _group(host, "IntakeGrate")
	_rect(mouth, 2.0, 12.0, 36.0, floor_y - 16.0, Color(0.06, 0.10, 0.14))
	_rect(mouth, 2.0, 12.0, 36.0, 4.0, STEEL)
	_rect(mouth, 2.0, floor_y - 8.0, 36.0, 4.0, STEEL)
	_rect(mouth, 2.0, 12.0, 4.0, floor_y - 16.0, STEEL)
	_rect(mouth, 34.0, 12.0, 4.0, floor_y - 16.0, STEEL)
	var bar := 8.0
	while bar < 32.0:
		_rect(mouth, bar, 16.0, 2.5, floor_y - 26.0, Color(0.55, 0.60, 0.58))
		bar += 6.0
	_rect(mouth, 6.0, h * 0.48, 28.0, 3.0, STEEL_LT)
	_rect(mouth, 8.0, floor_y - 18.0, 24.0, 6.0, Color(0.20, 0.45, 0.62, 0.7))
	var pipe := _group(host, "IntakePipe")
	var py := h * 0.42
	_pipe_h(pipe, 36.0, py, w * 0.55, 10.0, WATER)
	_flange(pipe, 36.0, py - 3.0, 6.0, 16.0, STEEL)
	_flange(pipe, w * 0.48, py - 3.0, 6.0, 16.0, STEEL)
	_valve(pipe, w * 0.40, py + 5.0, 8.0)
	_pipe_v(pipe, w * H2O_A, 0.0, py, 6.0, WATER)
	_pipe_v(pipe, w * 0.62, py + 8.0, floor_y - py - 10.0, 6.0, Color(0.16, 0.32, 0.42))
	_ellipse(pipe, w * 0.65, py + 16.0, 2.0, 3.0, Color(0.6, 0.8, 0.9, 0.7))
	_chevron(pipe, w * 0.32, py + 2.0, 1.0, STEEL_LT)
	_panel(host, w * 0.72, 10.0)
	_lamp(host, w * 0.84, py, Color(0.2, 0.75, 0.9))


static func _sub_bay(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var rails := _group(host, "LaunchRails")
	_rect(rails, 8.0, floor_y - 8.0, w - 36.0, 3.0, STEEL)
	_rect(rails, 8.0, floor_y - 16.0, w - 36.0, 2.0, STEEL_DK)
	var gx := 14.0
	while gx < w - 40.0:
		_rect(rails, gx, floor_y - 8.0, 2.0, 3.0, YELLOW)
		gx += 10.0
	var cradle := _group(host, "Cradle")
	_brace(cradle, Vector2(w * 0.22, floor_y - 6.0), Vector2(w * 0.32, floor_y - 28.0), 3.0, STEEL_DK)
	_brace(cradle, Vector2(w * 0.70, floor_y - 6.0), Vector2(w * 0.58, floor_y - 28.0), 3.0, STEEL_DK)
	_rect(cradle, w * 0.24, floor_y - 30.0, w * 0.42, 3.0, STEEL)
	var sub := _group(host, "MiniSub")
	var scx := w * 0.46
	var scy := floor_y - 40.0
	_ellipse(sub, scx + 2.0, scy + 2.0, 46.0, 12.0, SHADOW)
	_ellipse(sub, scx, scy, 46.0, 11.0, Color(0.62, 0.58, 0.28))
	_ellipse(sub, scx, scy + 3.0, 40.0, 6.0, Color(0.28, 0.30, 0.22))
	_rect(sub, scx - 20.0, scy - 14.0, 16.0, 10.0, Color(0.50, 0.48, 0.30))
	_rect(sub, scx - 16.0, scy - 12.0, 8.0, 4.0, Color(0.15, 0.22, 0.24))
	_rect(sub, scx + 40.0, scy - 3.0, 10.0, 6.0, STEEL_DK)
	_rect(sub, scx + 48.0, scy - 6.0, 2.0, 4.0, STEEL_LT)
	_rect(sub, scx + 48.0, scy + 3.0, 2.0, 4.0, STEEL_LT)
	_lamp(sub, scx - 30.0, scy - 2.0, CYAN)
	var cargo := _group(host, "CargoBelt")
	var belt_y := floor_y - 22.0
	_rect(cargo, w * 0.52, belt_y, w * 0.48 + 6.0, 8.0, Color(0.16, 0.16, 0.15))
	_rect(cargo, w * 0.52, belt_y, w * 0.48 + 6.0, 2.0, Color(0.42, 0.40, 0.32))
	var arms := _group(host, "RepairArms")
	var a1 := _arm(arms, Vector2(w * 0.18, 8.0), 70.0, 34.0, 3.5, YELLOW)
	_arm(arms, a1, 110.0, 22.0, 3.0, STEEL)
	var a2 := _arm(arms, Vector2(w * 0.78, 6.0), 100.0, 32.0, 3.5, YELLOW)
	var claw := _arm(arms, a2, 150.0, 16.0, 2.5, STEEL_LT)
	_rect(arms, claw.x - 4.0, claw.y, 3.0, 6.0, STEEL)
	_rect(arms, claw.x + 2.0, claw.y, 3.0, 6.0, STEEL)
	var gear := _group(host, "HatchGear")
	_rect(gear, w - 22.0, 16.0, 8.0, floor_y - 24.0, Color(0.34, 0.36, 0.32))
	_rect(gear, w - 20.0, 20.0, 4.0, 6.0, Color(0.1, 0.12, 0.12))
	_teeth(gear, w - 30.0, floor_y - 14.0, 4, STEEL_LT)
	_ellipse(gear, w - 18.0, floor_y - 20.0, 5.0, 5.0, STEEL_DK)
	var cord := _group(host, "Umbilical")
	_pipe_v(cord, w * 0.20, 0.0, 18.0, 3.0, INK)
	_pipe_h(cord, w * 0.20, 16.0, w * 0.18, 3.0, INK)
	_rect(cord, w * 0.20, 0.0, 3.0, 1.0, YELLOW)
	_panel(host, 4.0, 4.0)


static func _sorting(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var belt := _group(host, "Conveyor")
	var by := floor_y - 22.0
	_rect(belt, -4.0, by, w * 0.74 + 4.0, 10.0, Color(0.16, 0.16, 0.15))
	_rect(belt, -4.0, by, w * 0.74 + 4.0, 2.0, Color(0.42, 0.40, 0.32))
	_rect(belt, -4.0, by + 8.0, w * 0.74 + 4.0, 2.0, STEEL_DK)
	var rx := 4.0
	while rx < w * 0.72:
		_ellipse(belt, rx, by + 5.0, 3.0, 3.0, STEEL)
		rx += 14.0
	_crate(belt, w * 0.28, by - 8.0, 14.0, 8.0, Color(0.42, 0.34, 0.22))
	var scan := _group(host, "Scanner")
	var sx := w * 0.46
	_rect(scan, sx, by - 28.0, 3.0, 28.0, STEEL_DK)
	_rect(scan, sx + 28.0, by - 28.0, 3.0, 28.0, STEEL_DK)
	_rect(scan, sx, by - 28.0, 31.0, 4.0, STEEL)
	_rect(scan, sx + 4.0, by - 22.0, 23.0, 2.0, Color(0.3, 0.85, 0.9, 0.8))
	_lamp(scan, sx + 14.0, by - 32.0, CYAN)
	var grab := _group(host, "Grabber")
	var g0 := Vector2(w * 0.34, 6.0)
	_rect(grab, g0.x - 8.0, 2.0, 16.0, 3.0, STEEL)
	var g1 := _arm(grab, g0, 75.0, 26.0, 3.0, YELLOW)
	var g2 := _arm(grab, g1, 120.0, 18.0, 2.5, STEEL_LT)
	_rect(grab, g2.x - 4.0, g2.y, 3.0, 5.0, STEEL)
	_rect(grab, g2.x + 2.0, g2.y, 3.0, 5.0, STEEL)
	var bins := _group(host, "SortBins")
	_bin(bins, w * 0.76, floor_y - 30.0, 14.0, 24.0, Color(0.22, 0.40, 0.28))
	_bin(bins, w * 0.84, floor_y - 36.0, 14.0, 30.0, Color(0.55, 0.40, 0.16))
	_bin(bins, w * 0.92, floor_y - 26.0, 12.0, 20.0, Color(0.28, 0.32, 0.36))
	_panel(host, 6.0, 8.0)
	_lamp(host, 28.0, 12.0, YELLOW)


static func _biology(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var tanks := _group(host, "SampleTanks")
	_tank_glass(tanks, 6.0, 18.0, 44.0, floor_y - 22.0, Color(0.18, 0.55, 0.42), 0.72)
	_tank_glass(tanks, 56.0, 18.0, 40.0, floor_y - 22.0, Color(0.16, 0.42, 0.48), 0.60)
	var air := _group(host, "Aeration")
	_pipe_h(air, 8.0, 12.0, 90.0, 3.0, STEEL_LT)
	_pipe_v(air, 24.0, 14.0, 12.0, 2.5, STEEL)
	_pipe_v(air, 74.0, 14.0, 12.0, 2.5, STEEL)
	_ellipse(air, 25.0, 30.0, 2.0, 2.0, Color(0.8, 0.95, 1.0, 0.8))
	_ellipse(air, 75.0, 32.0, 1.6, 1.6, Color(0.8, 0.95, 1.0, 0.8))
	var filt := _group(host, "Filter")
	_vessel(filt, w * 0.58, 28.0, 18.0, floor_y - 36.0, Color(0.40, 0.48, 0.46))
	_rect(filt, w * 0.58, 40.0, 18.0, 4.0, BIO)
	_pipe_h(filt, 96.0, 36.0, w * 0.58 - 96.0, 3.0, WATER)
	var nut := _group(host, "NutrientCanister")
	_vessel(nut, w * 0.78, floor_y - 48.0, 22.0, 40.0, Color(0.62, 0.58, 0.22))
	_rect(nut, w * 0.78, floor_y - 28.0, 22.0, 8.0, BIO)
	_pipe_h(nut, w * 0.58 + 16.0, floor_y - 30.0, w * 0.20, 3.0, BIO)
	var circ := _group(host, "CircPump")
	_ellipse(circ, w * 0.72, floor_y - 14.0, 7.0, 7.0, STEEL)
	_ellipse(circ, w * 0.72, floor_y - 14.0, 3.0, 3.0, STEEL_DK)
	_lamp(host, w * 0.72, 16.0, BIO)
	_panel(host, w * 0.80, 8.0)


static func _reserves(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var tanks := _group(host, "StorageTanks")
	_storage_tank(tanks, 4.0, 14.0, 28.0, floor_y - 20.0, CRUDE, Color(0.05, 0.04, 0.03))
	_storage_tank(tanks, w * 0.24, 22.0, 28.0, floor_y - 28.0, Color(0.62, 0.40, 0.12), FUEL)
	var sight := _group(host, "FuelSight")
	var glass_x := w * 0.24 + 10.5
	var glass_y := 27.0
	var glass_h := (floor_y - 28.0) - 12.0
	_rect(sight, glass_x - 1.0, glass_y, 5.0, glass_h, Color(0.08, 0.10, 0.11))
	var fuel_fill := Polygon2D.new()
	fuel_fill.name = "FuelFill"
	fuel_fill.antialiased = false
	fuel_fill.color = FUEL
	var fuel_span := Rect2(glass_x, glass_y + 1.0, 3.0, glass_h - 2.0)
	fuel_fill.set_meta("span", fuel_span)
	fuel_fill.polygon = PackedVector2Array([
		fuel_span.position,
		fuel_span.position + Vector2(fuel_span.size.x, 0.0),
		fuel_span.position + fuel_span.size,
		fuel_span.position + Vector2(0.0, fuel_span.size.y),
	])
	sight.add_child(fuel_fill)
	_storage_tank(tanks, w * 0.46, 12.0, 28.0, floor_y - 18.0, Color(0.46, 0.50, 0.28), BIO)
	_storage_tank(tanks, w * 0.70, 26.0, 26.0, floor_y - 32.0, Color(0.40, 0.44, 0.48), Color(0.25, 0.32, 0.40))
	var man := _group(host, "Manifold")
	_pipe_h(man, 8.0, floor_y - 10.0, w - 20.0, 4.0, STEEL_DK)
	_valve(man, 18.0, floor_y - 8.0, 4.5)
	_valve(man, w * 0.32, floor_y - 8.0, 4.5)
	_valve(man, w * 0.54, floor_y - 8.0, 4.5)
	_valve(man, w * 0.76, floor_y - 8.0, 4.5)
	_pipe_v(man, w * FUEL_E, 0.0, 20.0, 4.0, FUEL)
	_pipe_h(man, w * 0.46 + 20.0, 20.0, w * 0.22, 3.0, BIO)
	_lamp(host, w - 16.0, 12.0, YELLOW)
	_panel(host, w * 0.84, 8.0)


static func _recycling(host: Node2D, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var floor_y := h - 11.0
	var sep := _group(host, "Separator")
	_poly(sep, PackedVector2Array([
		Vector2(8.0, 16.0),
		Vector2(58.0, 16.0),
		Vector2(48.0, 40.0),
		Vector2(18.0, 40.0),
	]), Color(0.40, 0.38, 0.32))
	_plate(sep, 12.0, 40.0, 46.0, floor_y - 48.0, Color(0.36, 0.38, 0.34))
	_rect(sep, 18.0, 48.0, 34.0, 4.0, STEEL_DK)
	_pipe_h(sep, 52.0, 52.0, 28.0, 5.0, Color(0.32, 0.30, 0.26))
	_chevron(sep, 60.0, 53.0, 1.0, YELLOW)
	var press := _group(host, "Press")
	_motor_h(press, w * 0.46, 36.0, 40.0, 16.0, STEEL_DK)
	_fins(press, w * 0.50, 36.0, 28.0, 16.0, 5, Color(0.15, 0.16, 0.16))
	_rect(press, w * 0.46, floor_y - 8.0, 44.0, 4.0, STEEL)
	_brace(press, Vector2(w * 0.48, floor_y - 6.0), Vector2(w * 0.50, 52.0), 2.5, STEEL_DK)
	_brace(press, Vector2(w * 0.66, floor_y - 6.0), Vector2(w * 0.64, 52.0), 2.5, STEEL_DK)
	var drums := _group(host, "SealedDrums")
	_drum(drums, w * 0.74, floor_y - 46.0, 20.0, 40.0)
	_drum(drums, w * 0.88, floor_y - 40.0, 18.0, 34.0)
	var flange := _group(host, "ExpansionFlange")
	_pipe_h(flange, w - 28.0, 18.0, 26.0, 5.0, STEEL)
	_ellipse(flange, w - 6.0, 20.5, 6.0, 6.0, STEEL_LT)
	_ellipse(flange, w - 6.0, 20.5, 2.5, 2.5, INK)
	_lamp(host, w * 0.40, 14.0, Color(0.9, 0.18, 0.12))
	_lamp(host, w * 0.40 + 10.0, 14.0, YELLOW)
	_panel(host, 64.0, 8.0)


static func _routes(infra: Node2D, rooms: Node2D) -> void:
	var power := infra.get_node_or_null("PowerCables") as Node2D
	var data := infra.get_node_or_null("DataCables") as Node2D
	var water := infra.get_node_or_null("WaterPipes") as Node2D
	var fuel := infra.get_node_or_null("FuelPipes") as Node2D
	var conv := infra.get_node_or_null("Conveyors") as Node2D
	var b2 := _room_rect(rooms, "PowerRoom")
	var d2 := _room_rect(rooms, "AICoreRoom")
	var e2 := _room_rect(rooms, "RefineryRoom")
	var a2 := _room_rect(rooms, "WaterIntakeRoom")
	var a3 := _room_rect(rooms, "OceanIntake")
	var d3 := _room_rect(rooms, "BiologyRoom")
	var e3 := _room_rect(rooms, "ProductReserves")
	var b3 := _room_rect(rooms, "SubmarineBay")
	var c3 := _room_rect(rooms, "ResourceSortingRoom")
	if power != null:
		var bus := _group(power, "UpperBus")
		var x0 := b2.position.x + b2.size.x * PWR_B
		var x1 := e2.position.x + e2.size.x * PWR_E
		_cable_h(bus, x0, 283.0, x1 - x0)
		_hangers(bus, x0, 283.0, x1 - x0)
		var xb := b2.position.x + b2.size.x * 0.16
		_deck_riser(power, xb, INK, "RiserToSubBay")
		_rect(power, xb, 400.0, 3.0, 1.2, YELLOW)
	if water != null:
		var top := _group(water, "CoolingFeed")
		var xa := a2.position.x + a2.size.x * H2O_A
		var xb2 := b2.position.x + b2.size.x * 0.22
		_pipe_h(top, xa, 291.0, xb2 - xa, 4.0, WATER)
		_chevron(top, (xa + xb2) * 0.5, 291.0, 1.0, STEEL_LT)
		_hangers(top, xa, 291.0, xb2 - xa)
		_deck_riser(water, xa, WATER, "IntakeRiser")
		var low := _group(water, "BiologyFeed")
		var xa3 := a3.position.x + a3.size.x * H2O_A
		var xd := d3.position.x + d3.size.x * 0.20
		_pipe_h(low, xa3, 411.0, xd - xa3, 4.0, WATER)
		_chevron(low, xa3 + 80.0, 411.0, 1.0, STEEL_LT)
	if fuel != null:
		var xf := e2.position.x + e2.size.x * FUEL_E
		_deck_riser(fuel, xf, FUEL, "ProductRiser")
		var man := _group(fuel, "ReserveTieIn")
		var x_tank := e3.position.x + e3.size.x * 0.28
		_pipe_h(man, minf(xf, x_tank), e3.position.y + 8.0, absf(x_tank - xf) + 4.0, 3.5, FUEL)
	if data != null:
		var trunk := _group(data, "CoreTrunk")
		var xd2 := d2.position.x + 8.0
		var xe := e2.position.x + e2.size.x * 0.55
		var x_from := b2.position.x + b2.size.x * 0.5
		_pipe_h(trunk, x_from, 300.0, xe - x_from, 2.0, Color(0.08, 0.10, 0.14))
		_rect(trunk, xd2, 300.5, xe - xd2, 1.0, CYAN)
		var low_d := _group(data, "LowerTrunk")
		var x_left := c3.position.x
		var x_right := e3.position.x + e3.size.x
		_pipe_h(low_d, x_left, 418.0, x_right - x_left, 2.0, Color(0.08, 0.10, 0.14))
		_rect(low_d, x_left, 418.5, x_right - x_left, 1.0, CYAN)
	if conv != null:
		_hatch_belt(conv)
	# touch b3 so a missing bay warns via _room_rect; umbilical is in-room
	if b3.size.x <= 0.0:
		push_warning("EquipmentBuilder: submarine bay rect empty")


static func _hatch_belt(parent: Node2D) -> void:
	for opening in _door_openings():
		if int(opening["col"]) != 2 or int(opening["floor"]) != 1:
			continue
		var x := float(opening["x"]) + 3.0
		var width := float(opening["thick"]) - 6.0
		var top := float(opening["top"])
		var bot := float(opening["bot"])
		var belt_y := _lower_belt_y()
		if belt_y < top or belt_y + 8.0 > bot:
			belt_y = (top + bot) * 0.5 - 4.0
		var g := _group(parent, "BayBeltLink")
		_rect(g, x, belt_y, width, 8.0, Color(0.18, 0.17, 0.14))
		_rect(g, x, belt_y, width, 2.0, Color(0.45, 0.40, 0.28))


static func _lower_works(interior: Node2D) -> void:
	var old := interior.get_node_or_null("LowerWorks")
	if old:
		old.free()
	var root := Node2D.new()
	root.name = "LowerWorks"
	root.z_index = 0
	interior.add_child(root)
	var chord := Color(0.48, 0.44, 0.34)
	var web := Color(0.26, 0.28, 0.30)
	# Posts drop off the cut sill onto the keel, aligned with bay bulkheads.
	var cw := CUT_SIZE.x / float(COLS)
	var posts: Array[float] = [150.0, 1424.0]
	for col in range(1, COLS):
		posts.append(CUT_POS.x + float(col) * cw - 8.0)
	# Columns start under the painted hull lip so the orange stripe stays visible.
	# Leave the center keel open. That span is the submarine drop path.
	var drop_l := 370.0
	var drop_r := 1230.0
	for x in posts:
		if x > drop_l - 10.0 and x < drop_r:
			continue
		_rect(root, x, 556.0, 5.0, 12.0, chord)
		_rect(root, x, 556.0, 5.0, 2.0, STEEL_LT)
	_rect(root, 150.0, 562.0, drop_l - 150.0, 6.0, chord)
	_rect(root, 150.0, 562.0, drop_l - 150.0, 2.0, STEEL_LT)
	_rect(root, drop_r, 562.0, 1450.0 - drop_r, 6.0, chord)
	_rect(root, drop_r, 562.0, 1450.0 - drop_r, 2.0, STEEL_LT)
	var rivet := 160.0
	while rivet < drop_l:
		_rect(root, rivet, 563.0, 3.0, 3.0, Color(0.78, 0.72, 0.48))
		rivet += 32.0
	rivet = drop_r
	while rivet < 1440.0:
		_rect(root, rivet, 563.0, 3.0, 3.0, Color(0.78, 0.72, 0.48))
		rivet += 32.0
	# Pod gaps are drawn by OilRigAllInOneIntegration. A filled truss grid here
	# would close the water between the separated buoyancy pods.
	var bays: Array = []
	for b in bays:
		var x0: float = b[0]
		var x1: float = b[1]
		var y0 := 568.0
		var y1 := 604.0
		_rect(root, x0, y0, 4.0, y1 - y0, web)
		_rect(root, x1 - 4.0, y0, 4.0, y1 - y0, web)
		_rect(root, x0, y1 - 5.0, x1 - x0, 5.0, chord)
		_rect(root, x0 + 4.0, 584.0, x1 - x0 - 8.0, 3.0, Color(0.40, 0.38, 0.32))
		var sx := x0 + 14.0
		while sx < x1 - 10.0:
			_rect(root, sx, y0, 2.0, y1 - y0 - 4.0, Color(0.33, 0.35, 0.34))
			sx += 26.0
		_brace(root, Vector2(x0, y0 + 2.0), Vector2(x1, y1 - 5.0), 2.5, Color(0.55, 0.40, 0.18))
		_brace(root, Vector2(x0, y1 - 5.0), Vector2(x1, y0 + 2.0), 2.5, Color(0.30, 0.32, 0.34))
		var gx := x0 + 8.0
		while gx < x1 - 8.0:
			_rect(root, gx, y0 + 8.0, 2.0, 8.0, Color(0.62, 0.58, 0.46, 0.9))
			gx += 9.0
	_pipe_h(root, 170.0, 572.0, drop_l - 180.0, 3.5, Color(0.20, 0.38, 0.50))
	_pipe_h(root, drop_r, 572.0, 1450.0 - drop_r, 3.5, Color(0.20, 0.38, 0.50))
	for lx in [210.0, 1380.0]:
		_lamp(root, lx, 560.0, YELLOW)


static func _bilge_pump(machinery: Node2D) -> void:
	var old := machinery.get_node_or_null("BilgePump")
	if old:
		old.free()
	var g := _group(machinery, "BilgePump")
	g.z_index = -8
	var x := 250.0
	var y := 574.0
	_plate(g, x, y, 52.0, 22.0, Color(0.38, 0.40, 0.38))
	_ellipse(g, x + 16.0, y + 12.0, 8.0, 8.0, STEEL_DK)
	_ellipse(g, x + 16.0, y + 12.0, 3.0, 3.0, YELLOW)
	_motor_h(g, x + 22.0, y + 4.0, 24.0, 10.0, Color(0.24, 0.26, 0.28))
	_pipe_h(g, x + 50.0, y + 8.0, 24.0, 4.0, WATER)
	_lamp(g, x + 8.0, y + 4.0, Color(0.3, 0.8, 0.4))


static func _deck_riser(parent: Node2D, x: float, color: Color, name: String) -> void:
	var g := _group(parent, name)
	# Crosses only the deck band between the two floors, not the machine faces.
	_rect(g, x, 378.0, 5.0, 48.0, _darken(color, 0.08))
	_rect(g, x, 378.0, 1.4, 48.0, _lighten(color, 0.18))
	_flange(g, x - 2.0, 386.0, 9.0, 4.0, STEEL)
	_flange(g, x - 2.0, 408.0, 9.0, 4.0, STEEL)


static func _door_openings() -> Array:
	var openings: Array = []
	var cw := CUT_SIZE.x / float(COLS)
	var mid := CUT_POS.y + CUT_SIZE.y * 0.5
	var thick := 16.0
	var door_cfgs: Array = [
		[78.0, 6.0], [64.0, 10.0], [72.0, 8.0], [80.0, 6.0], [68.0, 12.0],
	]
	for col in range(1, COLS):
		var x := CUT_POS.x + float(col) * cw - thick * 0.5
		var cfg: Array = door_cfgs[col - 1]
		var specs: Array = [
			[CUT_POS.y + 10.0, mid - 4.0, float(cfg[0]), float(cfg[1]), 0],
			[mid + 6.0, CUT_POS.y + CUT_SIZE.y - 10.0, float(cfg[0]) - 8.0, float(cfg[1]) + 4.0, 1],
		]
		for spec in specs:
			var y0: float = spec[0]
			var y1: float = spec[1]
			var door_h: float = spec[2]
			var gap: float = spec[3]
			var door_bot := y1 - gap
			var door_top := door_bot - door_h
			if door_top < y0 + 12.0:
				door_top = y0 + 12.0
			openings.append({
				"col": col,
				"floor": int(spec[4]),
				"x": x,
				"thick": thick,
				"top": door_top,
				"bot": door_bot,
			})
	return openings


static func _lower_belt_y() -> float:
	var mid := CUT_POS.y + CUT_SIZE.y * 0.5
	var y0 := mid + 14.0
	var y1 := CUT_POS.y + CUT_SIZE.y - 18.0
	var room_h := y1 - y0
	return y0 + (room_h - 11.0) - 22.0


static func _room_rect(rooms: Node2D, room_name: String) -> Rect2:
	var n := rooms.get_node_or_null(room_name) as Node2D
	if n == null:
		push_warning("EquipmentBuilder missing room %s" % room_name)
		return Rect2()
	return Rect2(n.position, n.get("room_size"))


static func _group(parent: Node2D, group_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = group_name
	parent.add_child(n)
	return n


static func _count_polys(n: Node) -> int:
	var c := 0
	if n is Polygon2D:
		c = 1
	for ch in n.get_children():
		c += _count_polys(ch)
	return c


static func _poly(parent: Node2D, pts: PackedVector2Array, color: Color) -> void:
	if parent == null or pts.size() < 3:
		return
	var p := Polygon2D.new()
	p.name = "p%d" % parent.get_child_count()
	p.antialiased = false
	p.color = color
	p.polygon = pts
	parent.add_child(p)


static func _named_rect(parent: Node2D, node_name: String, x: float, y: float, w: float, h: float, color: Color) -> void:
	if parent == null or w < 0.4 or h < 0.4:
		return
	var p := Polygon2D.new()
	p.name = node_name
	p.antialiased = false
	p.color = color
	p.polygon = PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
	])
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


static func _lighten(c: Color, amount: float) -> Color:
	return Color(clampf(c.r + amount, 0.0, 1.0), clampf(c.g + amount, 0.0, 1.0), clampf(c.b + amount, 0.0, 1.0), c.a)


static func _darken(c: Color, amount: float) -> Color:
	return Color(clampf(c.r - amount, 0.0, 1.0), clampf(c.g - amount, 0.0, 1.0), clampf(c.b - amount, 0.0, 1.0), c.a)


static func _shadow(parent: Node2D, x: float, y: float, w: float, h: float) -> void:
	_rect(parent, x + 2.0, y, w, h, SHADOW)


static func _plate(parent: Node2D, x: float, y: float, w: float, h: float, fill: Color) -> void:
	_rect(parent, x - 1.0, y - 1.0, w + 2.0, h + 2.0, INK)
	_rect(parent, x, y, w, h, fill)
	_rect(parent, x, y, w, maxf(1.0, h * 0.14), _lighten(fill, 0.16))
	_rect(parent, x + w * 0.78, y, maxf(1.0, w * 0.22), h, _darken(fill, 0.10))


static func _vessel(parent: Node2D, x: float, y: float, w: float, h: float, body: Color) -> void:
	if h < 8.0 or w < 6.0:
		return
	var rx := w * 0.5
	var cap_y := maxf(2.4, w * 0.16)
	_ellipse(parent, x + rx + 1.0, y + h + 1.0, rx, cap_y * 0.7, SHADOW)
	_rect(parent, x - 1.0, y, w + 2.0, h, INK)
	_rect(parent, x, y, w, h, body)
	_rect(parent, x + w * 0.70, y, w * 0.30, h, _darken(body, 0.12))
	_rect(parent, x + w * 0.12, y, maxf(1.0, w * 0.10), h, _lighten(body, 0.16))
	_ellipse(parent, x + rx, y, rx + 0.5, cap_y, _lighten(body, 0.08))
	_ellipse(parent, x + rx, y + h, rx, cap_y * 0.85, _darken(body, 0.10))


static func _motor_h(parent: Node2D, x: float, y: float, w: float, h: float, body: Color) -> void:
	var ry := h * 0.5
	_ellipse(parent, x, y + ry, ry * 0.55, ry, _darken(body, 0.08))
	_rect(parent, x, y, w, h, body)
	_rect(parent, x, y, w, maxf(1.0, h * 0.22), _lighten(body, 0.14))
	_ellipse(parent, x + w, y + ry, ry * 0.55, ry, _lighten(body, 0.06))
	_ellipse(parent, x + w, y + ry, ry * 0.22, ry * 0.4, STEEL_DK)


static func _pipe_h(parent: Node2D, x: float, y: float, length: float, thick: float, color: Color) -> void:
	if length < 1.0:
		return
	_rect(parent, x, y + 1.0, length, thick, Color(0, 0, 0, 0.25))
	_rect(parent, x, y, length, thick, color)
	_rect(parent, x, y, length, maxf(1.0, thick * 0.30), _lighten(color, 0.20))


static func _pipe_v(parent: Node2D, x: float, y: float, length: float, thick: float, color: Color) -> void:
	if length < 1.0:
		return
	_rect(parent, x + 1.0, y, thick, length, Color(0, 0, 0, 0.25))
	_rect(parent, x, y, thick, length, color)
	_rect(parent, x, y, maxf(1.0, thick * 0.30), length, _lighten(color, 0.18))


static func _flange(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	_rect(parent, x, y, w, h, color)
	_rect(parent, x + 1.0, y + 1.0, maxf(1.0, w - 2.0), 1.0, STEEL_LT)


static func _valve(parent: Node2D, cx: float, cy: float, r: float) -> void:
	_ellipse(parent, cx, cy, r, r, Color(0.78, 0.62, 0.16))
	_ellipse(parent, cx, cy, r * 0.45, r * 0.45, Color(0.28, 0.22, 0.12))
	_rect(parent, cx - r * 1.35, cy - 1.3, r * 2.7, 2.6, STEEL_LT)
	_rect(parent, cx - 1.3, cy - r * 1.35, 2.6, r * 2.7, STEEL_LT)


static func _lamp(parent: Node2D, x: float, y: float, color: Color) -> void:
	_ellipse(parent, x, y, 5.0, 4.0, Color(color.r, color.g, color.b, 0.28))
	_rect(parent, x - 3.0, y + 2.0, 6.0, 2.0, STEEL_DK)
	_rect(parent, x - 2.0, y - 2.0, 4.0, 4.0, color)


static func _fins(parent: Node2D, x: float, y: float, w: float, h: float, n: int, color: Color) -> void:
	if n < 1 or w < 2.0:
		return
	var gap := w / float(n)
	for i in n:
		_rect(parent, x + float(i) * gap, y, maxf(1.2, gap * 0.38), h, color)


static func _vent_slots(parent: Node2D, x: float, y: float, w: float, n: int) -> void:
	for i in n:
		_rect(parent, x, y + float(i) * 3.0, w, 1.4, INK)


static func _cabinet(parent: Node2D, x: float, y: float, w: float, h: float, body: Color) -> void:
	_shadow(parent, x, y + h - 2.0, w, 5.0)
	_plate(parent, x, y, w, h, body)
	_rect(parent, x + w * 0.5, y + 4.0, 1.2, h - 8.0, _darken(body, 0.08))
	var vy := y + 10.0
	while vy < y + h - 16.0:
		_rect(parent, x + 3.0, vy, w - 6.0, 1.4, Color(0.05, 0.08, 0.10))
		vy += 6.0
	_lamp(parent, x + 6.0, y + 8.0, CYAN)
	_lamp(parent, x + 12.0, y + 8.0, CYAN)
	_rect(parent, x, y + h - 4.0, w, 4.0, STEEL_DK)


static func _crate(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	_plate(parent, x, y, w, h, color)
	_rect(parent, x + 2.0, y + h * 0.45, maxf(1.0, w - 4.0), 1.2, _darken(color, 0.16))


static func _bin(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	_rect(parent, x + 1.0, y + h - 2.0, w, 3.0, SHADOW)
	_rect(parent, x, y, w, h, _darken(color, 0.02))
	_rect(parent, x + 2.0, y + 3.0, w - 4.0, h - 6.0, _darken(color, 0.16))
	_rect(parent, x, y, w, 3.0, _lighten(color, 0.14))


static func _tank_glass(parent: Node2D, x: float, y: float, w: float, h: float, liquid: Color, fill_ratio: float) -> void:
	_rect(parent, x - 1.0, y - 1.0, w + 2.0, h + 2.0, Color(0.55, 0.62, 0.64))
	_rect(parent, x, y, w, h, Color(0.12, 0.18, 0.20))
	var lh := h * fill_ratio
	_rect(parent, x + 2.0, y + h - lh, w - 4.0, lh - 2.0, liquid)
	_rect(parent, x + 2.0, y + h - lh, w - 4.0, 2.0, _lighten(liquid, 0.2))
	_rect(parent, x + 3.0, y + 2.0, 2.0, h - 4.0, Color(1, 1, 1, 0.18))
	var fish_y := y + h - lh * 0.55
	_ellipse(parent, x + w * 0.35, fish_y, 5.0, 2.2, Color(0.78, 0.86, 0.45))
	_ellipse(parent, x + w * 0.62, fish_y + 6.0, 4.0, 1.8, Color(0.90, 0.78, 0.40))
	_ellipse(parent, x + w * 0.48, y + 8.0, 1.5, 1.5, Color(0.85, 0.95, 1.0, 0.75))


static func _storage_tank(parent: Node2D, x: float, y: float, w: float, h: float, body: Color, sight: Color) -> void:
	_vessel(parent, x, y, w, h, body)
	_rect(parent, x + w * 0.42, y + 6.0, 3.0, h - 10.0, Color(0.75, 0.82, 0.84))
	var sh := h * 0.45
	_rect(parent, x + w * 0.42, y + h - sh, 3.0, sh - 4.0, sight)
	_rect(parent, x, y + 8.0, w, 3.0, _darken(body, 0.05))


static func _drum(parent: Node2D, x: float, y: float, w: float, h: float) -> void:
	_vessel(parent, x, y, w, h, Color(0.32, 0.34, 0.30))
	var by := y + 6.0
	var on := true
	while by < y + h - 6.0:
		var band := YELLOW
		if not on:
			band = INK
		_rect(parent, x, by, w, 3.5, band)
		by += 3.5
		on = not on
	_ellipse(parent, x + w * 0.5, y + 2.0, w * 0.28, 2.5, STEEL_LT)


static func _grate(parent: Node2D, size: Vector2) -> void:
	var g := _group(parent, "FloorGrate")
	var x := 2.0
	while x < size.x - 2.0:
		_rect(g, x, size.y - 8.0, 2.0, 6.0, Color(0.40, 0.44, 0.42, 0.85))
		x += 7.0


static func _panel(parent: Node2D, x: float, y: float) -> void:
	var g := _group(parent, "WallPanel")
	_plate(g, x, y, 20.0, 14.0, Color(0.34, 0.37, 0.38))
	_rect(g, x + 2.0, y + 2.0, 2.0, 2.0, STEEL_LT)
	_rect(g, x + 16.0, y + 2.0, 2.0, 2.0, STEEL_LT)
	_rect(g, x + 2.0, y + 10.0, 2.0, 2.0, STEEL_LT)
	_rect(g, x + 16.0, y + 10.0, 2.0, 2.0, STEEL_LT)
	_rect(g, x + 5.0, y + 6.0, 10.0, 1.2, STEEL_DK)


static func _hazard_bar(parent: Node2D, x: float, y: float, w: float, h: float) -> void:
	var t := 0.0
	var on := true
	while t < w:
		var dw := minf(5.0, w - t)
		var c := YELLOW
		if not on:
			c = INK
		_rect(parent, x + t, y, dw, h, c)
		t += 5.0
		on = not on


static func _cable_h(parent: Node2D, x: float, y: float, length: float) -> void:
	_rect(parent, x, y + 1.0, length, 5.0, Color(0, 0, 0, 0.3))
	_rect(parent, x, y, length, 5.0, Color(0.07, 0.07, 0.08))
	_rect(parent, x, y + 2.0, length, 1.4, YELLOW)


static func _hangers(parent: Node2D, x: float, y: float, length: float) -> void:
	var t := 10.0
	while t < length:
		_rect(parent, x + t, y - 4.0, 1.5, 4.0, STEEL_DK)
		t += 36.0


static func _chevron(parent: Node2D, x: float, y: float, dir: float, color: Color) -> void:
	var pts := PackedVector2Array()
	if dir >= 0.0:
		pts.append(Vector2(x, y))
		pts.append(Vector2(x, y + 5.0))
		pts.append(Vector2(x + 4.5, y + 2.5))
	else:
		pts.append(Vector2(x, y + 2.5))
		pts.append(Vector2(x + 4.5, y))
		pts.append(Vector2(x + 4.5, y + 5.0))
	_poly(parent, pts, color)


static func _teeth(parent: Node2D, x: float, y: float, n: int, color: Color) -> void:
	for i in n:
		_rect(parent, x + float(i) * 5.0, y, 3.0, 4.0, color)


static func _brace(parent: Node2D, a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 2.0:
		return
	var n := Node2D.new()
	n.name = "br%d" % parent.get_child_count()
	n.position = a
	n.rotation = delta.angle()
	parent.add_child(n)
	var ht := thickness * 0.5
	_poly(n, PackedVector2Array([
		Vector2(0, -ht), Vector2(length, -ht), Vector2(length, ht), Vector2(0, ht),
	]), color)


static func _arm(parent: Node2D, origin: Vector2, angle_deg: float, length: float, thick: float, color: Color) -> Vector2:
	var dest := origin + Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg))) * length
	_brace(parent, origin, dest, thick, color)
	_ellipse(parent, origin.x, origin.y, thick * 0.9, thick * 0.9, _lighten(color, 0.08))
	_ellipse(parent, dest.x, dest.y, thick * 0.7, thick * 0.7, STEEL_DK)
	return dest
