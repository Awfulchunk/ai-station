extends Node2D
class_name InteriorBuilder
## PASS1 architectural shell + PASS2 equipment mount.
## Continuous cavity, two decks, thick bulkheads with hatches, steel cut rim.
## Machines are Polygon2D kits from EquipmentBuilder. No labels, no grid.

const EquipKit := preload("res://scripts/cutaway/equipment_builder.gd")

const CUT := Rect2(120, 268, 1360, 262)
const COLS := 6
const ROWS := 2

const ROOM_MAP := {
	"A2": "WaterIntakeRoom", "B2": "PowerRoom", "C2": "ServiceCorridor",
	"D2": "AICoreRoom", "E2": "RefineryRoom", "F2": "StorageRoom",
	"A3": "OceanIntake", "B3": "SubmarineBay", "C3": "ResourceSortingRoom",
	"D3": "BiologyRoom", "E3": "ProductReserves", "F3": "RecyclingRoom",
}

@onready var floors: Node2D = $Floors
@onready var bulkheads: Node2D = $Bulkheads
@onready var rooms: Node2D = $Rooms
@onready var cut_edges: Node2D = get_node_or_null("CutEdges")

func _ready() -> void:
	if cut_edges == null:
		cut_edges = Node2D.new()
		cut_edges.name = "CutEdges"
		add_child(cut_edges)
		move_child(cut_edges, 0)
	for n in [floors, bulkheads, rooms, cut_edges]:
		_clear(n)
	_build_cavity_and_depth()
	_build_cut_rim()
	_build_continuous_decks()
	_build_overhead_structure()
	_build_bulkheads()
	_build_room_details()
	EquipKit.build(self)
	print("InteriorBuilder PASS2 equipment mounted")

func _clear(n: Node2D) -> void:
	if n == null:
		return
	for c in n.get_children():
		c.queue_free()

func _cw() -> float:
	return CUT.size.x / float(COLS)

func _mid_y() -> float:
	return CUT.position.y + CUT.size.y * 0.5

func _build_cavity_and_depth() -> void:
	## One continuous rear volume — NOT twelve separate room boxes.
	var deep := Color(0.09, 0.11, 0.13)
	var mid := Color(0.14, 0.17, 0.20)
	var warm := Color(0.16, 0.15, 0.13)
	# Backplane
	_poly(cut_edges, "Cavity", [
		CUT.position, CUT.position + Vector2(CUT.size.x, 0),
		CUT.position + CUT.size, CUT.position + Vector2(0, CUT.size.y),
	], deep)
	# Upper rear wash. Y is absolute — do not add CUT.position on top of _mid_y().
	_poly(cut_edges, "UpperWash", [
		Vector2(CUT.position.x + 10, CUT.position.y + 8),
		Vector2(CUT.position.x + CUT.size.x - 10, CUT.position.y + 8),
		Vector2(CUT.position.x + CUT.size.x - 10, _mid_y() - 16),
		Vector2(CUT.position.x + 10, _mid_y() - 16),
	], mid)
	_poly(cut_edges, "LowerWash", [
		Vector2(CUT.position.x + 10, _mid_y() + 8),
		Vector2(CUT.position.x + CUT.size.x - 10, _mid_y() + 8),
		Vector2(CUT.position.x + CUT.size.x - 10, CUT.position.y + CUT.size.y - 12),
		Vector2(CUT.position.x + 10, CUT.position.y + CUT.size.y - 12),
	], warm)
	# Vertical structural ribs on rear wall (irregular spacing — not column grid)
	var rib_c := Color(0.20, 0.23, 0.26)
	var rib_xs := [180.0, 410.0, 700.0, 980.0, 1220.0, 1380.0]
	for i in rib_xs.size():
		var x: float = rib_xs[i]
		_poly(cut_edges, "Rib%d" % i, [
			Vector2(x, CUT.position.y + 10),
			Vector2(x + 5, CUT.position.y + 10),
			Vector2(x + 5, CUT.position.y + CUT.size.y - 12),
			Vector2(x, CUT.position.y + CUT.size.y - 12),
		], rib_c)

func _build_cut_rim() -> void:
	## Physical steel cut edge with thickness, ribs, bolts.
	var steel := Color(0.45, 0.46, 0.40)
	var lip := Color(0.28, 0.30, 0.28)
	var bolt := Color(0.78, 0.74, 0.55)
	var t := 10.0
	_poly(cut_edges, "RimT", [
		CUT.position, CUT.position + Vector2(CUT.size.x, 0),
		CUT.position + Vector2(CUT.size.x, t), CUT.position + Vector2(0, t),
	], steel)
	_poly(cut_edges, "RimB", [
		CUT.position + Vector2(0, CUT.size.y - t),
		CUT.position + Vector2(CUT.size.x, CUT.size.y - t),
		CUT.position + Vector2(CUT.size.x, CUT.size.y),
		CUT.position + Vector2(0, CUT.size.y),
	], steel)
	_poly(cut_edges, "RimL", [
		CUT.position, CUT.position + Vector2(t, 0),
		CUT.position + Vector2(t, CUT.size.y), CUT.position + Vector2(0, CUT.size.y),
	], steel)
	_poly(cut_edges, "RimR", [
		CUT.position + Vector2(CUT.size.x - t, 0),
		CUT.position + Vector2(CUT.size.x, 0),
		CUT.position + Vector2(CUT.size.x, CUT.size.y),
		CUT.position + Vector2(CUT.size.x - t, CUT.size.y),
	], steel)
	# Inner lip shadow (reads as wall thickness)
	_poly(cut_edges, "LipT", [
		CUT.position + Vector2(t, t),
		CUT.position + Vector2(CUT.size.x - t, t),
		CUT.position + Vector2(CUT.size.x - t, t + 6),
		CUT.position + Vector2(t, t + 6),
	], lip)
	_poly(cut_edges, "LipL", [
		CUT.position + Vector2(t, t),
		CUT.position + Vector2(t + 6, t),
		CUT.position + Vector2(t + 6, CUT.size.y - t),
		CUT.position + Vector2(t, CUT.size.y - t),
	], lip)
	# Bolts
	var i := 0
	var x := CUT.position.x + 18.0
	while x < CUT.position.x + CUT.size.x - 14:
		_poly(cut_edges, "BT%d" % i, [
			Vector2(x, CUT.position.y + 2), Vector2(x + 5, CUT.position.y + 2),
			Vector2(x + 5, CUT.position.y + 7), Vector2(x, CUT.position.y + 7),
		], bolt)
		_poly(cut_edges, "BB%d" % i, [
			Vector2(x, CUT.position.y + CUT.size.y - 7), Vector2(x + 5, CUT.position.y + CUT.size.y - 7),
			Vector2(x + 5, CUT.position.y + CUT.size.y - 2), Vector2(x, CUT.position.y + CUT.size.y - 2),
		], bolt)
		x += 48.0
		i += 1

func _build_continuous_decks() -> void:
	## Two full-span floor plates + mid beam — physical decks, not per-cell floors.
	var plate := Color(0.18, 0.20, 0.22)
	var plate_hi := Color(0.32, 0.36, 0.34)
	var beam := Color(0.42, 0.44, 0.40)
	var shadow := Color(0.05, 0.06, 0.07, 0.65)
	var mid := _mid_y()

	# Upper deck underside shadow
	_poly(floors, "UpperShadow", [
		Vector2(CUT.position.x + 12, mid - 18),
		Vector2(CUT.position.x + CUT.size.x - 12, mid - 18),
		Vector2(CUT.position.x + CUT.size.x - 12, mid - 10),
		Vector2(CUT.position.x + 12, mid - 10),
	], shadow)
	# Upper deck plate
	_poly(floors, "UpperDeck", [
		Vector2(CUT.position.x + 10, mid - 14),
		Vector2(CUT.position.x + CUT.size.x - 10, mid - 14),
		Vector2(CUT.position.x + CUT.size.x - 10, mid - 2),
		Vector2(CUT.position.x + 10, mid - 2),
	], plate)
	# Grate lines on upper deck
	var gx := CUT.position.x + 20.0
	var gi := 0
	while gx < CUT.position.x + CUT.size.x - 20:
		_poly(floors, "UG%d" % gi, [
			Vector2(gx, mid - 12), Vector2(gx + 2, mid - 12),
			Vector2(gx + 2, mid - 4), Vector2(gx, mid - 4),
		], plate_hi)
		gx += 22.0
		gi += 1
	# Thick mid beam (I-beam feel)
	_poly(floors, "MidBeam", [
		Vector2(CUT.position.x + 6, mid - 4),
		Vector2(CUT.position.x + CUT.size.x - 6, mid - 4),
		Vector2(CUT.position.x + CUT.size.x - 6, mid + 6),
		Vector2(CUT.position.x + 6, mid + 6),
	], beam)
	_poly(floors, "MidBeamWeb", [
		Vector2(CUT.position.x + 6, mid),
		Vector2(CUT.position.x + CUT.size.x - 6, mid),
		Vector2(CUT.position.x + CUT.size.x - 6, mid + 2),
		Vector2(CUT.position.x + 6, mid + 2),
	], Color(0.25, 0.27, 0.25))

	# Lower deck
	var by := CUT.position.y + CUT.size.y
	_poly(floors, "LowerShadow", [
		Vector2(CUT.position.x + 12, by - 22),
		Vector2(CUT.position.x + CUT.size.x - 12, by - 22),
		Vector2(CUT.position.x + CUT.size.x - 12, by - 14),
		Vector2(CUT.position.x + 12, by - 14),
	], shadow)
	_poly(floors, "LowerDeck", [
		Vector2(CUT.position.x + 10, by - 16),
		Vector2(CUT.position.x + CUT.size.x - 10, by - 16),
		Vector2(CUT.position.x + CUT.size.x - 10, by - 6),
		Vector2(CUT.position.x + 10, by - 6),
	], plate)
	gx = CUT.position.x + 24.0
	gi = 0
	while gx < CUT.position.x + CUT.size.x - 20:
		_poly(floors, "LG%d" % gi, [
			Vector2(gx, by - 14), Vector2(gx + 2, by - 14),
			Vector2(gx + 2, by - 8), Vector2(gx, by - 8),
		], plate_hi)
		gx += 26.0
		gi += 1

func _build_overhead_structure() -> void:
	## Cable trays + beams that span across rooms (breaks cell look).
	var tray := Color(0.24, 0.28, 0.30)
	var beam := Color(0.40, 0.43, 0.40)
	var light := Color(0.95, 0.88, 0.50, 0.9)
	var y0 := CUT.position.y + 14.0
	# Continuous cable tray upper
	_poly(floors, "CableTrayU", [
		Vector2(CUT.position.x + 16, y0),
		Vector2(CUT.position.x + CUT.size.x - 16, y0),
		Vector2(CUT.position.x + CUT.size.x - 16, y0 + 7),
		Vector2(CUT.position.x + 16, y0 + 7),
	], tray)
	# Cross beams at irregular intervals
	var spans := [250.0, 520.0, 780.0, 1050.0, 1320.0]
	for i in spans.size():
		var x: float = CUT.position.x + (spans[i] - CUT.position.x) if false else spans[i]
		_poly(floors, "XBeam%d" % i, [
			Vector2(x, CUT.position.y + 12),
			Vector2(x + 8, CUT.position.y + 12),
			Vector2(x + 8, _mid_y() - 14),
			Vector2(x, _mid_y() - 14),
		], beam)
	# Work lights (not labels)
	var lights := [200.0, 450.0, 700.0, 950.0, 1200.0, 1400.0]
	for i in lights.size():
		var lx: float = lights[i]
		_poly(floors, "WL%d" % i, [
			Vector2(lx, y0 + 1), Vector2(lx + 14, y0 + 1),
			Vector2(lx + 14, y0 + 6), Vector2(lx, y0 + 6),
		], light)
	# Lower deck cable tray
	var y1 := _mid_y() + 12.0
	_poly(floors, "CableTrayL", [
		Vector2(CUT.position.x + 16, y1),
		Vector2(CUT.position.x + CUT.size.x - 16, y1),
		Vector2(CUT.position.x + CUT.size.x - 16, y1 + 6),
		Vector2(CUT.position.x + 16, y1 + 6),
	], tray)

func _build_bulkheads() -> void:
	## Thick steel partitions with hatch openings — varied door heights/offsets.
	var steel := Color(0.36, 0.39, 0.37)
	var edge := Color(0.55, 0.58, 0.50)
	var dark := Color(0.12, 0.13, 0.14)
	var thick := 16.0
	var cw := _cw()
	# Door configs per bulkhead index 1..5: [door_h, offset_from_floor]
	var door_cfgs := [
		[78.0, 6.0], [64.0, 10.0], [72.0, 8.0], [80.0, 6.0], [68.0, 12.0],
	]
	for col in range(1, COLS):
		var x := CUT.position.x + col * cw - thick * 0.5
		var cfg: Array = door_cfgs[col - 1]
		# Upper
		_hatch_wall(bulkheads, "U%d" % col, x, CUT.position.y + 10, _mid_y() - 4, thick,
			cfg[0], cfg[1], steel, edge, dark, col % 2 == 0)
		# Lower — different door geometry
		_hatch_wall(bulkheads, "L%d" % col, x, _mid_y() + 6, CUT.position.y + CUT.size.y - 10, thick,
			cfg[0] - 8.0, cfg[1] + 4.0, steel, edge, dark, col % 2 == 1)

func _hatch_wall(parent: Node2D, name: String, x: float, y0: float, y1: float,
		thick: float, door_h: float, gap: float, steel: Color, edge: Color, dark: Color,
		swing_left: bool = true) -> void:
	var door_bot := y1 - gap
	var door_top := door_bot - door_h
	if door_top < y0 + 12:
		door_top = y0 + 12
	# Main wall above door
	_poly(parent, name + "_A", [
		Vector2(x, y0), Vector2(x + thick, y0),
		Vector2(x + thick, door_top), Vector2(x, door_top),
	], steel)
	# Sill
	_poly(parent, name + "_S", [
		Vector2(x, door_bot), Vector2(x + thick, door_bot),
		Vector2(x + thick, y1), Vector2(x, y1),
	], steel)
	# Doorway void already empty; add frame
	_poly(parent, name + "_FL", [
		Vector2(x, door_top), Vector2(x + 4, door_top),
		Vector2(x + 4, door_bot), Vector2(x, door_bot),
	], edge)
	_poly(parent, name + "_FR", [
		Vector2(x + thick - 4, door_top), Vector2(x + thick, door_top),
		Vector2(x + thick, door_bot), Vector2(x + thick - 4, door_bot),
	], edge)
	# Header bar
	_poly(parent, name + "_H", [
		Vector2(x, door_top), Vector2(x + thick, door_top),
		Vector2(x + thick, door_top + 5), Vector2(x, door_top + 5),
	], edge)
	# Dark recess just inside opening (depth)
	_poly(parent, name + "_D", [
		Vector2(x + 4, door_top + 5), Vector2(x + thick - 4, door_top + 5),
		Vector2(x + thick - 4, door_top + 9), Vector2(x + 4, door_top + 9),
	], dark)
	EquipKit.add_hatch_leaf(parent, name, x, door_top, door_bot, thick, swing_left)

func _build_room_details() -> void:
	## Per-bay details WITHOUT identical filled room boxes.
	## Uses RoomShell only for floor pad + subtle rear panel, heavily varied.
	var letters := "ABCDEF"
	# Color / depth variants so bays don't stamp identical
	var rears := [
		Color(0.17, 0.20, 0.23), Color(0.20, 0.18, 0.16), Color(0.15, 0.18, 0.20),
		Color(0.14, 0.20, 0.28), Color(0.18, 0.17, 0.15), Color(0.16, 0.18, 0.17),
	]
	for col in range(COLS):
		for row_i in range(ROWS):
			var grid := "%s%d" % [letters[col], row_i + 2]
			var cw := _cw()
			var x0 := CUT.position.x + col * cw + 14
			var x1 := CUT.position.x + (col + 1) * cw - 14
			var y0: float
			var y1: float
			if row_i == 0:
				y0 = CUT.position.y + 18
				y1 = _mid_y() - 16
			else:
				y0 = _mid_y() + 14
				y1 = CUT.position.y + CUT.size.y - 18
			var shell := RoomShell.new()
			shell.name = ROOM_MAP.get(grid, "Room_%s" % grid)
			shell.position = Vector2(x0, y0)
			shell.room_size = Vector2(x1 - x0, y1 - y0)
			shell.rear_color = rears[col]
			shell.floor_color = Color(0.12, 0.14, 0.16)
			shell.steel_color = Color(0.32, 0.36, 0.38)
			shell.floor_thickness = 8.0
			shell.show_work_light = (col + row_i) % 2 == 0
			# Skip default full rear fill looking like boxes — use thinner panel
			rooms.add_child(shell)

func _poly(parent: Node2D, name: String, pts: Array, color: Color) -> void:
	var p := Polygon2D.new()
	p.name = name
	p.color = color
	var arr := PackedVector2Array()
	for pt in pts:
		arr.append(pt as Vector2)
	p.polygon = arr
	parent.add_child(p)
