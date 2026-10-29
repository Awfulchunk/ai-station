extends Node2D
class_name PixelStation
## Small pixel sub-station. Rooms are not clickable. Lamps read the live bus.

const STATION_POS := Vector2(76, 14)
const VIEW_SCALE := 4.0

var _sim: StationSim
var _anchors: Dictionary = {}
var _built := false
var _time := 0.0
var _sub: Sprite2D
var _lamp: Sprite2D
var _rays: Sprite2D
var _reactor: Sprite2D
var _dish: Array[Sprite2D] = []
var _ports: Array[Dictionary] = []
var _swimmers: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _ore: Sprite2D
var _biomass: Sprite2D


func bind(sim: StationSim) -> void:
	_sim = sim
	if not sim.state_changed.is_connected(_on_sim):
		sim.state_changed.connect(_on_sim)
	_on_sim()


func _ready() -> void:
	var main := get_parent() as DeepMain
	if main != null and main.skips_boot():
		set_process(false)
		return
	scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	_built = true


func _build() -> void:
	var art := SpriteFactory.new().build()
	_anchors = art["anchors"]
	_add_sprite(art["water"], Vector2.ZERO, 0, false)
	_rays = _add_sprite(art["rays"], Vector2(40, 0), 1, false)
	_rays.modulate = Color(1, 1, 1, 0)
	_add_sprite(art["kelp"], Vector2(8, 62), 2, false)
	_add_sprite(art["kelp"], Vector2(372, 64), 2, false)
	var body := _add_sprite(art["station"], STATION_POS, 3, false)
	body.z_index = 3
	_reactor = _glow_at(_anchors["reactor"], Color("39e696"), 4)
	_lamp = _glow_at(_anchors["lamp"], Color("fff1b0"), 5)
	for port in _anchors["portholes"]:
		var glow := _glow_at(port["at"], port["color"], 4)
		_ports.append({"id": str(port["id"]), "node": glow, "color": port["color"]})
	for i in 2:
		var dish := _add_sprite(art["dish"][i], STATION_POS + _anchors["dish"], 6, false)
		_dish.append(dish)
	_sub = _add_sprite(art["sub"], STATION_POS + _anchors["sub_dock"], 5, false)
	_spawn_life(art)
	_ore = _crystal(Vector2(292, 90), Color("e0a040"))
	_biomass = _crystal(Vector2(248, 88), Color("3ddc8a"))


func _spawn_life(art: Dictionary) -> void:
	var specs: Array[Dictionary] = [
		{"tex": 0, "x": 20.0, "y": 28.0, "speed": 18.0, "amp": 1.5},
		{"tex": 0, "x": 340.0, "y": 22.0, "speed": -14.0, "amp": 1.2},
		{"tex": 1, "x": 48.0, "y": 78.0, "speed": 12.0, "amp": 2.0},
		{"tex": 2, "x": 300.0, "y": 36.0, "speed": -16.0, "amp": 1.0},
		{"tex": 3, "x": 24.0, "y": 70.0, "speed": 8.0, "amp": 1.4},
		{"tex": 1, "x": 180.0, "y": 18.0, "speed": 10.0, "amp": 1.0},
	]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var spr := _add_sprite(art["fish"][int(spec["tex"])], Vector2(spec["x"], spec["y"]), 2, false)
		if int(spec["speed"]) < 0:
			spr.flip_h = true
		_swimmers.append({
			"node": spr,
			"x": float(spec["x"]),
			"y": float(spec["y"]),
			"speed": float(spec["speed"]),
			"amp": float(spec["amp"]),
			"phase": float(i) * 1.3,
		})
	for i in 2:
		var jelly := _add_sprite(art["jelly"], Vector2(40 + i * 300, 40), 2, false)
		_swimmers.append({
			"node": jelly,
			"x": 40.0 + float(i) * 300.0,
			"y": 44.0,
			"speed": 4.0,
			"amp": 2.5,
			"phase": float(i),
		})
	for i in 7:
		var bub := _add_sprite(art["bubble"], Vector2(120, 70), 6, false)
		_bubbles.append({
			"node": bub,
			"x": 130.0 + float(i) * 14.0,
			"y": 20.0 + float((i * 17) % 70),
			"speed": 10.0 + float(i % 3) * 4.0,
		})


func _add_sprite(tex: ImageTexture, at: Vector2, z: int, centered: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = centered
	spr.position = at
	spr.z_index = z
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	return spr


func _glow_at(local_at: Vector2, color: Color, z: int) -> Sprite2D:
	var tex := SpriteFactory.new()._tex(SpriteFactory.new()._glow(color))
	var spr := _add_sprite(tex, STATION_POS + local_at, z, true)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = mat
	spr.modulate = color
	return spr


func _crystal(at: Vector2, color: Color) -> Sprite2D:
	var img := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var factory := SpriteFactory.new()
	factory._stamp(img, Vector2i(1, 0), [".c.", "ccc", "ccc", ".c."], {"c": color})
	return _add_sprite(factory._tex(img), at, 2, false)


func _process(delta: float) -> void:
	if not _built:
		return
	_time += delta
	for item in _swimmers:
		var spr: Sprite2D = item["node"]
		var x := float(item["x"]) + float(item["speed"]) * delta
		if x > 410.0:
			x = -18.0
		elif x < -24.0:
			x = 404.0
		item["x"] = x
		var y := float(item["y"]) + sin(_time * 2.0 + float(item["phase"])) * float(item["amp"])
		spr.position = Vector2(roundf(x), roundf(y))
	for item in _bubbles:
		var bub: Sprite2D = item["node"]
		var y: float = float(item["y"]) - float(item["speed"]) * delta
		if y < 4.0:
			y = 78.0
		item["y"] = y
		bub.position = Vector2(roundf(float(item["x"])), roundf(y))
		bub.modulate.a = 0.75
	if _dish.size() == 2:
		var frame := int(_time * 2.0) % 2
		_dish[0].visible = frame == 0
		_dish[1].visible = frame == 1
	_place_sub()
	_pulse()


func _on_sim() -> void:
	_place_sub()
	_pulse()


func _place_sub() -> void:
	if _sub == null:
		return
	var dock: Vector2 = STATION_POS + _anchors.get("sub_dock", Vector2(174, 38))
	if _sim == null:
		_sub.position = dock
		return
	var depth := _sim.sub.depth_m
	var phase := _sim.sub.phase
	var pos := dock
	match phase:
		SubVessel.Phase.DOCKED:
			pos = dock
			_sub.modulate = Color.WHITE
		SubVessel.Phase.SURFACE:
			pos = dock + Vector2(18, 16)
			_sub.modulate = Color.WHITE
		SubVessel.Phase.TRAVEL, SubVessel.Phase.MINE, SubVessel.Phase.RETURN:
			var t := clampf(depth / 90.0, 0.0, 1.0)
			pos = dock + Vector2(22.0 + t * 62.0, 14.0 + t * 28.0)
			_sub.modulate = Color.WHITE
		SubVessel.Phase.DISABLED:
			var sunk := clampf(depth / 90.0, 0.0, 1.0)
			pos = dock + Vector2(22.0 + sunk * 62.0, 14.0 + sunk * 28.0)
			_sub.modulate = Color(0.55, 0.4, 0.4)
		_:
			var _missing := phase
			push_error("PixelStation unhandled sub phase")
			pos = dock
	_sub.position = Vector2(roundf(pos.x), roundf(pos.y))


func _pulse() -> void:
	if _sim == null or _lamp == null:
		return
	var lights: StationModule = _sim.modules["exterior_lights"]
	var on := lights.mode == StationModule.Mode.RUNNING and lights.power_granted + 1e-6 >= lights.power_demand
	var starved := lights.mode == StationModule.Mode.RUNNING and not on
	_lamp.modulate = Color("fff1b0") if on else (Color("803030") if starved else Color(1, 1, 1, 0))
	_rays.modulate.a = 0.85 if on else 0.0
	var gen := clampf(_sim.power.generated / StationSim.GENERATOR_RATED_KW, 0.0, 1.0)
	_reactor.modulate = Color(0.3, 1.0, 0.65, 0.25 + gen * 0.75)
	for port in _ports:
		var spr: Sprite2D = port["node"]
		var module_id := str(port["id"])
		var key := "life_support" if module_id == "life" else module_id
		if module_id == "energy":
			key = "exterior_lights"
		elif module_id == "sub_bay":
			key = "dock"
		elif module_id == "storage":
			key = "storage"
		elif module_id == "control":
			key = "ai_core"
		elif module_id == "mechanics":
			key = "processor"
		var granted := 0.0
		if _sim.modules.has(key):
			granted = _sim.modules[key].power_granted
		var lit := clampf(granted / 2.0, 0.15, 1.0) if granted > 0.05 else 0.12
		var col: Color = port["color"]
		spr.modulate = Color(col.r, col.g, col.b, lit)
	_paint_deposits()


func _paint_deposits() -> void:
	if _sim == null or _ore == null:
		return
	var ore_left := float(_sim.sub.nodes["shelf_ore"].get("remaining", 0.0))
	var bio_left := float(_sim.sub.nodes["shelf_biomass"].get("remaining", 0.0))
	_ore.modulate.a = 1.0 if ore_left > 0.5 else 0.25
	_biomass.modulate.a = 1.0 if bio_left > 0.5 else 0.25
