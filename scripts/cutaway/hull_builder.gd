extends Node2D
## Coherent oil-rig hull around the existing cutaway rooms.
## Polygon2D only. Does not draw exterior_with_hole.png or the front-wall photo.
## Rooms stay the foundation: CUT matches InteriorBuilder.

const CUT := Rect2(120, 268, 1360, 262)

const SKY_0 := Color("#3C8FCE")
const SKY_1 := Color("#62B0E3")
const SKY_2 := Color("#9DCEEE")
const SKY_3 := Color("#D7ECF8")
const HAZE := Color("#C5DDEA")
const CLOUD := Color("#F4F8FB")
const CLOUD_HI := Color("#FFFFFF")
const SEA_DEEP := Color("#0E4F86")
const SEA_MID := Color("#1A6EAB")
const SEA_TOP := Color("#2B8EC4")
const SEA_LIT := Color("#4AADD6")
const FOAM := Color("#E5F3F8")

const HULL := Color("#4A4E46")
const HULL_MID := Color("#5C6156")
const HULL_HI := Color("#8E8A74")
const HULL_EDGE := Color("#948F7A")
const HULL_DK := Color("#2A2E2A")
const HULL_RIVET := Color("#C6BEA2")

const ORANGE := Color("#FF6A00")
const ORANGE_HI := Color("#FF9A3C")
const ORANGE_DK := Color("#C24100")

const CRANE := Color("#E6A817")
const CRANE_HI := Color("#F6D36A")
const CRANE_DK := Color("#A87810")
const RED := Color("#E23B2F")

const TOWER := Color("#2A3038")
const TOWER_LT := Color("#5A636C")
const TOWER_DK := Color("#161A1E")

const DOME := Color("#C5CDD2")
const DOME_HI := Color("#F2F5F6")
const DOME_DK := Color("#7A848C")
const CORE := Color("#1E6FE0")
const CORE_HOT := Color("#7AE8FF")

const TANK := Color("#D5DADF")
const TANK_DK := Color("#8A949C")
const TANK_HI := Color("#F7FBFC")
const RAIL := Color("#D7C56A")
const PIPE := Color("#C9A24A")
const PIPE_C := Color("#3FCFE0")

var _n := 0

func _ready() -> void:
	var rig := get_parent() as Node2D
	if rig == null:
		push_error("HullBuilder: Exterior has no OilRig parent")
		return
	_build_sky(rig.get_node("Background/Sky") as Node2D)
	_build_ocean(rig.get_node("Background/Ocean") as Node2D)
	var plates := _layer(self, "HullPlates", 0)
	_build_lower_hull(plates)
	# Pontoons are owned by IntegratedRigLayer (separated pods). Do not draw the slab.
	_build_side_hulls(plates)
	_build_deck(plates)
	_build_bulkhead_caps(plates)
	var pipes := _layer(self, "HullPipes", 1)
	_build_exterior_pipes(pipes)
	var rails := _layer(self, "Railings", 2)
	_build_rails(rails)
	var cranes := get_node("Cranes") as Node2D
	cranes.z_index = 4
	_build_cranes(cranes)
	var towers := get_node("SignalTowers") as Node2D
	towers.z_index = 4
	_build_towers(towers)
	var dish := get_node("SatelliteDish") as Node2D
	dish.z_index = 4
	_build_dish(dish)
	var tanks := get_node("ProcessTanks") as Node2D
	tanks.z_index = 4
	_build_tanks(tanks)
	var dome := get_node("AICoreHousing") as Node2D
	dome.z_index = 5
	_build_dome(dome)
	_build_front_skin(rig.get_node("FrontWall") as Node2D)
	# InteriorBuilder clears its children in its own _ready, which runs after this
	# one. Weld the hull to the finished room block on the next idle call.
	call_deferred("_weld_to_rooms")
	print("HullBuilder coherent hull polygons=", _n, " silhouette_sprite=false")


func _layer(parent: Node2D, node_name: String, z: int) -> Node2D:
	var existing := parent.get_node_or_null(node_name)
	if existing:
		existing.free()
	var n := Node2D.new()
	n.name = node_name
	n.z_index = z
	parent.add_child(n)
	return n


func _poly(parent: Node2D, pts: PackedVector2Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = "P%d" % _n
	_n += 1
	p.antialiased = false
	p.polygon = pts
	p.color = color
	parent.add_child(p)


func _rect(parent: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	_poly(parent, PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h),
	]), color)


func _quad(parent: Node2D, a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_poly(parent, PackedVector2Array([a, b, c, d]), color)


func _ellipse(parent: Node2D, cx: float, cy: float, rx: float, ry: float, color: Color, segs: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var ang := TAU * float(i) / float(segs)
		pts.append(Vector2(cx + cos(ang) * rx, cy + sin(ang) * ry))
	_poly(parent, pts, color)


func _semi(parent: Node2D, cx: float, cy: float, rx: float, ry: float, color: Color, upper: bool) -> void:
	var pts := PackedVector2Array()
	var segs := 16
	for i in segs + 1:
		var t := float(i) / float(segs)
		var ang := (PI + PI * t) if upper else (PI * t)
		pts.append(Vector2(cx + cos(ang) * rx, cy + sin(ang) * ry))
	_poly(parent, pts, color)


func _beam(parent: Node2D, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.5:
		return
	var n := Vector2(-d.y, d.x) / length * (width * 0.5)
	_poly(parent, PackedVector2Array([a + n, b + n, b - n, a - n]), color)


func _left_outer(y: float) -> float:
	var t := clampf((y - 236.0) / 324.0, 0.0, 1.0)
	return lerpf(70.0, 28.0, t)


func _right_outer(y: float) -> float:
	var t := clampf((y - 236.0) / 324.0, 0.0, 1.0)
	return lerpf(1530.0, 1572.0, t)


func _build_sky(sky: Node2D) -> void:
	_rect(sky, 0, 0, 1600, 180, SKY_0)
	_rect(sky, 0, 180, 1600, 160, SKY_1)
	_rect(sky, 0, 340, 1600, 180, SKY_2)
	_rect(sky, 0, 520, 1600, 200, SKY_3)
	_rect(sky, 0, 548, 1600, 70, HAZE)
	_ellipse(sky, 1280, 78, 70, 70, Color("#F7E7B0"))
	_ellipse(sky, 1280, 78, 46, 46, Color("#FFF6D2"))
	_cloud(sky, 180, 70, 1.15)
	_cloud(sky, 520, 48, 0.85)
	_cloud(sky, 1040, 64, 1.05)
	_cloud(sky, 1488, 96, 0.7)
	_cloud(sky, 760, 36, 0.55)


func _cloud(parent: Node2D, cx: float, cy: float, scale: float) -> void:
	_ellipse(parent, cx, cy + 4.0 * scale, 48.0 * scale, 16.0 * scale, CLOUD)
	_ellipse(parent, cx - 32.0 * scale, cy + 6.0 * scale, 28.0 * scale, 13.0 * scale, CLOUD)
	_ellipse(parent, cx + 34.0 * scale, cy + 5.0 * scale, 26.0 * scale, 12.0 * scale, CLOUD)
	_ellipse(parent, cx - 6.0 * scale, cy - 6.0 * scale, 22.0 * scale, 12.0 * scale, CLOUD_HI)


func _build_ocean(sea: Node2D) -> void:
	# Sea rises to the hull flange so the open bays show water, not sky.
	_rect(sea, 0, 546, 1600, 70, Color("#0A3C62"))
	_rect(sea, 0, 600, 1600, 36, SEA_LIT)
	_rect(sea, 0, 628, 1600, 40, SEA_TOP)
	_rect(sea, 0, 660, 1600, 30, SEA_MID)
	_rect(sea, 0, 686, 1600, 34, SEA_DEEP)
	var i := 0
	while i < 22:
		var x := 16.0 + float(i) * 74.0
		var y := 606.0 + float(i % 3) * 16.0
		_ellipse(sea, x, y, 34.0, 5.0, FOAM, 10)
		_rect(sea, x - 28.0, y + 10.0, 50.0, 2.0, Color("#D0E6F0"))
		i += 1
	# Wake shadows under the five separated pods. Not a hull plate.
	for cx in [187.0, 494.0, 800.0, 1106.0, 1413.0]:
		_ellipse(sea, cx, 668.0, 70.0, 8.0, Color(0.04, 0.12, 0.18, 0.35), 10)


func _build_lower_hull(parent: Node2D) -> void:
	# Bottom flange of the deckhouse. Short, steel, welded to the cut sill.
	# Not a dark slab: below this the bays are open to sky and water.
	_quad(parent,
		Vector2(78, 524), Vector2(1522, 524),
		Vector2(1576, 548), Vector2(24, 548),
		HULL_MID)
	_rect(parent, 90, 524, 1420, 5, HULL_EDGE)
	# No full-width orange rub rail. Separated pods own the buoyancy line.
	var bolt := 48.0
	while bolt < 1560.0:
		_rect(parent, bolt, 534, 4, 4, HULL_RIVET)
		bolt += 28.0


func _build_side_hulls(parent: Node2D) -> void:
	# End bulkheads. Inner edge meets the cut rim; outer edge flares to the waterline.
	_quad(parent,
		Vector2(70, 236), Vector2(128, 236),
		Vector2(128, 560), Vector2(28, 560),
		HULL)
	_quad(parent,
		Vector2(1472, 236), Vector2(1530, 236),
		Vector2(1572, 560), Vector2(1472, 560),
		HULL)
	# Inner weld, same steel as the cut rim.
	_rect(parent, 116, 248, 12, 300, HULL_EDGE)
	_rect(parent, 1472, 248, 12, 300, HULL_EDGE)
	# Highlight on the outer top corner.
	_rect(parent, 74, 240, 48, 6, HULL_HI)
	_rect(parent, 1478, 240, 48, 6, HULL_HI)
	_side_detail(parent, true)
	_side_detail(parent, false)


func _side_detail(parent: Node2D, left: bool) -> void:
	var y := 268.0
	while y < 530.0:
		var x0: float
		var x1: float
		if left:
			x0 = _left_outer(y) + 8.0
			x1 = 116.0
		else:
			x0 = 1484.0
			x1 = _right_outer(y) - 8.0
		_rect(parent, x0, y, x1 - x0, 3.0, HULL_DK)
		y += 36.0
	# Floor lines leave the rooms and continue across the end bulkhead.
	_floor_stripe(parent, 393.0, 14.0, HULL_HI, left)
	_floor_stripe(parent, 512.0, 12.0, HULL_MID, left)
	var rivet_y := 300.0
	while rivet_y < 520.0:
		var rx: float = (_left_outer(rivet_y) + 18.0) if left else (_right_outer(rivet_y) - 22.0)
		_rect(parent, rx, rivet_y, 4, 4, HULL_RIVET)
		rivet_y += 28.0
	# External stair on the end wall.
	var step_y := 360.0
	var s := 0
	while step_y < 530.0:
		var sx: float = (_left_outer(step_y) - 16.0) if left else (_right_outer(step_y) + 2.0)
		_rect(parent, sx, step_y, 14, 3, HULL_HI)
		s += 1
		step_y += 16.0


func _floor_stripe(parent: Node2D, y: float, h: float, color: Color, left: bool) -> void:
	if left:
		var x0 := _left_outer(y) + 4.0
		_rect(parent, x0, y, 120.0 - x0, h, color)
	else:
		var x1 := _right_outer(y) - 4.0
		_rect(parent, 1480.0, y, x1 - 1480.0, h, color)


func _build_deck(parent: Node2D) -> void:
	# Weather deck sits on the room block. Its lower edge is covered by the cut rim.
	_rect(parent, 58, 228, 1484, 44, HULL_MID)
	_rect(parent, 58, 228, 1484, 6, HULL_HI)
	_rect(parent, 58, 262, 1484, 8, HULL_DK)
	var seam := 90.0
	while seam < 1520.0:
		_rect(parent, seam, 236, 2, 26, HULL_DK)
		_rect(parent, seam + 8.0, 240, 3, 3, HULL_RIVET)
		seam += 36.0
	# Winch houses tie the cranes into the deck.
	_house(parent, 196, 292, 188)
	_house(parent, 1360, 1436, 196)


func _house(parent: Node2D, x0: float, x1: float, y0: float) -> void:
	var w := x1 - x0
	_rect(parent, x0, y0, w, 248.0 - y0, HULL_DK)
	_rect(parent, x0, y0, w, 6, HULL_HI)
	_rect(parent, x0 + 8, y0 + 16, w - 22, 16, Color("#1C2428"))
	_rect(parent, x0 + 10, y0 + 18, w - 28, 5, Color("#67D0DC"))
	_rect(parent, x0 + w - 16, y0 + 8, 8, 28, CRANE_DK)
	_ellipse(parent, x0 + 16, y0 + 8, 4, 4, RED, 8)


func _build_bulkhead_caps(parent: Node2D) -> void:
	# Short pilasters where interior bulkheads meet the deck and the sill.
	var cw := CUT.size.x / 6.0
	for col in range(1, 6):
		var x := CUT.position.x + float(col) * cw - 8.0
		_rect(parent, x - 4.0, 214, 24, 28, HULL)
		_rect(parent, x - 4.0, 214, 24, 4, HULL_HI)
		_rect(parent, x - 6.0, 520, 28, 32, HULL)
		_rect(parent, x - 6.0, 520, 28, 4, HULL_EDGE)
		_rect(parent, x + 4.0, 526, 6, 22, HULL_DK)


func _build_exterior_pipes(parent: Node2D) -> void:
	# Deck mains. They stop at housings; they do not enter the cutaway.
	_rect(parent, 300, 242, 490, 6, PIPE)
	_rect(parent, 300, 242, 490, 2, CRANE_HI)
	_rect(parent, 1030, 240, 320, 6, PIPE_C)
	_rect(parent, 1030, 240, 320, 2, Color("#E8FFFF"))
	_rect(parent, 790, 236, 8, 22, PIPE)
	_rect(parent, 1022, 232, 8, 24, PIPE_C)
	# Intake riser on the port cheek, aimed at the water rooms.
	_rect(parent, 96, 300, 8, 230, Color("#2E6E86"))
	_rect(parent, 96, 300, 3, 230, Color("#7ED0DE"))
	_ellipse(parent, 100, 292, 7, 7, Color("#2E6E86"), 10)
	# Starboard product line down the end bulkhead.
	_rect(parent, 1496, 320, 7, 210, PIPE)
	_rect(parent, 1496, 320, 2, 210, CRANE_HI)


func _build_rails(parent: Node2D) -> void:
	_rect(parent, 70, 214, 1460, 3, RAIL)
	_rect(parent, 70, 224, 1460, 2, RAIL)
	var x := 78.0
	while x < 1520.0:
		_rect(parent, x, 214, 3, 22, HULL_HI)
		x += 22.0


func _build_cranes(parent: Node2D) -> void:
	_crane(parent, 148.0, -1.0, 126.0)
	_crane(parent, 1472.0, 1.0, 108.0)


func _crane(parent: Node2D, mast_x: float, facing: float, reach: float) -> void:
	var deck_y := 234.0
	_rect(parent, mast_x - 30.0, deck_y - 28.0, 60, 36, CRANE_DK)
	_rect(parent, mast_x - 30.0, deck_y - 28.0, 60, 5, CRANE_HI)
	_rect(parent, mast_x - 8.0, 30.0, 16, deck_y - 28.0, CRANE)
	_rect(parent, mast_x - 8.0, 30.0, 4, deck_y - 28.0, CRANE_HI)
	for band_y in [48.0, 92.0, 140.0, 186.0]:
		_rect(parent, mast_x - 10.0, band_y, 20, 7, RED)
	var cab_x := mast_x + (10.0 if facing > 0.0 else -40.0)
	_rect(parent, cab_x, deck_y - 70.0, 32, 26, CRANE_DK)
	_rect(parent, cab_x + 4.0, deck_y - 64.0, 20, 12, Color("#7ED4DE"))
	var root := Vector2(mast_x, 64.0)
	var tip := Vector2(mast_x + facing * reach, 46.0)
	_beam(parent, root, tip, 9.0, CRANE)
	_beam(parent, root + Vector2(0, 12), tip + Vector2(0, 10), 4.0, CRANE_DK)
	var step := 0
	while step <= 6:
		var t := float(step) / 6.0
		var p: Vector2 = root.lerp(tip, t)
		_beam(parent, p, p + Vector2(0.0, 12.0).lerp(Vector2(0.0, 10.0), t), 2.0, CRANE_HI)
		step += 1
	_beam(parent, Vector2(mast_x, 34.0), tip, 2.0, Color("#E6E2D4"))
	_beam(parent, tip, tip + Vector2(0, 78), 1.8, TOWER_DK)
	_rect(parent, tip.x - 6.0, tip.y + 76.0, 12, 8, CRANE_DK)
	var cw_x := mast_x - facing * 46.0
	_rect(parent, cw_x - 18.0, 78.0, 32, 16, TOWER)
	_rect(parent, cw_x - 18.0, 78.0, 32, 3, HULL_HI)
	_ellipse(parent, mast_x, 26.0, 5, 5, RED, 8)


func _build_towers(parent: Node2D) -> void:
	_tower(parent, 390.0, 22.0, 246.0, [46.0, 96.0, 150.0, 198.0])
	_tower(parent, 1310.0, 40.0, 246.0, [64.0, 118.0, 176.0])


func _tower(parent: Node2D, cx: float, top_y: float, base_y: float, bands: Array) -> void:
	var top_w := 16.0
	var base_w := 40.0
	_beam(parent,
		Vector2(cx - base_w * 0.5, base_y),
		Vector2(cx - top_w * 0.5, top_y),
		5.0, TOWER)
	_beam(parent,
		Vector2(cx + base_w * 0.5, base_y),
		Vector2(cx + top_w * 0.5, top_y),
		5.0, TOWER_LT)
	var y := base_y - 6.0
	var flip := false
	var span := base_y - top_y
	while y > top_y + 18.0:
		var y2 := maxf(y - 24.0, top_y)
		var half := lerpf(top_w, base_w, clampf((y - top_y) / span, 0.0, 1.0)) * 0.5
		var half2 := lerpf(top_w, base_w, clampf((y2 - top_y) / span, 0.0, 1.0)) * 0.5
		_beam(parent, Vector2(cx - half, y), Vector2(cx + half, y), 3.0, TOWER_LT)
		if flip:
			_beam(parent, Vector2(cx - half, y), Vector2(cx + half2, y2), 2.5, TOWER_DK)
		else:
			_beam(parent, Vector2(cx + half, y), Vector2(cx - half2, y2), 2.5, TOWER_DK)
		flip = not flip
		y = y2
	for band_y in bands:
		var by: float = band_y
		var half_b := lerpf(top_w, base_w, clampf((by - top_y) / (base_y - top_y), 0.0, 1.0)) * 0.5 + 3.0
		_rect(parent, cx - half_b, by, half_b * 2.0, 8.0, RED)
	_rect(parent, cx - 14.0, top_y + 36.0, 28, 4, HULL_HI)
	_rect(parent, cx - 11.0, 236.0, 22, 60, HULL_DK)
	_rect(parent, cx - 11.0, 236.0, 5, 60, HULL_HI)
	_rect(parent, cx - 2.0, top_y - 26.0, 4, 28, TOWER_LT)
	_ellipse(parent, cx, top_y - 28.0, 4, 4, RED, 8)
	_rect(parent, cx - 10.0, top_y - 8.0, 20, 3, TOWER_LT)


func _build_dish(parent: Node2D) -> void:
	var cx := 530.0
	_rect(parent, cx - 4.0, 150.0, 8, 146, TOWER)
	_rect(parent, cx - 16.0, 228.0, 32, 8, HULL_DK)
	_beam(parent, Vector2(cx, 210), Vector2(cx - 28, 242), 3.0, TOWER_LT)
	_beam(parent, Vector2(cx, 210), Vector2(cx + 28, 242), 3.0, TOWER_LT)
	# Bowl faces up-left. Outer rim, inner bowl, feed.
	_ellipse(parent, cx - 8.0, 132.0, 40, 28, Color("#B7C0C6"), 16)
	_ellipse(parent, cx - 14.0, 126.0, 28, 18, Color("#6E787E"), 14)
	_ellipse(parent, cx - 20.0, 120.0, 10, 6, Color("#D5DDE2"), 10)
	_beam(parent, Vector2(cx - 8.0, 132.0), Vector2(cx - 36.0, 104.0), 3.0, TOWER_LT)
	_ellipse(parent, cx - 38.0, 102.0, 4, 4, RED, 8)
	_rect(parent, cx - 2.0, 146.0, 18, 8, HULL_HI)


func _build_tanks(parent: Node2D) -> void:
	_tank(parent, 1076.0, 128.0, 54.0, 118.0)
	_tank(parent, 1152.0, 146.0, 50.0, 100.0)
	_tank(parent, 1224.0, 118.0, 56.0, 128.0)
	# Manifold tying the three heads back toward the dome.
	_rect(parent, 1088, 124, 176, 6, PIPE)
	_rect(parent, 1088, 124, 176, 2, CRANE_HI)
	# Skirts carry the tanks down into the refinery bay.
	_rect(parent, 1090, 236, 28, 64, TANK_DK)
	_rect(parent, 1164, 236, 26, 64, TANK_DK)
	_rect(parent, 1236, 236, 28, 64, TANK_DK)
	_rect(parent, 1096, 246, 8, 50, PIPE)
	_rect(parent, 1244, 246, 8, 50, PIPE_C)
	_rect(parent, 1100, 124, 5, 22, PIPE)
	_rect(parent, 1174, 124, 5, 36, PIPE)
	_rect(parent, 1248, 118, 5, 20, PIPE)


func _tank(parent: Node2D, x: float, y: float, w: float, h: float) -> void:
	_ellipse(parent, x + w * 0.5, y + h, w * 0.5, 8.0, TANK_DK, 12)
	_rect(parent, x, y, w, h, TANK)
	_rect(parent, x, y, 7, h, TANK_HI)
	_rect(parent, x + w - 8.0, y, 8, h, TANK_DK)
	_ellipse(parent, x + w * 0.5, y, w * 0.5, 9.0, TANK_HI, 12)
	_ellipse(parent, x + w * 0.5, y, w * 0.5 - 6.0, 5.0, Color("#8FD8E4"), 10)
	_rect(parent, x + 2.0, y + h * 0.45, w - 4.0, 6, Color("#B7C2C8"))
	_rect(parent, x + w - 10.0, y + 8.0, 3, h - 12.0, HULL_DK)
	var by := y + 14.0
	while by < y + h - 8.0:
		_rect(parent, x + w - 6.0, by, 5, 2, HULL_HI)
		by += 12.0


func _build_dome(parent: Node2D) -> void:
	var cx := 913.0
	# Plinth is the housing over the AI-core bay. Collar then shell.
	# Trunk drops through the deck into the AI-core bay so the dome is not sitting on a frame.
	_rect(parent, 804, 188, 218, 108, HULL_DK)
	_rect(parent, 804, 188, 218, 6, HULL_HI)
	_rect(parent, 818, 250, 10, 46, HULL)
	_rect(parent, 998, 250, 10, 46, HULL)
	_rect(parent, 904, 248, 18, 48, Color("#1A2830"))
	_rect(parent, 818, 206, 190, 22, Color("#1A242C"))
	var pane := 826.0
	while pane < 990.0:
		_rect(parent, pane, 210, 16, 12, Color("#12343C"))
		_rect(parent, pane + 2.0, 212, 6, 4, CORE_HOT)
		pane += 24.0
	_rect(parent, 836, 164, 154, 28, DOME_DK)
	_rect(parent, 836, 164, 154, 5, DOME_HI)
	_semi(parent, cx, 164.0, 104.0, 74.0, DOME, true)
	_beam(parent, Vector2(cx, 94), Vector2(836, 164), 3.0, DOME_DK)
	_beam(parent, Vector2(cx, 94), Vector2(990, 164), 3.0, DOME_DK)
	_beam(parent, Vector2(cx, 94), Vector2(860, 150), 2.0, DOME_DK)
	_beam(parent, Vector2(cx, 94), Vector2(966, 150), 2.0, DOME_DK)
	_ellipse(parent, cx, 126.0, 34, 34, DOME_DK, 16)
	_ellipse(parent, cx, 126.0, 26, 26, Color("#0E2A55"), 16)
	_ellipse(parent, cx, 126.0, 18, 18, CORE, 14)
	_ellipse(parent, cx, 126.0, 8, 8, CORE_HOT, 10)
	_rect(parent, cx - 22.0, 124, 44, 3, Color("#041018"))
	_rect(parent, cx - 1.5, 108, 3, 36, Color("#041018"))
	_ellipse(parent, cx - 28.0, 108.0, 14, 8, Color(1, 1, 1, 0.55), 8)
	_ellipse(parent, cx, 90.0, 5, 5, RED, 8)
	var bolt_x := 848.0
	while bolt_x < 980.0:
		_rect(parent, bolt_x, 172, 4, 4, HULL_RIVET)
		bolt_x += 16.0


func _weld_to_rooms() -> void:
	var rig := get_parent() as Node2D
	if rig == null:
		return
	# Draws over the cut rim so the room block is capped by the hull,
	# not outlined as its own panel. Stays clear of hatch openings.
	var weld := _layer(rig, "HullWeld", 3)
	_rect(weld, 104, 206, 34, 370, HULL)
	_rect(weld, 104, 206, 34, 8, HULL_HI)
	_rect(weld, 108, 214, 6, 340, HULL_EDGE)
	_rect(weld, 1462, 206, 34, 370, HULL)
	_rect(weld, 1462, 206, 34, 8, HULL_HI)
	_rect(weld, 1486, 214, 6, 340, HULL_EDGE)
	# Floor lines of the cut continue across the end posts.
	_rect(weld, 104, 392, 34, 12, HULL_HI)
	_rect(weld, 104, 508, 34, 10, HULL_EDGE)
	_rect(weld, 1462, 392, 34, 12, HULL_HI)
	_rect(weld, 1462, 508, 34, 10, HULL_EDGE)
	# Separate beam ends cross the cut. They are not a continuous picture frame.
	var x := 180.0
	while x < 1420.0:
		_rect(weld, x, 248, 10, 32, HULL_DK)
		_rect(weld, x, 248, 10, 4, HULL_HI)
		_rect(weld, x, 518, 10, 16, HULL)
		x += 72.0
	# Knee braces at the cut corners, outside the rooms.
	_beam(weld, Vector2(78, 250), Vector2(120, 300), 6.0, HULL_HI)
	_beam(weld, Vector2(78, 530), Vector2(120, 480), 6.0, HULL_HI)
	_beam(weld, Vector2(1522, 250), Vector2(1480, 300), 6.0, HULL_HI)
	_beam(weld, Vector2(1522, 530), Vector2(1480, 480), 6.0, HULL_HI)
	print("HullBuilder weld polygons=", _n)


func _build_front_skin(wall: Node2D) -> void:
	# Closed face for the cutaway toggle. Geometry, not the photo panel.
	var old := wall.get_node_or_null("FrontWallPanel")
	if old:
		old.free()
	var skin := _layer(wall, "FrontSkin", 0)
	var x0 := CUT.position.x
	var y0 := CUT.position.y
	var w := CUT.size.x
	var h := CUT.size.y
	_rect(skin, x0, y0, w, h, Color("#3C423C"))
	var cw := w / 6.0
	for i in 6:
		var x := x0 + float(i) * cw + 4.0
		_rect(skin, x, y0 + 10.0, cw - 10.0, h * 0.5 - 22.0, Color("#52584E"))
		_rect(skin, x, y0 + 10.0, cw - 10.0, 4.0, HULL_EDGE)
		_rect(skin, x, y0 + h * 0.5 + 10.0, cw - 10.0, h * 0.5 - 24.0, Color("#484E46"))
		_rect(skin, x, y0 + h * 0.5 + 10.0, cw - 10.0, 3.0, HULL_EDGE)
		_ellipse(skin, x + 28.0, y0 + 46.0, 9, 9, Color("#142026"), 10)
		_ellipse(skin, x + 28.0, y0 + 46.0, 5, 5, Color("#3D8EA8"), 8)
		_rect(skin, x + 8.0, y0 + h - 46.0, 36, 22, HULL_DK)
		_rect(skin, x + 8.0, y0 + h - 46.0, 36, 3, HULL_HI)
		var k := 0
		while k < 4:
			_rect(skin, x + 6.0 + float(k) * 16.0, y0 + 16.0, 3, 3, HULL_RIVET)
			k += 1
	_rect(skin, x0, y0 + h * 0.5 - 6.0, w, 12.0, HULL_EDGE)
	_rect(skin, x0, y0 + h - 8.0, w, 8.0, ORANGE)
	_rect(skin, x0, y0, w, 6.0, HULL_HI)
