extends CanvasLayer
class_name RoomHud
## Six room tabs. The station picture is not a control; this panel is.

signal speed_changed(speed: float)
signal pause_toggled

const ROOMS: Array[String] = ["energy", "control", "storage", "mechanics", "life", "sub_bay"]
const ROOM_LABELS: Dictionary = {
	"energy": "ENERGY",
	"control": "CONTROL",
	"storage": "STORAGE",
	"mechanics": "MECHANICS",
	"life": "LIFE SUPPORT",
	"sub_bay": "SUB BAY",
}

var _sim: StationSim
var _room := "energy"
var _tabs: Dictionary = {}
var _panels: Dictionary = {}
var _text: Dictionary = {}
var _action: Label
var _status: Label
var _monitors: Dictionary = {}
var _repair: Dictionary = {}
var _repair_note: Label
var _tab_on: StyleBoxFlat
var _tab_off: StyleBoxFlat
var _tab_hover: StyleBoxFlat


func bind(sim: StationSim) -> void:
	_sim = sim
	if not sim.state_changed.is_connected(_refresh):
		sim.state_changed.connect(_refresh)
	_build_repair_buttons()
	_refresh()


func show_room(room_id: String) -> void:
	if not _panels.has(room_id):
		return
	_room = room_id
	for id in _panels.keys():
		(_panels[id] as Control).visible = id == room_id
	_style_tabs()


func _ready() -> void:
	var main := get_parent() as DeepMain
	if main != null and main.skips_boot():
		return
	_build()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	var frame := Panel.new()
	frame.name = "ArtFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 8
	frame.offset_top = 52
	frame.offset_right = -8
	frame.offset_bottom = -328
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0, 0, 0, 0)
	frame_box.border_color = Color("e06a28")
	frame_box.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", frame_box)
	root.add_child(frame)

	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_top = 6
	top.offset_right = -10
	top.offset_bottom = 48
	root.add_child(top)
	var top_box := HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 10)
	top.add_child(top_box)
	var title := Label.new()
	title.text = "DEEP STATION"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffb15a"))
	top_box.add_child(title)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text = "booting"
	top_box.add_child(_status)
	top_box.add_child(_button("Pause", _on_pause))
	top_box.add_child(_button("1x", func(): speed_changed.emit(1.0)))
	top_box.add_child(_button("2x", func(): speed_changed.emit(2.0)))
	top_box.add_child(_button("4x", func(): speed_changed.emit(4.0)))

	var dock := PanelContainer.new()
	dock.name = "RoomDock"
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 10
	dock.offset_top = -324
	dock.offset_right = -10
	dock.offset_bottom = -8
	root.add_child(dock)
	var margin := MarginContainer.new()
	dock.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	for room_id in ROOMS:
		var tab := _button(str(ROOM_LABELS[room_id]), _show_room_id.bind(room_id))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_tabs[room_id] = tab

	var stack := Control.new()
	stack.name = "RoomStack"
	stack.custom_minimum_size = Vector2(0, 220)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.clip_contents = true
	vbox.add_child(stack)
	_build_energy(stack)
	_build_control(stack)
	_build_storage(stack)
	_build_mechanics(stack)
	_build_life(stack)
	_build_sub_bay(stack)

	_action = Label.new()
	_action.name = "ActionLine"
	_action.text = " "
	vbox.add_child(_action)
	show_room("energy")


func _panel(parent: Control, room_id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = room_id
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.visible = false
	parent.add_child(box)
	_panels[room_id] = box
	return box


func _body(parent: VBoxContainer, room_id: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = true
	label.fit_content = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 72)
	label.add_theme_font_size_override("normal_font_size", 15)
	label.text = "..."
	parent.add_child(label)
	_text[room_id] = label
	return label


func _build_energy(stack: Control) -> void:
	var box := _panel(stack, "energy")
	_body(box, "energy")
	var row := _flow(box)
	row.add_child(_button("Exterior lights", _toggle_lights))
	row.add_child(_button("Divert off", func(): _sim.set_divert("", 0.0)))
	row.add_child(_button("Speed processor +4 kW", func(): _sim.set_divert("processor", 4.0)))
	row.add_child(_button("Speed refinery +4 kW", func(): _sim.set_divert("refinery", 4.0)))
	var pri := _flow(box)
	for spec in ShellOps.ROOM_SPECS:
		var feed := str(spec["feed"])
		var room_name := str(spec["room"])
		pri.add_child(_button("Pri " + room_name, _prioritize.bind(feed)))


func _build_control(stack: Control) -> void:
	var box := _panel(stack, "control")
	_body(box, "control")
	var row := _flow(box)
	row.add_child(_button("Search shelf", _launch.bind("shelf_biomass")))
	row.add_child(_button("Mine ore", _launch.bind("shelf_ore")))
	row.add_child(_button("Order return", _return_sub))


func _build_storage(stack: Control) -> void:
	var box := _panel(stack, "storage")
	_body(box, "storage")
	var row := _flow(box)
	row.add_child(_button("Unload sub into storage", _unload))


func _build_mechanics(stack: Control) -> void:
	var box := _panel(stack, "mechanics")
	_body(box, "mechanics")
	var gear := _flow(box)
	gear.add_child(_button("Craft battery", func(): _sim.upgrade_gear("battery")))
	gear.add_child(_button("Craft scanner", func(): _sim.upgrade_gear("scanner")))
	gear.add_child(_button("Craft cargo rack", func(): _sim.upgrade_gear("cargo")))
	var rooms := _flow(box)
	for spec in ShellOps.ROOM_SPECS:
		var module_id := str(spec["primary"])
		var room_name := str(spec["room"])
		rooms.add_child(_button("Upgrade " + room_name, _upgrade.bind(module_id)))
	_repair_note = Label.new()
	_repair_note.text = "Wear: no faults"
	box.add_child(_repair_note)
	var repairs := HFlowContainer.new()
	repairs.name = "Repairs"
	repairs.add_theme_constant_override("h_separation", 6)
	repairs.add_theme_constant_override("v_separation", 4)
	box.add_child(repairs)
	_repair["box"] = repairs


func _build_life(stack: Control) -> void:
	var box := _panel(stack, "life")
	_body(box, "life")
	var row := _flow(box)
	row.add_child(_button("Plant off", func(): _sim.set_life_mode(StationModule.Mode.OFF)))
	row.add_child(_button("Plant standby", func(): _sim.set_life_mode(StationModule.Mode.STANDBY)))
	row.add_child(_button("Plant run", func(): _sim.set_life_mode(StationModule.Mode.RUNNING)))
	row.add_child(_button("Seal hull  12 scrap", func(): _sim.seal_station_hull()))


func _build_sub_bay(stack: Control) -> void:
	var box := _panel(stack, "sub_bay")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	for key in ["position", "depth", "station", "equipment"]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(280, 72)
		grid.add_child(panel)
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.scroll_active = false
		label.fit_content = true
		label.add_theme_font_size_override("normal_font_size", 16)
		panel.add_child(label)
		_monitors[key] = label
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(220, 0)
	row.add_child(side)
	side.add_child(_button("Ping  1.5 kW", func(): _sim.ping_sub()))
	var note := RichTextLabel.new()
	note.bbcode_enabled = true
	note.scroll_active = false
	note.fit_content = true
	side.add_child(note)
	_text["sub_bay"] = note


func _build_repair_buttons() -> void:
	if _sim == null or not _repair.has("box"):
		return
	var host: HFlowContainer = _repair["box"]
	for id in _sim.modules.keys():
		var module_id := str(id)
		var btn := _button("Repair " + module_id, _repair_id.bind(module_id))
		btn.visible = false
		host.add_child(btn)
		_repair[module_id] = btn


func _refresh() -> void:
	if _sim == null or _status == null:
		return
	var snap := _sim.snapshot()
	var run := "PAUSED" if bool(snap["paused"]) else "RUN"
	_status.text = "tick %d   %s   %.0fx    gen %.1f kW    air %.0f%%    station hull %.0f    sub %s" % [
		int(snap["tick"]), run, float(snap["speed"]),
		float(snap["power_generated"]), float(snap["air"]),
		float(snap["station_hull"]), str(snap["sub_phase"]),
	]
	_action.text = _sim.last_action_reason if _sim.last_action_reason != "" else " "
	_fill_energy(snap)
	_fill_control(snap)
	_fill_storage(snap)
	_fill_mechanics(snap)
	_fill_life(snap)
	_fill_sub_bay(snap)
	_refresh_repairs()


func _fill_energy(snap: Dictionary) -> void:
	var gen: StationModule = _sim.modules["generator"]
	var lights: StationModule = _sim.modules["exterior_lights"]
	var speed := 1.0
	if str(snap["divert_target"]) != "" and float(snap["divert_applied_kw"]) > 0.0:
		var need := _sim.module_request_kw(str(snap["divert_target"]))
		speed = 1.0 + float(snap["divert_applied_kw"]) / maxf(need, 0.1)
	var lines := "[b]GENERATOR[/b]  %.1f kW    fuel_oil %.1f    cond %.0f%%  %s\n" % [
		float(snap["power_generated"]), float(snap["fuel_oil"]), gen.condition, gen.mode_name(),
	]
	lines += "[b]BUS[/b]  requested %.1f    granted %.1f    spare %.1f    reserved %.1f kW\n" % [
		float(snap["power_requested"]), float(snap["power_granted"]),
		float(snap["power_available"]), float(snap["power_reserved"]),
	]
	var target := str(snap["divert_target"]) if str(snap["divert_target"]) != "" else "off"
	lines += "[b]DIVERT[/b]  %s    order %.1f kW    applied %.1f kW    craft x%.2f\n" % [
		target, float(snap["divert_kw"]), float(snap["divert_applied_kw"]), speed,
	]
	lines += "[b]EXTERIOR LIGHTS[/b]  %s    demand %.1f    granted %.1f kW\n" % [
		"ON" if lights.mode == StationModule.Mode.RUNNING else "OFF",
		_sim.module_request_kw("exterior_lights"), lights.power_granted,
	]
	for row in _sim.shell.bus_rows(_sim):
		lines += "%s    %s    %.1f / %.1f kW    tier %d\n" % [
			str(row["room"]), str(row["modules"]), float(row["granted"]), float(row["demand"]), int(row["priority"]),
		]
	var other: Dictionary = _sim.shell.other_load(_sim)
	lines += "Other loads    %.1f / %.1f kW" % [float(other["granted"]), float(other["demand"])]
	(_text["energy"] as RichTextLabel).text = lines


func _fill_control(snap: Dictionary) -> void:
	var sub := _sim.sub
	var lines := "[b]%s[/b]    target %s\n" % [str(snap["sub_phase"]), sub.target_id if sub.target_id != "" else "(bay)"]
	lines += "depth %.0f m    track %.0f m    safe %.0f m\n" % [sub.depth_m, float(snap["track_m"]), sub.safe_depth_m]
	lines += "battery %.2f / %.2f kWh    hull %.0f    cargo %.1f / %.0f\n" % [
		sub.battery_kwh, sub.battery_capacity_kwh, sub.hull, sub.cargo_total(), sub.cargo_capacity,
	]
	if sub.fail_reason != "":
		lines += "[color=#ffb15a]%s[/color]\n" % sub.fail_reason
	lines += "\n[b]DEPOSITS[/b]\n"
	for nid in sub.nodes.keys():
		var node: Dictionary = sub.nodes[nid]
		lines += "%s    %.0f m    %s    left %.1f\n" % [
			str(nid), float(node["depth_m"]), str(node["resource"]), float(node["remaining"]),
		]
	(_text["control"] as RichTextLabel).text = lines


func _fill_storage(_snap: Dictionary) -> void:
	var lines := "[b]STATION BINS[/b]\n"
	var ids: Array = _sim.inventory.stock.keys()
	ids.sort()
	for id in ids:
		var res := str(id)
		lines += "%s    %.1f / %.0f\n" % [res, _sim.inventory.get_amount(res), float(_sim.inventory.capacity.get(res, 0.0))]
	lines += "\n[b]STILL ABOARD[/b]\n"
	if _sim.sub.cargo.is_empty():
		lines += "(empty)\n"
	else:
		for id in _sim.sub.cargo.keys():
			lines += "%s    %.1f\n" % [str(id), float(_sim.sub.cargo[id])]
	(_text["storage"] as RichTextLabel).text = lines


func _fill_mechanics(_snap: Dictionary) -> void:
	var lines := "[b]DIVE GEAR[/b]  battery L%d    scanner L%d    cargo L%d\n" % [
		int(_sim.shell.gear_levels["battery"]),
		int(_sim.shell.gear_levels["scanner"]),
		int(_sim.shell.gear_levels["cargo"]),
	]
	lines += "battery %s    scanner %s    cargo rack %s\n\n" % [
		_cost("battery"), _cost("scanner"), _cost("cargo"),
	]
	lines += "[b]ROOM CONDITION[/b]\n"
	for spec in ShellOps.ROOM_SPECS:
		var module_id := str(spec["primary"])
		var m: StationModule = _sim.modules[module_id]
		lines += "%s  %s  L%d  %s  %s  wear/tick %.3f\n" % [
			str(spec["room"]), module_id, m.level, m.mode_name(), _bar(m.condition), m.wear_per_tick,
		]
	(_text["mechanics"] as RichTextLabel).text = lines


func _fill_life(snap: Dictionary) -> void:
	var plant: StationModule = _sim.modules["life_support"]
	var lines := "[b]AIR[/b]  %.0f%%     [b]HEAT[/b]  %.1f C     [b]HULL[/b]  %.0f%%\n" % [
		float(snap["air"]), float(snap["heat_c"]), float(snap["station_hull"]),
	]
	lines += "[b]CABIN[/b]  %.2f bar     [b]SEA AT STATION[/b]  %.2f bar\n" % [
		float(snap["cabin_bar"]), float(snap["station_sea_bar"]),
	]
	lines += "[b]PLANT[/b]  %s    granted %.2f / %.1f kW    %s\n" % [
		plant.mode_name(), plant.power_granted, plant.power_demand,
		"holding" if bool(snap["life_powered"]) else "losing air",
	]
	lines += "Seal spends %d scrap and restores hull on the station, not the sub." % int(ShellOps.SEAL_SCRAP)
	(_text["life"] as RichTextLabel).text = lines


func _fill_sub_bay(snap: Dictionary) -> void:
	var sub := _sim.sub
	var ping := "no fix yet"
	if int(snap["ping_tick"]) >= 0:
		ping = "tick %d" % int(snap["ping_tick"])
	var pos := "%s\n%.0f m   track %.0f m\n%s" % [
		sub.phase_name(), sub.depth_m, float(snap["track_m"]),
		sub.target_id if sub.target_id != "" else "in the bay",
	]
	(_monitors["position"] as RichTextLabel).text = "[b]SUB POSITION[/b]\n" + pos
	(_monitors["depth"] as RichTextLabel).text = "[b]DEPTH PRESSURE[/b]\n%.2f bar\nat %.0f m" % [
		float(snap["depth_pressure_bar"]), sub.depth_m,
	]
	(_monitors["station"] as RichTextLabel).text = "[b]STATION PRESSURE[/b]\ncabin %.2f bar\nsea %.2f bar" % [
		float(snap["cabin_bar"]), float(snap["station_sea_bar"]),
	]
	(_monitors["equipment"] as RichTextLabel).text = "[b]EQUIPMENT PRESSURE[/b]\n%.2f bar\n%s" % [
		float(snap["equipment_pressure_bar"]),
		"lock" if sub.phase == SubVessel.Phase.DOCKED else "with the sub",
	]
	var dock: StationModule = _sim.modules["dock"]
	(_text["sub_bay"] as RichTextLabel).text = "Last ping  %s\nDock power  %.2f / %.1f kW\nSub hull %.0f\nBattery %.2f kWh" % [
		ping, dock.power_granted, _sim.module_request_kw("dock"), sub.hull, sub.battery_kwh,
	]


func _refresh_repairs() -> void:
	if _repair_note == null:
		return
	var faults := 0
	for id in _sim.modules.keys():
		var btn: Button = _repair.get(str(id), null)
		if btn == null:
			continue
		var module: StationModule = _sim.modules[id]
		var faulted: bool = module.mode == StationModule.Mode.FAULTED
		btn.visible = faulted
		if faulted:
			faults += 1
	_repair_note.text = "Wear faults: %d    repair spends scrap + electronics" % faults


func _show_room_id(room_id: String) -> void:
	show_room(room_id)


func _prioritize(module_id: String) -> void:
	_sim.prioritize_room(module_id)


func _upgrade(module_id: String) -> void:
	_sim.upgrade_room(module_id)


func _repair_id(module_id: String) -> void:
	_sim.try_repair_module(module_id)
	_sim.state_changed.emit()


func _return_sub() -> void:
	_sim.sub_order_return()
	_sim.state_changed.emit()


func _unload() -> void:
	_sim.unload_sub()
	_sim.state_changed.emit()


func _launch(node_id: String) -> void:
	_sim.sub_depart(node_id)
	_sim.state_changed.emit()


func _toggle_lights() -> void:
	_sim.set_exterior_lights(not _sim.shell.lights_on)


func _style_tabs() -> void:
	for id in _tabs.keys():
		var btn: Button = _tabs[id]
		if id == _room:
			btn.add_theme_stylebox_override("normal", _tab_on)
			btn.add_theme_stylebox_override("hover", _tab_on)
		else:
			btn.add_theme_stylebox_override("normal", _tab_off)
			btn.add_theme_stylebox_override("hover", _tab_hover)


func _button(text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 30)
	btn.pressed.connect(action)
	return btn


func _flow(parent: Node) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	return flow


func _on_pause() -> void:
	pause_toggled.emit()


func _cost(kind: String) -> String:
	var spec: Dictionary = ShellOps.GEAR[kind]
	var parts: PackedStringArray = PackedStringArray()
	for key in spec.keys():
		if str(key) == "max":
			continue
		parts.append("%s %.0f" % [str(key), float(spec[key])])
	return " ".join(parts)


func _bar(pct: float) -> String:
	var n := int(round(clampf(pct, 0.0, 100.0) / 10.0))
	var marks := ""
	for i in 10:
		marks += "#" if i < n else "."
	return "[%s] %.0f%%" % [marks, pct]


func _theme() -> Theme:
	var theme := Theme.new()
	var ink := Color("071016")
	var paper := Color("d7ebe6")
	var edge := Color("e06a28")
	_tab_off = _box(Color("102028"), edge, 2)
	_tab_hover = _box(Color("1a3340"), edge, 2)
	_tab_on = _box(Color("a34a16"), Color("ffd7a8"), 2)
	var panel := _box(Color(0.035, 0.06, 0.08, 0.96), edge, 3)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("normal", "Button", _tab_off)
	theme.set_stylebox("hover", "Button", _tab_hover)
	theme.set_stylebox("pressed", "Button", _tab_on)
	theme.set_stylebox("focus", "Button", _tab_off)
	theme.set_color("font_color", "Button", paper)
	theme.set_color("font_hover_color", "Button", Color("fff6e4"))
	theme.set_color("font_pressed_color", "Button", Color("fff6e4"))
	theme.set_font_size("font_size", "Button", 14)
	theme.set_color("font_color", "Label", paper)
	theme.set_font_size("font_size", "Label", 15)
	theme.set_color("default_color", "RichTextLabel", paper)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	theme.set_constant("line_separation", "RichTextLabel", 2)
	theme.set_color("font_color", "Label", paper)
	theme.set_stylebox("panel", "Panel", _box(ink, edge, 2))
	return theme


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(0)
	box.content_margin_left = 8
	box.content_margin_top = 4
	box.content_margin_right = 8
	box.content_margin_bottom = 4
	return box
