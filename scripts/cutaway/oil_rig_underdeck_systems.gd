extends Node2D
class_name OilRigUnderdeckSystems
## OIL RIG: ALL-IN-ONE UNDERDECK / SUBMARINE SYSTEMS
## Godot 4.x — single-file integration module intended for Grok/Cursor.
##
## PURPOSE
## Draws and drives the lower section shown in the reference image:
## - central blue submarine hatch / launch bay (NOT a flotation tank)
## - left and right orange flotation pontoons with visible separation
## - steel keel, support braces, hazard markings, hydraulic tubes and service pipes
## - animated hatch opening/closing, submarine deployment/recovery, lights and water effects
## - upgrades, damage, repair, and costs charged to StationSim
##
## INTEGRATION NOTES
## 1. Add a Node2D named "UnderdeckSystems" to the existing station scene.
## 2. Attach this script. Set `art_width`, `deck_bottom_y`, and `system_scale` to
##    align it with the existing screenshot/art. The defaults assume a local canvas
##    roughly 1600x720 with the station centered around x=800.
## 3. Put this node BEHIND the main station art but IN FRONT of the water/background.
##    If your existing art already draws pontoons/hatch, disable those old drawings
##    to avoid duplicates. This script intentionally owns only the underside.
## 4. Call bind_sim() from the main scene, same pattern as EngineRoomStatus.
##    Scrap, electronics, and fuel_oil live on StationSim inventory. Hatch, launch,
##    and recovery power is a kW reservation on that power bus, not a local charge.
##
## MAIN PUBLIC METHODS
##   bind_sim(station_sim)
##   open_hatch()
##   close_hatch()
##   launch_sub()
##   recover_sub()
##   damage_hatch(amount)
##   repair_hatch(amount)
##   damage_pontoon(index, amount)
##   repair_pontoon(index, amount)
##   purchase_upgrade(upgrade_id)
##   get_system_status()
##
## SIGNALS
##   hatch_state_changed(is_open)
##   submarine_state_changed(state_name)
##   upgrade_purchased(upgrade_id, new_level)
##   system_damaged(system_id, damage_fraction)
##
## This is stylized game logic, not a realistic pressure-vessel or naval design.

signal hatch_state_changed(is_open: bool)
signal submarine_state_changed(state_name: String)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal system_damaged(system_id: String, damage_fraction: float)

enum HatchState { CLOSED, UNLOCKING, OPENING, OPEN, CLOSING, JAMMED }
enum SubState { DOCKED, PREPARING, DEPLOYING, AWAY, RETURNING, RECOVERING, DISABLED }

@export_group("Scene Fit")
@export var art_width: float = 1500.0
@export var deck_bottom_y: float = 520.0
@export var system_scale: float = 1.0
@export var draw_pontoons: bool = true
@export var draw_tubing: bool = true
@export var draw_submarine: bool = true
@export var animate_systems: bool = true
@export var start_hatch_open: bool = false

@export_group("Hatch Dimensions")
@export var hatch_width: float = 900.0
@export var hatch_height: float = 54.0
@export var hatch_open_distance: float = 76.0
@export var hatch_animation_speed: float = 1.0
@export var hatch_max_damage: float = 1.0

@export_group("Pontoon Layout")
@export var pontoon_count: int = 2
@export var pontoon_width: float = 240.0
@export var pontoon_height: float = 112.0
@export var pontoon_spacing_from_center: float = 615.0

@export_group("Gameplay / Resources")
# Costs only. Stock and bus power are StationSim. Fuel id is fuel_oil.
@export var sub_fuel_cost: float = 8.0
@export var launch_power_kw: float = 5.0
@export var hatch_power_kw: float = 3.0
@export var recovery_power_kw: float = 4.0
@export var repair_scrap_cost: int = 12
@export var allow_launch_only_when_hatch_open: bool = true

@export_group("Palette")
@export var steel_dark: Color = Color("#17394d")
@export var steel_mid: Color = Color("#465652")
@export var steel_light: Color = Color("#777c6d")
@export var steel_highlight: Color = Color("#a3a58d")
@export var orange_main: Color = Color("#e94d00")
@export var orange_shadow: Color = Color("#b93600")
@export var orange_highlight: Color = Color("#ff9c20")
@export var hazard_yellow: Color = Color("#f5bd24")
@export var pipe_blue: Color = Color("#3aa5d0")
@export var pipe_cyan: Color = Color("#4ce4e8")
@export var pipe_orange: Color = Color("#e77722")
@export var water_color: Color = Color("#3198c7")

var hatch_state: HatchState = HatchState.CLOSED
var sub_state: SubState = SubState.DOCKED
var hatch_damage: float = 0.0
var pontoon_damage: Array[float] = [0.0, 0.0]
var sim: StationSim
var upgrades: Dictionary = {
    "hatch_actuators": 0,
    "sub_bay": 0,
    "pontoons": 0,
    "pipe_insulation": 0,
    "pump_efficiency": 0,
    "sub_scanner": 0,
    "sub_battery": 0,
    "repair_bots": 0
}

var _hatch_progress: float = 0.0
var _sub_progress: float = 0.0
var _launch_target: String = ""
var _time: float = 0.0
var _warning_phase: float = 0.0
var _water_phase: float = 0.0
var _sub_offset: Vector2 = Vector2.ZERO
var _message: String = "SUB BAY READY"
var _last_error: String = ""

const UPGRADE_DATA := {
    "hatch_actuators": {"name": "Hatch Actuators", "max": 3, "scrap": 35, "electronics": 12, "desc": "Faster hatch cycles and improved jam resistance."},
    "sub_bay": {"name": "Sub Bay Expansion", "max": 3, "scrap": 50, "electronics": 15, "desc": "Improves recovery speed and adds service capacity."},
    "pontoons": {"name": "Reinforced Pontoons", "max": 4, "scrap": 45, "electronics": 4, "desc": "Raises buoyancy reserve and hull resilience."},
    "pipe_insulation": {"name": "Pipe Insulation", "max": 3, "scrap": 25, "electronics": 8, "desc": "Reduces utility losses from damaged lines."},
    "pump_efficiency": {"name": "High-Efficiency Pumps", "max": 3, "scrap": 30, "electronics": 10, "desc": "Reduces launch and recovery power costs."},
    "sub_scanner": {"name": "Deep-Sea Scanner", "max": 3, "scrap": 20, "electronics": 22, "desc": "Adds range and improves resource discovery."},
    "sub_battery": {"name": "Submarine Battery", "max": 3, "scrap": 24, "electronics": 18, "desc": "Increases sortie range and reserve power."},
    "repair_bots": {"name": "Underdeck Repair Drones", "max": 2, "scrap": 60, "electronics": 25, "desc": "Gradually repairs minor damage while powered."}
}

func _ready() -> void:
    pontoon_count = clampi(pontoon_count, 2, 2)
    pontoon_damage.resize(2)
    if start_hatch_open:
        hatch_state = HatchState.OPEN
        _hatch_progress = 1.0
    queue_redraw()

func bind_sim(sim_node: StationSim) -> void:
    sim = sim_node
    if sim and not sim.state_changed.is_connected(_on_sim_state):
        sim.state_changed.connect(_on_sim_state)
    queue_redraw()

func _on_sim_state() -> void:
    if sim != null and sim.sub != null and sim.sub.phase == SubVessel.Phase.DISABLED:
        if sub_state != SubState.DISABLED:
            sub_state = SubState.DISABLED
            _message = sim.sub.fail_reason if sim.sub.fail_reason != "" else "SUB DISABLED"
    queue_redraw()

func _amount(res_id: String) -> float:
    if sim == null:
        return 0.0
    return sim.inventory.get_amount(res_id)

func _station_generated_kw() -> float:
    if sim == null:
        return 0.0
    return sim.power.generated

func _station_power_fraction() -> float:
    var rated := StationSim.GENERATOR_RATED_KW
    if rated <= 0.0:
        return 0.0
    return clampf(_station_generated_kw() / rated, 0.0, 1.0)

## Validate then spend on StationSim. Local hatch/sub state changes only after true.
func _spend(costs: Dictionary, power_kw: float) -> bool:
    if sim == null:
        _last_error = "StationSim is not bound."
        return false
    if sim.try_spend(costs, power_kw):
        _last_error = ""
        return true
    _last_error = sim.last_action_reason
    if _last_error == "":
        _last_error = "StationSim refused the spend."
    return false

func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()
        return
    if not animate_systems:
        return
    advance_visual(delta)

## Hatch, sub, and repair-drone motion follow SimClock. Pause freezes them.
func advance_visual(delta: float) -> void:
    var step := _sim_delta(delta)
    if step <= 0.0:
        return
    _time += step
    _warning_phase = fmod(_warning_phase + step * 4.0, TAU)
    _water_phase = fmod(_water_phase + step * 0.8, TAU)
    _advance_hatch(step)
    _advance_sub(step)
    _run_passive_systems(step)
    queue_redraw()

func _sim_delta(delta: float) -> float:
    if sim != null and sim.clock != null:
        if sim.clock.paused:
            return 0.0
        return delta * sim.clock.speed
    return delta

func _draw() -> void:
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * system_scale)
    _draw_keel()
    if draw_tubing:
        _draw_tubes_and_pumps()
    if draw_pontoons:
        _draw_pontoon_pair()
    _draw_hatch_frame_and_door()
    _draw_hatch_mechanisms()
    if draw_submarine:
        _draw_submarine()
    _draw_system_lights()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_keel() -> void:
    var left := -art_width * 0.5
    var right := art_width * 0.5
    var y := deck_bottom_y
    # Narrow steel keel: deliberately not a solid orange underbody.
    draw_colored_polygon(PackedVector2Array([
        Vector2(left, y - 10), Vector2(right, y - 10),
        Vector2(right + 15, y + 12), Vector2(left - 15, y + 12)
    ]), steel_dark)
    draw_line(Vector2(left + 8, y - 7), Vector2(right - 8, y - 7), steel_light, 4.0)
    draw_line(Vector2(left + 20, y + 7), Vector2(right - 20, y + 7), Color("#0d2d3e"), 3.0)
    # Repeating keel plates and bolt heads.
    var x := left + 24.0
    while x < right - 20:
        draw_line(Vector2(x, y - 5), Vector2(x + 20, y - 5), steel_mid, 3.0)
        draw_circle(Vector2(x + 5, y - 13), 2.0, steel_highlight)
        x += 74.0

func _draw_hatch_frame_and_door() -> void:
    var w := hatch_width
    var h := hatch_height
    var x := -w * 0.5
    var y := deck_bottom_y + 4.0
    var travel := _hatch_progress * hatch_open_distance
    # Fixed outer steel frame and side rails.
    draw_rect(Rect2(x - 18, y - 3, w + 36, h + 22), steel_dark)
    draw_rect(Rect2(x - 10, y + 2, w + 20, h + 10), steel_light)
    draw_rect(Rect2(x - 3, y + 7, w + 6, h), Color("#253e48"))
    # Hatch door slides down/out of the aperture as it opens.
    if hatch_state != HatchState.OPEN and hatch_state != HatchState.JAMMED:
        var door_y := y + 7.0 + travel
        draw_rect(Rect2(x, door_y, w, h - 3), Color("#258fbd"))
        draw_rect(Rect2(x, door_y, w, 7), Color("#45b8da"))
        draw_line(Vector2(x + 8, door_y + h - 8), Vector2(x + w - 8, door_y + h - 8), Color("#1c6e97"), 3.0)
        _draw_hazard_stripes(x, door_y + h - 1, w, 9.0)
        # Door grip bars.
        for i in range(11):
            var gx := x + 32 + i * ((w - 64) / 10.0)
            draw_line(Vector2(gx, door_y + 17), Vector2(gx + 10, door_y + 17), Color("#b5e7e9"), 2.0)
    else:
        # Open bay: black aperture with depth rails and cyan guide lights.
        draw_rect(Rect2(x + 5, y + 8, w - 10, h - 1), Color("#071a25"))
        draw_line(Vector2(x + 15, y + 15), Vector2(x + w - 15, y + 15), pipe_cyan, 3.0)
        draw_line(Vector2(x + 15, y + h + 4), Vector2(x + w - 15, y + h + 4), pipe_blue, 3.0)
        for i in range(9):
            var gx := x + 30 + i * ((w - 60) / 8.0)
            draw_circle(Vector2(gx, y + 30), 3.0, pipe_cyan)
    # Four locking blocks and visible pressure-seal line.
    for side in [-1.0, 1.0]:
        var bx: float = x + (0.0 if float(side) < 0.0 else w) - 10.0
        for j in range(2):
            var by := y + 12 + j * 22
            draw_rect(Rect2(bx, by, 20, 10), steel_mid)
            draw_rect(Rect2(bx + 4, by + 2, 12, 3), hazard_yellow if hatch_state == HatchState.CLOSED else pipe_cyan)
    draw_line(Vector2(x - 2, y + 5), Vector2(x + w + 2, y + 5), Color("#b4d2c8"), 2.0)

func _draw_hazard_stripes(x: float, y: float, w: float, h: float) -> void:
    draw_rect(Rect2(x, y, w, h), Color("#1b3037"))
    var stripe_w := 20.0
    var sx := x
    while sx < x + w:
        draw_colored_polygon(PackedVector2Array([
            Vector2(sx, y + h), Vector2(sx + stripe_w * 0.55, y),
            Vector2(sx + stripe_w, y), Vector2(sx + stripe_w * 0.45, y + h)
        ]), hazard_yellow)
        sx += stripe_w * 1.8

func _draw_hatch_mechanisms() -> void:
    var x0 := -hatch_width * 0.5
    var y0 := deck_bottom_y + 2
    # Hydraulic actuators on either side of hatch.
    for side in [-1.0, 1.0]:
        var ax: float = float(side) * (hatch_width * 0.5 + 26.0)
        draw_line(Vector2(ax, y0 + 4), Vector2(ax, y0 + 44), steel_dark, 12.0)
        draw_line(Vector2(ax, y0 + 4), Vector2(ax, y0 + 44), steel_light, 5.0)
        draw_line(Vector2(ax, y0 + 22), Vector2(ax + float(side) * 24.0, y0 + 22 + _hatch_progress * 22), pipe_orange, 4.0)
        draw_circle(Vector2(ax, y0 + 4), 6.0, hazard_yellow)
        draw_circle(Vector2(ax, y0 + 4), 2.5, steel_dark)
    # Lock motors and cable trays.
    draw_rect(Rect2(x0 - 32, y0 + 12, 20, 18), steel_mid)
    draw_rect(Rect2(hatch_width * 0.5 + 12, y0 + 12, 20, 18), steel_mid)
    draw_line(Vector2(x0 - 24, y0 + 21), Vector2(x0 + 6, y0 + 21), pipe_orange, 3.0)
    draw_line(Vector2(hatch_width * 0.5 - 6, y0 + 21), Vector2(hatch_width * 0.5 + 22, y0 + 21), pipe_orange, 3.0)

func _draw_pontoon_pair() -> void:
    for i in range(2):
        var side := -1.0 if i == 0 else 1.0
        var cx := side * pontoon_spacing_from_center
        var top := deck_bottom_y + 17.0
        var h := pontoon_height * (1.0 + float(upgrades["pontoons"]) * 0.025)
        var w := pontoon_width * (1.0 + float(upgrades["pontoons"]) * 0.03)
        var half := w * 0.5
        var damage := pontoon_damage[i]
        var orange := orange_main.lerp(Color("#78331f"), damage * 0.7)
        # Braces are behind the float so the water and gaps remain visible.
        draw_line(Vector2(cx - half * 0.55, deck_bottom_y + 5), Vector2(cx - half * 0.42, top + h * 0.4), steel_dark, 11.0)
        draw_line(Vector2(cx - half * 0.55, deck_bottom_y + 5), Vector2(cx - half * 0.42, top + h * 0.4), steel_light, 4.0)
        draw_line(Vector2(cx + half * 0.55, deck_bottom_y + 5), Vector2(cx + half * 0.42, top + h * 0.4), steel_dark, 11.0)
        draw_line(Vector2(cx + half * 0.55, deck_bottom_y + 5), Vector2(cx + half * 0.42, top + h * 0.4), steel_light, 4.0)
        # Separate float body.
        draw_colored_polygon(PackedVector2Array([
            Vector2(cx - half, top), Vector2(cx + half, top),
            Vector2(cx + half - 5, top + h - 22),
            Vector2(cx + half * 0.62, top + h),
            Vector2(cx - half * 0.62, top + h),
            Vector2(cx - half + 5, top + h - 22)
        ]), orange)
        draw_colored_polygon(PackedVector2Array([
            Vector2(cx - half, top), Vector2(cx + half, top),
            Vector2(cx + half - 4, top + 13), Vector2(cx - half + 4, top + 13)
        ]), orange_highlight)
        draw_line(Vector2(cx - half + 7, top + 25), Vector2(cx + half - 7, top + 25), Color("#ff7808"), 5.0)
        draw_line(Vector2(cx - half + 5, top + h * 0.52), Vector2(cx + half - 5, top + h * 0.52), orange_shadow, 4.0)
        draw_line(Vector2(cx, top + h * 0.58), Vector2(cx, top + h - 15), orange_shadow, 3.0)
        for side2 in [-1.0, 1.0]:
            for ry in [top + 32.0, top + h * 0.46]:
                draw_circle(Vector2(cx + side2 * (half - 13), ry), 2.4, Color("#ffe4aa"))
        if damage > 0.0:
            draw_line(Vector2(cx - 18, top + 38), Vector2(cx - 4, top + 51), Color("#322c27"), 3.0)
            draw_line(Vector2(cx - 4, top + 51), Vector2(cx - 12, top + 64), Color("#322c27"), 3.0)
        # Mooring / ballast pipe coupling on inboard face.
        draw_rect(Rect2(cx - side * (half + 9) - 8, top + 39, 16, 20), steel_mid)
        draw_circle(Vector2(cx - side * (half + 9), top + 49), 5.0, pipe_blue)

func _draw_tubes_and_pumps() -> void:
    var y := deck_bottom_y + 29.0
    # Main cyan power/data conduit follows the keel and stops short of the hatch.
    var left := -art_width * 0.5 + 30
    var right := art_width * 0.5 - 30
    var hatch_l := -hatch_width * 0.5 - 30
    var hatch_r := hatch_width * 0.5 + 30
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(left, y), Vector2(hatch_l - 70, y),
        Vector2(hatch_l - 70, y + 16), Vector2(hatch_l, y + 16)
    ]), pipe_blue, 7.0)
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(hatch_r, y + 16), Vector2(hatch_r + 70, y + 16),
        Vector2(hatch_r + 70, y), Vector2(right, y)
    ]), pipe_blue, 7.0)
    # Orange hydraulic feed to both actuators.
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(-hatch_width * 0.5 - 80, y + 30),
        Vector2(-hatch_width * 0.5 - 80, y + 5),
        Vector2(-hatch_width * 0.5 - 26, y + 5)
    ]), pipe_orange, 5.0)
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(hatch_width * 0.5 + 26, y + 5),
        Vector2(hatch_width * 0.5 + 80, y + 5),
        Vector2(hatch_width * 0.5 + 80, y + 30)
    ]), pipe_orange, 5.0)
    # Pump stays on the port shoulder. The centerline is the sub drop path.
    var pump_x := -hatch_width * 0.5 - 120.0
    var pump_y := y + 36
    draw_rect(Rect2(pump_x - 32, pump_y - 13, 64, 28), steel_dark)
    draw_rect(Rect2(pump_x - 25, pump_y - 7, 50, 16), steel_mid)
    draw_circle(Vector2(pump_x, pump_y + 1), 6, pipe_cyan if _station_generated_kw() > 2.5 else Color("#ff4537"))
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(-hatch_width * 0.5 - 30, pump_y + 1),
        Vector2(-hatch_width * 0.5 - 65, pump_y + 1),
        Vector2(-hatch_width * 0.5 - 65, y + 30)
    ]), pipe_orange, 5.0)
    _draw_pipe_polyline(PackedVector2Array([
        Vector2(hatch_width * 0.5 + 30, pump_y + 1),
        Vector2(hatch_width * 0.5 + 65, pump_y + 1),
        Vector2(hatch_width * 0.5 + 65, y + 30)
    ]), pipe_orange, 5.0)
    # Small clamps on pipe runs.
    for px in range(int(left + 15), int(right - 10), 95):
        if abs(float(px)) > hatch_width * 0.5 + 110:
            draw_rect(Rect2(float(px) - 3, y - 7, 6, 14), steel_light)

func _draw_pipe_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
    if points.size() < 2:
        return
    draw_polyline(points, Color("#132f3d"), width + 4.0, true)
    draw_polyline(points, color, width, true)
    for i in range(points.size()):
        if i == 0 or i == points.size() - 1:
            draw_circle(points[i], width * 0.72, steel_light)
            draw_circle(points[i], width * 0.35, color)

func _draw_submarine() -> void:
    # A sealed hatch keeps the vehicle in the bay. It only enters the water
    # once the doors are open, so the closed plate matches the two-pod stamp.
    if sub_state == SubState.DOCKED and hatch_state != HatchState.OPEN:
        return
    var bay_x := 0.0
    var bay_top := deck_bottom_y + hatch_height + 28.0
    var visibility := 1.0
    if sub_state == SubState.DOCKED:
        _sub_offset = Vector2(0, 0)
    elif sub_state == SubState.PREPARING:
        _sub_offset = Vector2(0, sin(_time * 5.0) * 2.0)
    elif sub_state == SubState.DEPLOYING:
        _sub_offset = Vector2(0, _sub_progress * 170.0)
    elif sub_state == SubState.AWAY:
        visibility = 0.0
    elif sub_state == SubState.RETURNING:
        visibility = 0.0
    elif sub_state == SubState.RECOVERING:
        _sub_offset = Vector2(0, (1.0 - _sub_progress) * 170.0)
    elif sub_state == SubState.DISABLED:
        if sim != null and sim.sub != null and sim.sub.depth_m > 1.0:
            visibility = 0.0
        else:
            _sub_offset = Vector2.ZERO
    if visibility <= 0.0:
        return
    var center := Vector2(bay_x, bay_top + 26.0) + _sub_offset
    var w := 102.0 + float(upgrades["sub_bay"]) * 8.0
    # Sub shadow and compact autonomous vehicle silhouette.
    var shadow_center := center + Vector2(0, 17)
    draw_colored_polygon(PackedVector2Array([
        shadow_center + Vector2(-w * 0.58, 0),
        shadow_center + Vector2(-w * 0.42, -7),
        shadow_center + Vector2(w * 0.42, -7),
        shadow_center + Vector2(w * 0.58, 0),
        shadow_center + Vector2(w * 0.42, 7),
        shadow_center + Vector2(-w * 0.42, 7)
    ]), Color("#092f48"))
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-w * 0.5, 0), center + Vector2(-w * 0.34, -16),
        center + Vector2(w * 0.26, -16), center + Vector2(w * 0.5, -4),
        center + Vector2(w * 0.44, 13), center + Vector2(-w * 0.38, 13)
    ]), Color("#c2c8bf"))
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-w * 0.30, -12), center + Vector2(w * 0.24, -12),
        center + Vector2(w * 0.36, -4), center + Vector2(-w * 0.36, -4)
    ]), Color("#287fa5"))
    draw_rect(Rect2(center.x - 13, center.y - 12, 26, 7), pipe_cyan)
    draw_circle(center + Vector2(-w * 0.28, 5), 4, hazard_yellow)
    draw_circle(center + Vector2(w * 0.30, 5), 4, hazard_yellow)
    # Side thrusters and small manipulator arm.
    draw_rect(Rect2(center.x - w * 0.48, center.y + 2, 12, 8), steel_dark)
    draw_rect(Rect2(center.x + w * 0.36, center.y + 2, 12, 8), steel_dark)
    draw_line(center + Vector2(w * 0.22, 12), center + Vector2(w * 0.32, 24), steel_light, 3.0)
    draw_line(center + Vector2(w * 0.32, 24), center + Vector2(w * 0.42, 20), hazard_yellow, 2.0)

func _draw_system_lights() -> void:
    var y := deck_bottom_y + 5
    var blink := 0.5 + 0.5 * sin(_warning_phase)
    var hatch_light := pipe_cyan
    if hatch_state == HatchState.JAMMED or hatch_damage > 0.65:
        hatch_light = Color("#ff3e32").lerp(hazard_yellow, blink)
    elif hatch_state == HatchState.CLOSED:
        hatch_light = hazard_yellow
    draw_circle(Vector2(-hatch_width * 0.5 - 22, y), 5, hatch_light)
    draw_circle(Vector2(hatch_width * 0.5 + 22, y), 5, hatch_light)
    # Power bar sits beside the hatch, not across the launch opening.
    var bar_x := -hatch_width * 0.5 - 160.0
    draw_rect(Rect2(bar_x, deck_bottom_y + 22, 80, 5), steel_dark)
    draw_rect(Rect2(bar_x, deck_bottom_y + 22, 80.0 * _station_power_fraction(), 5), pipe_cyan)

func _advance_hatch(delta: float) -> void:
    var speed := hatch_animation_speed * (1.0 + float(upgrades["hatch_actuators"]) * 0.25)
    if hatch_state == HatchState.OPENING:
        _hatch_progress = minf(_hatch_progress + delta * speed * (1.0 - hatch_damage * 0.75), 1.0)
        if _hatch_progress >= 1.0:
            hatch_state = HatchState.OPEN
            hatch_state_changed.emit(true)
            _message = "HATCH OPEN — SUB BAY CLEAR"
    elif hatch_state == HatchState.CLOSING:
        _hatch_progress = maxf(_hatch_progress - delta * speed * (1.0 - hatch_damage * 0.75), 0.0)
        if _hatch_progress <= 0.0:
            hatch_state = HatchState.CLOSED
            hatch_state_changed.emit(false)
            _message = "HATCH SEALED"
    elif hatch_state == HatchState.UNLOCKING:
        _hatch_progress = minf(_hatch_progress + delta * speed * 0.35, 0.35)
        if _hatch_progress >= 0.35:
            hatch_state = HatchState.OPENING
    if hatch_state == HatchState.JAMMED and hatch_damage < 0.25:
        hatch_state = HatchState.CLOSED

func _advance_sub(delta: float) -> void:
    var speed := 0.45 + float(upgrades["sub_bay"]) * 0.12
    match sub_state:
        SubState.DOCKED:
            pass
        SubState.PREPARING:
            _sub_progress += delta * speed
            if _sub_progress >= 1.0:
                _sub_progress = 0.0
                sub_state = SubState.DEPLOYING
                submarine_state_changed.emit("deploying")
        SubState.DEPLOYING:
            _sub_progress += delta * speed
            if _sub_progress >= 1.0:
                _sub_progress = 0.0
                sub_state = SubState.AWAY
                _depart_mission()
                submarine_state_changed.emit("away")
                _message = "SUB DEPLOYED"
        SubState.AWAY:
            if sim != null and sim.sub != null and sim.sub.phase == SubVessel.Phase.SURFACE:
                _message = "SUB AT SURFACE — RECOVER"
        SubState.RETURNING:
            _sub_progress += delta * speed
            if _sub_progress >= 1.0:
                _sub_progress = 0.0
                sub_state = SubState.RECOVERING
                submarine_state_changed.emit("recovering")
        SubState.RECOVERING:
            _sub_progress += delta * speed
            if _sub_progress >= 1.0:
                _sub_progress = 0.0
                sub_state = SubState.DOCKED
                _finish_dock()
                submarine_state_changed.emit("docked")
        SubState.DISABLED:
            pass
        _:
            var _missing := sub_state
            push_error("Underdeck unhandled sub state")

func _run_passive_systems(delta: float) -> void:
    # Repair drones run only while the station bus is generating. They do not drain a private charge.
    if int(upgrades["repair_bots"]) <= 0:
        return
    if _station_generated_kw() <= 1.0:
        return
    hatch_damage = maxf(0.0, hatch_damage - delta * 0.002 * float(upgrades["repair_bots"]))
    for i in range(pontoon_damage.size()):
        pontoon_damage[i] = maxf(0.0, pontoon_damage[i] - delta * 0.001 * float(upgrades["repair_bots"]))

func open_hatch() -> bool:
    if hatch_state == HatchState.JAMMED:
        _last_error = "Hatch is jammed; repair it first."
        return false
    if hatch_state != HatchState.CLOSED:
        _last_error = "Hatch is not fully closed."
        return false
    if not _spend({}, hatch_power_kw):
        return false
    hatch_state = HatchState.UNLOCKING
    _message = "UNLOCKING HATCH"
    return true

func close_hatch() -> bool:
    if sub_state != SubState.DOCKED:
        _last_error = "Cannot close hatch while submarine is outside the bay."
        return false
    if hatch_state != HatchState.OPEN:
        _last_error = "Hatch is not fully open."
        return false
    if not _spend({}, hatch_power_kw):
        return false
    hatch_state = HatchState.CLOSING
    _message = "CLOSING HATCH"
    return true

func launch_sub() -> bool:
    if allow_launch_only_when_hatch_open and hatch_state != HatchState.OPEN:
        _last_error = "Open the hatch before launching the submarine."
        return false
    if sub_state != SubState.DOCKED:
        _last_error = "Submarine is not docked."
        return false
    var power_cost := launch_power_kw * (1.0 - float(upgrades["pump_efficiency"]) * 0.12)
    if power_cost < 0.0:
        power_cost = 0.0
    if sim != null:
        var target := sim.sub_default_target()
        if target == "":
            _last_error = "No deposit is available."
            return false
        if not sim.sub_can_depart(target):
            _last_error = sim.sub_fail_reason()
            return false
        _launch_target = target
    if not _spend({"fuel_oil": sub_fuel_cost}, power_cost):
        _launch_target = ""
        return false
    sub_state = SubState.PREPARING
    _sub_progress = 0.0
    submarine_state_changed.emit("preparing")
    _message = "SUB LAUNCH SEQUENCE"
    return true

func order_sub_return() -> bool:
    if sub_state != SubState.AWAY:
        _last_error = "Submarine is not away on a mission."
        return false
    if sim != null:
        sim.sub_order_return()
    sub_state = SubState.RETURNING
    _sub_progress = 0.0
    submarine_state_changed.emit("returning")
    _message = "SUB RETURNING"
    return true

func recover_sub() -> bool:
    if sub_state != SubState.AWAY and sub_state != SubState.RETURNING:
        _last_error = "Submarine is not in a recoverable state."
        return false
    if hatch_state != HatchState.OPEN:
        _last_error = "Open the hatch before recovering the submarine."
        return false
    if not _spend({}, recovery_power_kw):
        return false
    sub_state = SubState.RECOVERING
    _sub_progress = 0.0
    submarine_state_changed.emit("recovering")
    return true

func damage_hatch(amount: float) -> void:
    hatch_damage = clampf(hatch_damage + maxf(amount, 0.0), 0.0, hatch_max_damage)
    if hatch_damage >= 0.8:
        hatch_state = HatchState.JAMMED
        _message = "WARNING: HATCH JAMMED"
    system_damaged.emit("hatch", hatch_damage)
    queue_redraw()

func repair_hatch(amount: float = 0.25) -> bool:
    var cost := int(ceil(repair_scrap_cost * amount / 0.25))
    if not _spend({"scrap": cost}, 0.0):
        return false
    hatch_damage = maxf(0.0, hatch_damage - maxf(amount, 0.0))
    if hatch_state == HatchState.JAMMED and hatch_damage < 0.8:
        hatch_state = HatchState.CLOSED
        _hatch_progress = 0.0
    _message = "HATCH REPAIRED"
    queue_redraw()
    return true

func damage_pontoon(index: int, amount: float) -> void:
    if index < 0 or index >= pontoon_damage.size():
        return
    pontoon_damage[index] = clampf(pontoon_damage[index] + maxf(amount, 0.0), 0.0, 1.0)
    system_damaged.emit("pontoon_%d" % index, pontoon_damage[index])
    queue_redraw()

func repair_pontoon(index: int, amount: float = 0.25) -> bool:
    if index < 0 or index >= pontoon_damage.size():
        _last_error = "No pontoon at that index."
        return false
    var cost := int(ceil(repair_scrap_cost * amount / 0.25))
    if not _spend({"scrap": cost}, 0.0):
        return false
    pontoon_damage[index] = maxf(0.0, pontoon_damage[index] - maxf(amount, 0.0))
    queue_redraw()
    return true

func purchase_upgrade(upgrade_id: String) -> bool:
    if not UPGRADE_DATA.has(upgrade_id) or not upgrades.has(upgrade_id):
        _last_error = "Unknown upgrade: " + upgrade_id
        return false
    var data: Dictionary = UPGRADE_DATA[upgrade_id]
    var level := int(upgrades[upgrade_id])
    if level >= int(data["max"]):
        _last_error = "Upgrade is already at maximum level."
        return false
    var scrap_cost := int(data["scrap"]) * (level + 1)
    var electronics_cost := int(data["electronics"]) * (level + 1)
    if not _spend({"scrap": scrap_cost, "electronics": electronics_cost}, 0.0):
        return false
    upgrades[upgrade_id] = level + 1
    if sim != null and sim.sub != null and upgrade_id == "sub_battery":
        sim.sub.apply_battery_level(int(upgrades[upgrade_id]))
    if sim != null and sim.sub != null and upgrade_id == "sub_scanner":
        sim.sub.apply_scanner_level(int(upgrades[upgrade_id]))
    upgrade_purchased.emit(upgrade_id, int(upgrades[upgrade_id]))
    _message = str(data["name"]) + " upgraded to level " + str(upgrades[upgrade_id])
    queue_redraw()
    return true

func add_resources(scrap_amount: int = 0, electronics_amount: int = 0, fuel_amount: float = 0.0, power_amount: float = 0.0) -> void:
    if sim == null:
        _last_error = "StationSim is not bound; resources were not stored."
        return
    _last_error = ""
    if scrap_amount > 0:
        sim.inventory.transfer_in("scrap", float(scrap_amount))
    if electronics_amount > 0:
        sim.inventory.transfer_in("electronics", float(electronics_amount))
    if fuel_amount > 0.0:
        sim.inventory.transfer_in("fuel_oil", fuel_amount)
    if power_amount != 0.0:
        _last_error = "Station power is the live bus, not a deposit."
    sim.state_changed.emit()

func get_total_buoyancy_rating() -> float:
    var total := 0.0
    for d in pontoon_damage:
        total += (1.0 + float(upgrades["pontoons"]) * 0.15) * (1.0 - d * 0.75)
    return total

func get_sub_range_multiplier() -> float:
    return 1.0 + float(upgrades["sub_scanner"]) * 0.25 + float(upgrades["sub_battery"]) * 0.3

func _depart_mission() -> void:
    if sim == null or _launch_target == "":
        return
    var target := _launch_target
    _launch_target = ""
    if not sim.sub_depart(target):
        _message = sim.sub_fail_reason()

func _finish_dock() -> void:
    if sim == null:
        _message = "SUB RECOVERED"
        return
    var moved := sim.finish_recovery()
    if sim.sub.cargo_total() > 1e-6:
        _message = "DOCKED — CARGO WAITING (storage full)"
    elif moved.is_empty():
        _message = "SUB RECOVERED"
    else:
        _message = "SUB RECOVERED — CARGO UNLOADED"

func get_system_status() -> Dictionary:
    var depth_m := 0.0
    var battery_kwh := 0.0
    var hull := 100.0
    var sub_phase := "DOCKED"
    var sub_cargo := {}
    if sim != null and sim.sub != null:
        var st := sim.sub_status()
        depth_m = float(st.get("depth_m", 0.0))
        battery_kwh = float(st.get("battery_kwh", 0.0))
        hull = float(st.get("hull", 100.0))
        sub_phase = str(st.get("phase", "DOCKED"))
        sub_cargo = st.get("cargo", {})
    return {
        "hatch_state": HatchState.keys()[hatch_state],
        "hatch_progress": _hatch_progress,
        "hatch_damage": hatch_damage,
        "sub_state": SubState.keys()[sub_state],
        "sub_phase": sub_phase,
        "depth_m": depth_m,
        "battery_kwh": battery_kwh,
        "hull": hull,
        "sub_cargo": sub_cargo,
        "scrap": _amount("scrap"),
        "electronics": _amount("electronics"),
        "fuel_oil": _amount("fuel_oil"),
        "power_generated": _station_generated_kw(),
        "power_available_kw": 0.0 if sim == null else sim.power.available_kw(),
        "pontoon_damage": pontoon_damage.duplicate(),
        "buoyancy_rating": get_total_buoyancy_rating(),
        "sub_range_multiplier": get_sub_range_multiplier(),
        "upgrades": upgrades.duplicate(true),
        "message": _message,
        "last_error": _last_error
    }

func get_upgrade_catalog() -> Dictionary:
    return UPGRADE_DATA.duplicate(true)

func get_last_error() -> String:
    return _last_error

func get_status_message() -> String:
    return _message
