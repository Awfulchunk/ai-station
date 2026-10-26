extends Node
class_name EngineRoomStatus
## B2 power-plant readouts. Colors and needles follow StationSim.
## RUNNING / STRAINED / OFFLINE are derived from generator mode, fuel, and kW.

enum Visual { RUNNING, STRAINED, OFFLINE }

var sim: StationSim
var visual: Visual = Visual.OFFLINE
var _heat: Array[Polygon2D] = []
var _lamps: Array[Polygon2D] = []
var _bus: Array[Polygon2D] = []
var _fuel_root: Node2D
var _needle_kw: Polygon2D
var _needle_fuel: Polygon2D
var _kw_pivot: Vector2
var _kw_len: float
var _fuel_pivot: Vector2
var _fuel_len: float


func capture(host: Node2D) -> void:
	_heat = _polys(host.get_node_or_null("HeatGlow"))
	_lamps = _polys(host.get_node_or_null("StatusLamps"))
	_bus = _polys(host.get_node_or_null("BusGlow"))
	var fuel := host.get_node_or_null("FuelSystem")
	if fuel:
		_fuel_root = fuel.get_node_or_null("FuelFlow") as Node2D
	var gauges := host.get_node_or_null("Gauges")
	if gauges:
		_needle_kw = gauges.get_node_or_null("NeedleKw") as Polygon2D
		_needle_fuel = gauges.get_node_or_null("NeedleFuel") as Polygon2D
		_kw_pivot = _pivot_of(_needle_kw)
		_kw_len = _length_of(_needle_kw, _kw_pivot)
		_fuel_pivot = _pivot_of(_needle_fuel)
		_fuel_len = _length_of(_needle_fuel, _fuel_pivot)
	_paint()


func bind_sim(sim_node: StationSim) -> void:
	sim = sim_node
	if sim and not sim.state_changed.is_connected(_on_sim):
		sim.state_changed.connect(_on_sim)
	_on_sim()


func get_visual_status() -> String:
	return _visual_name(visual)


func get_engine_reading() -> Dictionary:
	var generated := 0.0
	var requested := 0.0
	var fuel := 0.0
	var mode := ""
	var condition := 0.0
	if sim:
		var snap: Dictionary = sim.snapshot()
		var info: Dictionary = sim.get_inspect("generator")
		generated = float(snap.get("power_generated", 0.0))
		requested = float(snap.get("power_requested", 0.0))
		fuel = float(snap.get("fuel_oil", 0.0))
		mode = str(info.get("mode", ""))
		condition = float(info.get("condition", 0.0))
	return {
		"status": get_visual_status(),
		"mode": mode,
		"condition": condition,
		"power_generated": generated,
		"power_requested": requested,
		"fuel_oil": fuel,
	}


func _on_sim() -> void:
	visual = _classify()
	_paint()


func _classify() -> Visual:
	if sim == null:
		return Visual.OFFLINE
	var info: Dictionary = sim.get_inspect("generator")
	var snap: Dictionary = sim.snapshot()
	var mode := str(info.get("mode", "OFF"))
	var generated := float(snap.get("power_generated", 0.0))
	var requested := float(snap.get("power_requested", 0.0))
	var fuel := float(snap.get("fuel_oil", 0.0))
	var condition := float(info.get("condition", 0.0))
	if mode == "OFF" or mode == "FAULTED" or mode == "DESTROYED":
		return Visual.OFFLINE
	if fuel <= 0.05 or generated <= 0.05:
		return Visual.OFFLINE
	if requested > generated + 0.05 or condition < 70.0 or mode == "STANDBY" or mode == "PAUSED":
		return Visual.STRAINED
	if mode == "RUNNING":
		return Visual.RUNNING
	return Visual.OFFLINE


func _paint() -> void:
	var load := 0.0
	var fuel_frac := 0.0
	if sim:
		var snap: Dictionary = sim.snapshot()
		var rated := StationSim.GENERATOR_RATED_KW
		if rated > 0.0:
			load = float(snap.get("power_generated", 0.0)) / rated
		var cap := float(sim.inventory.capacity.get("fuel_oil", 0.0))
		if cap > 0.0:
			fuel_frac = float(snap.get("fuel_oil", 0.0)) / cap
	var heat_color := Color(0.35, 0.16, 0.08, 0.05)
	var lamp_color := Color(0.18, 0.16, 0.14)
	var bus_color := Color(0.18, 0.24, 0.26)
	var fuel_modulate := Color(0.35, 0.32, 0.30)
	match visual:
		Visual.RUNNING:
			heat_color = Color(1.0, 0.46, 0.08, 0.20 + 0.28 * clampf(load, 0.0, 1.0))
			lamp_color = Color(0.25, 0.86, 0.38)
			bus_color = Color(0.35, 0.82, 0.86)
			fuel_modulate = Color(1, 1, 1, 1)
		Visual.STRAINED:
			heat_color = Color(1.0, 0.18, 0.06, 0.72)
			lamp_color = Color(0.92, 0.55, 0.12)
			bus_color = Color(0.86, 0.64, 0.14)
			fuel_modulate = Color(1, 1, 1, 1)
		Visual.OFFLINE:
			heat_color = Color(0.28, 0.14, 0.08, 0.06)
			lamp_color = Color(0.16, 0.14, 0.13)
			bus_color = Color(0.16, 0.20, 0.22)
			fuel_modulate = Color(0.28, 0.26, 0.24)
		_:
			var _missing := visual
			push_error("EngineRoomStatus unhandled visual")
	for poly in _heat:
		poly.color = heat_color
	for poly2 in _lamps:
		poly2.color = lamp_color
	for poly3 in _bus:
		poly3.color = bus_color
	if _fuel_root:
		_fuel_root.modulate = fuel_modulate
	_aim(_needle_kw, _kw_pivot, _kw_len, load)
	_aim(_needle_fuel, _fuel_pivot, _fuel_len, fuel_frac)


func _aim(needle: Polygon2D, pivot: Vector2, length: float, fraction: float) -> void:
	if needle == null or length <= 0.0:
		return
	var ang := deg_to_rad(lerpf(-140.0, -40.0, clampf(fraction, 0.0, 1.0)))
	var dir := Vector2(cos(ang), sin(ang))
	var side := Vector2(-dir.y, dir.x) * 0.7
	needle.polygon = PackedVector2Array([pivot + side, pivot + dir * length, pivot - side])


func _visual_name(which: Visual) -> String:
	match which:
		Visual.RUNNING:
			return "RUNNING"
		Visual.STRAINED:
			return "STRAINED"
		Visual.OFFLINE:
			return "OFFLINE"
		_:
			var _missing := which
			return "OFFLINE"


func _polys(node: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	if node == null:
		return out
	if node is Polygon2D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_polys(child))
	return out


func _pivot_of(needle: Polygon2D) -> Vector2:
	if needle == null or needle.polygon.size() < 1:
		return Vector2.ZERO
	return (needle.polygon[0] + needle.polygon[needle.polygon.size() - 1]) * 0.5


func _length_of(needle: Polygon2D, pivot: Vector2) -> float:
	if needle == null or needle.polygon.size() < 2:
		return 0.0
	return pivot.distance_to(needle.polygon[1])
