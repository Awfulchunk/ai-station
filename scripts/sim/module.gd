extends RefCounted
class_name StationModule
## Shared module FSM: OFF / STANDBY / RUNNING / PAUSED / FAULTED / DESTROYED

enum Mode { OFF, STANDBY, RUNNING, PAUSED, FAULTED, DESTROYED }

var id: String = ""
var type: String = ""
var level: int = 1
var condition: float = 100.0
var mode: int = Mode.STANDBY
var power_demand: float = 0.0
var power_granted: float = 0.0
var priority: int = 2
var base_rate: float = 1.0
var efficiency: float = 1.0
var blocked_reason: String = ""
var job_progress: float = 0.0
var job_duration: float = 0.0
var active_recipe: Dictionary = {}
var wear_per_tick: float = 0.01

func condition_factor() -> float:
	return clampf(condition / 100.0, 0.25, 1.0) if condition > 0.0 else 0.0

func is_operable() -> bool:
	return mode != Mode.OFF and mode != Mode.DESTROYED and mode != Mode.FAULTED and condition > 0.0

func set_mode(m: int, reason: String = "") -> void:
	mode = m
	blocked_reason = reason

func apply_wear(amount: float) -> void:
	condition = maxf(0.0, condition - amount)
	if condition <= 0.0:
		set_mode(Mode.DESTROYED, "condition zero")
