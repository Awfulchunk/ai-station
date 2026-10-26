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
