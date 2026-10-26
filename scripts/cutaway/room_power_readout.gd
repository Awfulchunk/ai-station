extends Node
class_name RoomPowerReadout
## Wall meter for one station module. Needle, bar, lamp, and optional glass
## follow StationSim. No painted digits and no second resource ledger.

enum Feed { LIVE, STARVED, IDLE }

var module_id: String = ""
var sim: StationSim
var _feed: Feed = Feed.IDLE
var _load: float = 0.0
var _fuel: float = 0.0
var _needle: Polygon2D
var _pivot: Vector2
var _length: float
var _fill: Polygon2D
var _bulb: Polygon2D
var _glass: Polygon2D
var _fuel_fill: Polygon2D
var _leds: Array[Polygon2D] = []


func _ready() -> void:
	var host := get_parent() as Node2D
	if host != null:
		capture(host)


func capture(host: Node2D) -> void:
	_needle = null
	_fill = null
	_bulb = null
	_glass = null
	_fuel_fill = null
	_leds = []
	var tap := _find(host, "BusTap")
	if tap != null:
		_needle = tap.get_node_or_null("NeedleLoad") as Polygon2D
		_pivot = _pivot_of(_needle)
		_length = _length_of(_needle, _pivot)
		_fill = tap.get_node_or_null("LoadFill") as Polygon2D
		var lamp := tap.get_node_or_null("LiveLamp")
		if lamp != null:
			_bulb = lamp.get_node_or_null("Bulb") as Polygon2D
	var glass := _find(host, "EnergyGlass")
	if glass is Polygon2D:
		_glass = glass
	var fuel := _find(host, "FuelFill")
	if fuel is Polygon2D:
		_fuel_fill = fuel
	var leds := _find(host, "CoreLeds")
	if leds != null:
		for child in leds.get_children():
			if child is Polygon2D:
				_leds.append(child)
	_paint()


func bind_sim(sim_node: StationSim) -> void:
	sim = sim_node
	if sim != null and not sim.state_changed.is_connected(_on_sim):
		sim.state_changed.connect(_on_sim)
	_on_sim()


func get_reading() -> Dictionary:
	return {
		"module": module_id,
		"feed": _feed_name(_feed),
		"load": _load,
		"fuel": _fuel,
	}


func bulb_color() -> Color:
	if _bulb == null:
		return Color(0, 0, 0, 0)
	return _bulb.color


func _on_sim() -> void:
	_sample()
	_paint()


func _sample() -> void:
	_load = 0.0
	_fuel = 0.0
	_feed = Feed.IDLE
	if sim == null:
		return
	var info: Dictionary = sim.get_inspect(module_id)
	if bool(info.has("error")):
		_feed = Feed.IDLE
		return
	var demand := float(info.get("power_demand", 0.0))
	var granted := float(info.get("power_granted", 0.0))
	if demand > 0.0:
		_load = clampf(granted / demand, 0.0, 1.0)
	var cap := float(sim.inventory.capacity.get("fuel_oil", 0.0))
	if cap > 0.0:
		_fuel = clampf(float(sim.snapshot().get("fuel_oil", 0.0)) / cap, 0.0, 1.0)
	_feed = _classify(str(info.get("mode", "OFF")), _load)


func _classify(mode: String, frac: float) -> Feed:
	match mode:
		"RUNNING":
			if frac >= 0.85:
				return Feed.LIVE
			return Feed.STARVED
		"STANDBY", "PAUSED":
			return Feed.STARVED
		"OFF", "FAULTED", "DESTROYED":
			return Feed.IDLE
		_:
			push_error("RoomPowerReadout unknown mode %s" % mode)
			return Feed.IDLE


func _paint() -> void:
	var colors := _colors(_feed)
	var lamp: Color = colors["lamp"]
	var bar: Color = colors["bar"]
	var glass: Color = colors["glass"]
	if _bulb != null:
		_bulb.color = lamp
	_paint_fill(_fill, _load if _feed != Feed.IDLE else 0.0, bar)
	_paint_fill(_fuel_fill, _fuel, Color(0.72, 0.40, 0.12))
	if _glass != null:
		_glass.color = glass
	_aim(_needle, _pivot, _length, _load)
	_paint_leds(lamp)


func _colors(feed: Feed) -> Dictionary:
	match feed:
		Feed.LIVE:
			return {
				"lamp": Color(0.25, 0.86, 0.38),
				"bar": Color(0.30, 0.82, 0.78),
				"glass": Color(0.35, 0.86, 0.95, 0.95),
			}
		Feed.STARVED:
			return {
				"lamp": Color(0.92, 0.62, 0.14),
				"bar": Color(0.86, 0.58, 0.16),
				"glass": Color(0.86, 0.58, 0.16, 0.95),
			}
		Feed.IDLE:
			return {
				"lamp": Color(0.16, 0.15, 0.14),
				"bar": Color(0.22, 0.24, 0.26),
				"glass": Color(0.10, 0.14, 0.18, 0.95),
			}
		_:
			var _missing := feed
			push_error("RoomPowerReadout unhandled feed")
			return {
				"lamp": Color(0.16, 0.15, 0.14),
				"bar": Color(0.22, 0.24, 0.26),
				"glass": Color(0.10, 0.14, 0.18, 0.95),
			}


func _paint_fill(poly: Polygon2D, frac: float, color: Color) -> void:
	if poly == null or not poly.has_meta("span"):
		return
	var box: Rect2 = poly.get_meta("span")
	var clamped := clampf(frac, 0.0, 1.0)
	var h := box.size.y * clamped
	if h < 0.8:
		poly.color = Color(color.r, color.g, color.b, 0.0)
		poly.polygon = PackedVector2Array([
			box.position, box.position, box.position,
		])
		return
	var y := box.position.y + box.size.y - h
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2(box.position.x, y),
		Vector2(box.position.x + box.size.x, y),
		Vector2(box.position.x + box.size.x, box.position.y + box.size.y),
		Vector2(box.position.x, box.position.y + box.size.y),
	])


func _paint_leds(on_color: Color) -> void:
	if _leds.is_empty():
		return
	var lit := 0
	if _feed != Feed.IDLE:
		lit = int(round(clampf(_load, 0.0, 1.0) * float(_leds.size())))
	var off := Color(0.10, 0.12, 0.13)
	for i in _leds.size():
		if i < lit:
			_leds[i].color = on_color
		else:
			_leds[i].color = off


func _aim(needle: Polygon2D, pivot: Vector2, length: float, fraction: float) -> void:
	if needle == null or length <= 0.0:
		return
	var ang := deg_to_rad(lerpf(-140.0, -40.0, clampf(fraction, 0.0, 1.0)))
	var dir := Vector2(cos(ang), sin(ang))
	var side := Vector2(-dir.y, dir.x) * 0.7
	needle.polygon = PackedVector2Array([pivot + side, pivot + dir * length, pivot - side])
	needle.color = Color(0.08, 0.08, 0.09)


func _feed_name(feed: Feed) -> String:
	match feed:
		Feed.LIVE:
			return "LIVE"
		Feed.STARVED:
			return "STARVED"
		Feed.IDLE:
			return "IDLE"
		_:
			var _missing := feed
			return "IDLE"


func _find(node: Node, node_name: String) -> Node:
	if node == null:
		return null
	if str(node.name) == node_name:
		return node
	for child in node.get_children():
		var found := _find(child, node_name)
		if found != null:
			return found
	return null


func _pivot_of(needle: Polygon2D) -> Vector2:
	if needle == null or needle.polygon.size() < 1:
		return Vector2.ZERO
	return (needle.polygon[0] + needle.polygon[needle.polygon.size() - 1]) * 0.5


func _length_of(needle: Polygon2D, pivot: Vector2) -> float:
	if needle == null or needle.polygon.size() < 2:
		return 0.0
	return pivot.distance_to(needle.polygon[1])
