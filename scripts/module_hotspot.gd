extends Area2D
class_name ModuleHotspot
## Clickable module zone over the station plate.

signal hotspot_clicked(module_id: String)

@export var module_id: String = ""
@export var label_text: String = ""

var _hover: bool = false
var _highlight: Polygon2D

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	input_event.connect(_on_input)
	_ensure_highlight()

func setup(id: String, rect: Rect2, label: String = "") -> void:
	module_id = id
	label_text = label if label != "" else id
	position = Vector2.ZERO
	# Collision
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = rect.position + rect.size * 0.5
	add_child(cs)
	# Highlight overlay (hidden until hover)
	_highlight = Polygon2D.new()
	var r := Rect2(rect.position, rect.size)
	_highlight.polygon = PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
	_highlight.color = Color(0.2, 0.85, 1.0, 0.0)
	_highlight.z_index = 5
	add_child(_highlight)
	# Tiny label
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = rect.position + Vector2(4, 2)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 1, 0.75, 0.7))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 6
	add_child(lbl)

func _ensure_highlight() -> void:
	pass

func _on_enter() -> void:
	_hover = true
	if _highlight:
		_highlight.color = Color(0.2, 0.85, 1.0, 0.22)

func _on_exit() -> void:
	_hover = false
	if _highlight:
		_highlight.color = Color(0.2, 0.85, 1.0, 0.0)

func _on_input(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hotspot_clicked.emit(module_id)
