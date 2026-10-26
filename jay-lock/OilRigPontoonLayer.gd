@tool
extends Node2D
class_name OilRigPontoonLayer
## Oil Rig visual integration pass — Godot 4.x
## Attach this Node2D beneath the existing station's hull/keel layer.
## Coordinates are local to the station artwork. Tune `rig_width` and `keel_y`
## to match the current scene. This script draws ONLY the underside supports,
## keel details, and five separated orange flotation pontoons; it does not redraw
## the station, rooms, water, HUD, or AI core.
##
## IMPORTANT INTEGRATION:
## 1. Add a Node2D named PontoonLayer directly under the existing station art.
## 2. Attach this script to PontoonLayer.
## 3. Disable/remove the old continuous orange underside hull drawing so it
##    does not overlap these separate pontoons.
## 4. Keep the existing water/background behind this layer.
## 5. Set rig_width / keel_y / pontoon_count / pontoon_gap in the Inspector.
##
## Gameplay API:
##   set_pontoon_damage(index, 0.0 .. 1.0)
##   repair_pontoon(index, amount)
##   upgrade_pontoons(level)
##   get_total_buoyancy()
##   get_pontoon_status()
##
## The art is intentionally made from simple polygons/lines so it is cheap to
## render, easy to recolor, and easy to replace with sprites later.

@export_group("Fit to Existing Rig")
@export var rig_width: float = 1500.0
@export var keel_y: float = 525.0
@export var pontoon_count: int = 5
@export var pontoon_gap: float = 62.0
@export var pontoon_width: float = 240.0
@export var pontoon_height: float = 112.0
@export var show_mounting_braces: bool = true
@export var show_keel_detail: bool = true
@export var show_sub_drop_hatch: bool = true
@export var hatch_gap: float = 420.0

@export_group("Palette")
@export var steel_dark: Color = Color("#183c50")
@export var steel_mid: Color = Color("#344c51")
@export var steel_light: Color = Color("#687166")
@export var orange_main: Color = Color("#e64b00")
@export var orange_shadow: Color = Color("#b93600")
@export var orange_highlight: Color = Color("#ff9b20")
@export var waterline_glow: Color = Color("#ff6a00")

@export_group("Simulation")
@export var buoyancy_per_pontoon: float = 100.0
@export var upgrade_level: int = 0
@export var animate_warning_lights: bool = true

var _damage: Array[float] = []
var _warning_phase: float = 0.0

func _ready() -> void:
    _resize_damage_array()
    queue_redraw()

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if animate_warning_lights:
        _warning_phase = fmod(_warning_phase + delta * 2.5, TAU)
        queue_redraw()

func _validate_property(_property: Dictionary) -> void:
    pontoon_count = clampi(pontoon_count, 1, 12)

func _notification(what: int) -> void:
    if what == NOTIFICATION_EDITOR_PRE_SAVE:
        _resize_damage_array()

func _resize_damage_array() -> void:
    while _damage.size() < pontoon_count:
        _damage.append(0.0)
    while _damage.size() > pontoon_count:
        _damage.pop_back()

func _draw() -> void:
    _resize_damage_array()
    var left := -rig_width * 0.5
    var right := rig_width * 0.5

    # A slim keel and dark under-deck shadow replace the old solid orange slab.
    draw_colored_polygon(PackedVector2Array([
        Vector2(left - 12, keel_y - 13),
        Vector2(right + 12, keel_y - 13),
        Vector2(right + 26, keel_y + 8),
        Vector2(left - 26, keel_y + 8)
    ]), steel_dark)
    draw_line(Vector2(left - 5, keel_y - 9), Vector2(right + 5, keel_y - 9), steel_light, 5.0)
    draw_line(Vector2(left, keel_y + 5), Vector2(right, keel_y + 5), Color("#0c2c3b"), 4.0)

    if show_keel_detail:
        _draw_keel_details(left, right)

    var centers: Array[float] = []
    if pontoon_count == 2 and show_sub_drop_hatch:
        # End pods only — wide clear middle for the sub drop hatch (Jay 2026-10-25).
        var half_span: float = rig_width * 0.5 - pontoon_width * 0.55
        centers = [-half_span, half_span]
    else:
        var total_width: float = float(pontoon_count) * pontoon_width + float(pontoon_count - 1) * pontoon_gap
        var start_x: float = -total_width * 0.5 + pontoon_width * 0.5
        for i in range(pontoon_count):
            centers.append(start_x + float(i) * (pontoon_width + pontoon_gap))
    for i in range(centers.size()):
        var x: float = centers[i]
        var damage: float = _damage[i] if i < _damage.size() else 0.0
        if show_mounting_braces:
            _draw_mounting_braces(x, damage)
        _draw_pontoon(x, i, damage)
    if show_sub_drop_hatch and centers.size() >= 2:
        _draw_sub_drop_hatch(centers)

func _draw_keel_details(left: float, right: float) -> void:
    # Repeated plates and fasteners add readable structure without costly art.
    var x := left + 22.0
    while x < right - 10.0:
        draw_line(Vector2(x, keel_y - 7), Vector2(x + 18, keel_y - 7), steel_mid, 3.0)
        draw_circle(Vector2(x + 7, keel_y - 15), 2.2, Color("#c3b58a"))
        x += 76.0

func _draw_mounting_braces(center_x: float, damage: float) -> void:
    var top_y := keel_y + 2.0
    var bottom_y := keel_y + pontoon_height * 0.38
    var brace_color := steel_mid.lerp(Color("#a64b25"), damage * 0.7)
    var half_span := pontoon_width * 0.34

    # Two visible legs leave the water/negative space visible between modules.
    draw_line(Vector2(center_x - half_span, top_y), Vector2(center_x - half_span * 0.72, bottom_y), steel_dark, 11.0)
    draw_line(Vector2(center_x - half_span, top_y), Vector2(center_x - half_span * 0.72, bottom_y), brace_color, 5.0)
    draw_line(Vector2(center_x + half_span, top_y), Vector2(center_x + half_span * 0.72, bottom_y), steel_dark, 11.0)
    draw_line(Vector2(center_x + half_span, top_y), Vector2(center_x + half_span * 0.72, bottom_y), brace_color, 5.0)

    # Cross brace.
    draw_line(Vector2(center_x - half_span * 0.86, top_y + 12), Vector2(center_x + half_span * 0.86, bottom_y - 4), steel_dark, 7.0)
    draw_line(Vector2(center_x - half_span * 0.86, top_y + 12), Vector2(center_x + half_span * 0.86, bottom_y - 4), steel_light, 2.0)

    # Bolted mounting shoes at the keel.
    for side_f in [-1.0, 1.0]:
        var side: float = float(side_f)
        var p := Vector2(center_x + side * half_span, top_y)
        draw_rect(Rect2(p.x - 8, p.y - 4, 16, 10), steel_dark)
        draw_circle(p + Vector2(0, 1), 2.5, Color("#d8c79b"))

func _draw_pontoon(center_x: float, index: int, damage: float) -> void:
    var w := pontoon_width * (1.0 + upgrade_level * 0.035)
    var h := pontoon_height * (1.0 + upgrade_level * 0.02)
    var top := keel_y + 12.0
    var bottom := top + h
    var half := w * 0.5
    var chipped := damage > 0.65
    var base_color := orange_main.lerp(Color("#71321f"), damage * 0.68)
    var shadow_color := orange_shadow.lerp(Color("#352d2a"), damage * 0.7)

    # Dark silhouette / drop shadow.
    draw_colored_polygon(PackedVector2Array([
        Vector2(center_x - half - 3, top + 4),
        Vector2(center_x + half + 3, top + 4),
        Vector2(center_x + half - 2, bottom - 13),
        Vector2(center_x + half * 0.62, bottom + 3),
        Vector2(center_x - half * 0.62, bottom + 3),
        Vector2(center_x - half - 2, bottom - 13)
    ]), Color("#092d43"))

    # Main buoyancy body, with angled bow/stern corners.
    draw_colored_polygon(PackedVector2Array([
        Vector2(center_x - half, top),
        Vector2(center_x + half, top),
        Vector2(center_x + half - 5, bottom - 23),
        Vector2(center_x + half * 0.62, bottom),
        Vector2(center_x - half * 0.62, bottom),
        Vector2(center_x - half + 5, bottom - 23)
    ]), base_color)

    # Top cap and two horizontal welded seams.
    draw_colored_polygon(PackedVector2Array([
        Vector2(center_x - half, top),
        Vector2(center_x + half, top),
        Vector2(center_x + half - 5, top + 13),
        Vector2(center_x - half + 5, top + 13)
    ]), orange_highlight)
    draw_line(Vector2(center_x - half + 5, top + 24), Vector2(center_x + half - 5, top + 24), Color("#ff7a08"), 5.0)
    draw_line(Vector2(center_x - half + 8, top + h * 0.52), Vector2(center_x + half - 8, top + h * 0.52), shadow_color, 4.0)

    # End plate / inspection seam.
    draw_line(Vector2(center_x, top + h * 0.58), Vector2(center_x, bottom - 15), shadow_color, 3.0)

    # Rivets and mount identification marks.
    for side_f in [-1.0, 1.0]:
        var side: float = float(side_f)
        var rivet_x: float = center_x + side * (half - 13.0)
        for rivet_y in [top + 31.0, top + h * 0.46]:
            draw_circle(Vector2(rivet_x, rivet_y), 2.5, Color("#ffe0a0"))
            draw_circle(Vector2(rivet_x, rivet_y), 1.1, Color("#fff4cf"))

    # Small waterline mark and damage indicator.
    var blink := 0.5 + 0.5 * sin(_warning_phase + float(index))
    var lamp_color := Color("#5ce8e8") if damage < 0.4 else Color("#ffcf35").lerp(Color("#ff3828"), blink)
    draw_rect(Rect2(center_x - 8, top - 7, 16, 5), lamp_color)
    if damage > 0.0:
        draw_line(Vector2(center_x - half * 0.25, top + 38), Vector2(center_x - half * 0.12, top + 54), Color("#322c27"), 3.0)
        draw_line(Vector2(center_x - half * 0.12, top + 54), Vector2(center_x - half * 0.20, top + 68), Color("#322c27"), 2.0)
    if chipped:
        draw_colored_polygon(PackedVector2Array([
            Vector2(center_x + half - 9, top + 33),
            Vector2(center_x + half - 22, top + 43),
            Vector2(center_x + half - 9, top + 52)
        ]), Color("#382e29"))


func _draw_sub_drop_hatch(centers: Array[float]) -> void:
    ## Ocean-facing launch hatch between end pontoons — clear water hole for the mini-sub.
    var left_edge: float = centers[0] + pontoon_width * 0.5 + 24.0
    var right_edge: float = centers[centers.size() - 1] - pontoon_width * 0.5 - 24.0
    var hw: float = right_edge - left_edge
    if hw < hatch_gap * 0.5:
        var mid: float = (centers[0] + centers[centers.size() - 1]) * 0.5
        hw = maxf(hatch_gap, 280.0)
        left_edge = mid - hw * 0.5
        right_edge = mid + hw * 0.5
    var hx: float = left_edge
    var hy: float = keel_y - 8.0
    var hh: float = pontoon_height * 0.55
    draw_rect(Rect2(hx, keel_y - 12.0, hw, 22.0), Color("#0d2a38"))
    draw_rect(Rect2(hx + 6.0, hy, hw - 12.0, hh), Color("#0a2433"))
    draw_rect(Rect2(hx, hy, hw, 8.0), steel_mid)
    draw_rect(Rect2(hx, hy + hh - 8.0, hw, 8.0), steel_dark)
    draw_rect(Rect2(hx, hy, 10.0, hh), steel_mid)
    draw_rect(Rect2(hx + hw - 10.0, hy, 10.0, hh), steel_mid)
    var stripe_x: float = hx + 14.0
    while stripe_x < hx + hw - 14.0:
        draw_rect(Rect2(stripe_x, hy + 1.0, 12.0, 6.0), Color("#e8b52b"))
        draw_rect(Rect2(stripe_x, hy + hh - 7.0, 12.0, 6.0), Color("#e8b52b"))
        stripe_x += 22.0
    draw_rect(Rect2(hx + 14.0, hy + 12.0, hw - 28.0, hh - 24.0), Color("#278bbd"))
    draw_rect(Rect2(hx + 18.0, hy + 16.0, hw - 36.0, 6.0), Color("#4eb3d8"))
    draw_rect(Rect2(hx + 12.0, hy + 10.0, 22.0, hh - 20.0), Color("#4a524c"))
    draw_rect(Rect2(hx + hw - 34.0, hy + 10.0, 22.0, hh - 20.0), Color("#4a524c"))
    draw_rect(Rect2(hx + 14.0, hy + 12.0, 6.0, hh - 24.0), Color("#8e947e"))
    draw_rect(Rect2(hx + hw - 20.0, hy + 12.0, 6.0, hh - 24.0), Color("#8e947e"))
    draw_line(Vector2(hx + 28.0, hy + hh - 4.0), Vector2(hx + 40.0, keel_y + pontoon_height * 0.72), steel_dark, 4.0)
    draw_line(Vector2(hx + hw - 28.0, hy + hh - 4.0), Vector2(hx + hw - 40.0, keel_y + pontoon_height * 0.72), steel_dark, 4.0)

func set_pontoon_damage(index: int, amount: float) -> void:
    _resize_damage_array()
    if index < 0 or index >= _damage.size():
        push_warning("Pontoon index out of range: %s" % index)
        return
    _damage[index] = clampf(amount, 0.0, 1.0)
    queue_redraw()

func repair_pontoon(index: int, amount: float = 0.25) -> void:
    if index < 0 or index >= _damage.size():
        return
    _damage[index] = clampf(_damage[index] - maxf(amount, 0.0), 0.0, 1.0)
    queue_redraw()

func upgrade_pontoons(level: int) -> void:
    upgrade_level = clampi(level, 0, 10)
    queue_redraw()

func get_total_buoyancy() -> float:
    _resize_damage_array()
    var total := 0.0
    for damage in _damage:
        total += buoyancy_per_pontoon * (1.0 + upgrade_level * 0.12) * (1.0 - damage * 0.8)
    return total

func get_pontoon_status() -> Array[Dictionary]:
    _resize_damage_array()
    var status: Array[Dictionary] = []
    for i in range(_damage.size()):
        status.append({
            "index": i,
            "damage": _damage[i],
            "health_percent": int(round((1.0 - _damage[i]) * 100.0)),
            "buoyancy": buoyancy_per_pontoon * (1.0 + upgrade_level * 0.12) * (1.0 - _damage[i] * 0.8)
        })
    return status
