extends Node2D
class_name RoomShell
## Pack §5 — rear panel + steel floor pad. Avoid full opaque room-box look.

@export var room_size: Vector2 = Vector2(220, 130)
@export var steel_color: Color = Color(0.30, 0.36, 0.40)
@export var floor_color: Color = Color(0.14, 0.18, 0.21)
@export var rear_color: Color = Color(0.18, 0.22, 0.26)
@export var shadow_color: Color = Color(0.05, 0.06, 0.08, 0.45)
@export var floor_thickness: float = 8.0
@export var show_work_light: bool = true

func _ready() -> void:
	build_shell()

func build_shell() -> void:
	for c in get_children():
		c.queue_free()
	var w := room_size.x
	var h := room_size.y
	var ft := floor_thickness

	# Partial rear panel (not full-height opaque box) — leaves cavity depth visible
	var rear := Polygon2D.new()
	rear.name = "RearWall"
	rear.color = rear_color
	rear.polygon = PackedVector2Array([
		Vector2(4, 8),
		Vector2(w - 4, 8),
		Vector2(w - 4, h - ft - 4),
		Vector2(4, h - ft - 4),
	])
	# slight transparency so continuous cavity reads through
	rear.color = Color(rear_color.r, rear_color.g, rear_color.b, 0.55)
	add_child(rear)

	var shadow := Polygon2D.new()
	shadow.name = "ContactShadow"
	shadow.color = shadow_color
	shadow.polygon = PackedVector2Array([
		Vector2(6, h - ft - 12),
		Vector2(w - 6, h - ft - 12),
		Vector2(w - 6, h - ft),
		Vector2(6, h - ft),
	])
	add_child(shadow)

	var floor := Polygon2D.new()
	floor.name = "SteelFloor"
	floor.color = floor_color
	floor.polygon = PackedVector2Array([
		Vector2(0, h - ft),
		Vector2(w, h - ft),
		Vector2(w, h),
		Vector2(0, h),
	])
	add_child(floor)

	if show_work_light:
		var light := Polygon2D.new()
		light.name = "WorkLight"
		light.color = Color(0.95, 0.88, 0.55, 0.75)
		var lx := w * 0.5 - 5
		light.polygon = PackedVector2Array([
			Vector2(lx, 4), Vector2(lx + 10, 4),
			Vector2(lx + 10, 9), Vector2(lx, 9),
		])
		add_child(light)
