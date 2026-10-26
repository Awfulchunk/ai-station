extends CanvasLayer
class_name HudInspect
## Live HUD only — binds to StationSim snapshot. No fake progress.

signal speed_changed(speed: float)
signal pause_toggled

@onready var inspect_panel: PanelContainer = $Root/InspectPanel
@onready var inspect_label: RichTextLabel = $Root/InspectPanel/Margin/VBox/InspectText
@onready var status_label: RichTextLabel = $Root/StatusBar/Margin/StatusText
@onready var title_label: Label = $Root/InspectPanel/Margin/VBox/Title

var _sim: StationSim
var _selected: String = "ai_core"

func bind_sim(sim: StationSim) -> void:
	_sim = sim
	_sim.state_changed.connect(_refresh)
	_refresh()

func show_module(module_id: String) -> void:
	_selected = module_id
	_refresh()

func _refresh() -> void:
	if _sim == null:
		return
	var snap := _sim.snapshot()
	var pause_s := "PAUSED" if snap["paused"] else "RUN"
	status_label.text = "[b]AI STATION[/b]  tick=%d  %s  speed=%.0fx\nPower  gen=%.1f  req=%.1f  granted=%.1f kW\nInv  biomass=%.0f  bio_nutrient=%.0f  waste=%.0f  fuel_oil=%.0f  sanity=%s" % [
		snap["tick"], pause_s, snap["speed"],
		snap["power_generated"], snap["power_requested"], snap["power_granted"],
		snap["biomass"], snap["bio_nutrient"], snap["waste"], snap["fuel_oil"],
		"OK" if snap["sanity_ok"] else "FAIL"
	]
	if snap["alerts"].size() > 0:
		status_label.text += "\n[color=yellow]ALERT: %s[/color]" % str(snap["alerts"][0])

	var info := _sim.get_inspect(_selected)
	title_label.text = "INSPECT — %s" % _selected
	inspect_label.text = "type: %s\nmode: [b]%s[/b]\ncondition: %.1f%%\npower demand: %.2f kW\npower granted: %.2f kW\npriority tier: %d\nblocked: %s\njob: %.1f / %.1f s\nrecipe: %s" % [
		info.get("type", "?"),
		info.get("mode", "?"),
		info.get("condition", 0.0),
		info.get("power_demand", 0.0),
		info.get("power_granted", 0.0),
		info.get("priority", 0),
		info.get("blocked_reason", "") if str(info.get("blocked_reason", "")) != "" else "(none)",
		info.get("job_progress", 0.0),
		info.get("job_duration", 0.0),
		info.get("recipe", "") if str(info.get("recipe", "")) != "" else "(none)",
	]

func _on_pause_pressed() -> void:
	pause_toggled.emit()

func _on_speed1() -> void:
	speed_changed.emit(1.0)

func _on_speed2() -> void:
	speed_changed.emit(2.0)

func _on_speed4() -> void:
	speed_changed.emit(4.0)
