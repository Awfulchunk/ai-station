extends Node
class_name SimClock
## Fixed 1.0s simulation tick. Pause + speed 1/2/4. Rendering stays free.

signal tick_advanced(tick: int)

const TICK_SECONDS := 1.0

var paused: bool = false
var speed: float = 1.0  # 1, 2, or 4
var tick: int = 0
var _accum: float = 0.0

func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta * speed
	while _accum >= TICK_SECONDS:
		_accum -= TICK_SECONDS
		tick += 1
		tick_advanced.emit(tick)

func set_speed(s: float) -> void:
	if s in [1.0, 2.0, 4.0]:
		speed = s

func toggle_pause() -> void:
	paused = not paused

func advance_n(n: int) -> void:
	## Headless/test: force n ticks without waiting on wall clock.
	for i in n:
		tick += 1
		tick_advanced.emit(tick)

func set_accum(seconds: float) -> void:
	_accum = clampf(seconds, 0.0, TICK_SECONDS)

func accum_seconds() -> float:
	return _accum

func export_state() -> Dictionary:
	return {
		"tick": tick,
		"paused": paused,
		"speed": speed,
		"accum": _accum,
	}

func import_state(data: Dictionary) -> void:
	tick = maxi(int(data.get("tick", tick)), 0)
	paused = bool(data.get("paused", paused))
	var next_speed := float(data.get("speed", speed))
	if next_speed == 1.0 or next_speed == 2.0 or next_speed == 4.0:
		speed = next_speed
	else:
		speed = 1.0
	set_accum(float(data.get("accum", _accum)))
