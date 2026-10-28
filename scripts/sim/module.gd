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

## Wear stops on this line and faults. A later wear from FAULTED can destroy.
const FAULT_CONDITION := 15.0
## Standby draw is this fraction of power_demand, and is always below it.
const IDLE_POWER_FRACTION := 0.25

func condition_factor() -> float:
	return clampf(condition / 100.0, 0.25, 1.0) if condition > 0.0 else 0.0

func is_operable() -> bool:
	return mode != Mode.OFF and mode != Mode.DESTROYED and mode != Mode.FAULTED and condition > 0.0

func set_mode(m: int, reason: String = "") -> void:
	mode = m
	blocked_reason = reason

func mode_name() -> String:
	match mode:
		Mode.OFF:
			return "OFF"
		Mode.STANDBY:
			return "STANDBY"
		Mode.RUNNING:
			return "RUNNING"
		Mode.PAUSED:
			return "PAUSED"
		Mode.FAULTED:
			return "FAULTED"
		Mode.DESTROYED:
			return "DESTROYED"
		_:
			var _missing := mode
			push_error("StationModule unhandled mode")
			return "OFF"

static func mode_from_name(mode_name: String) -> int:
	match mode_name:
		"OFF":
			return Mode.OFF
		"STANDBY":
			return Mode.STANDBY
		"RUNNING":
			return Mode.RUNNING
		"PAUSED":
			return Mode.PAUSED
		"FAULTED":
			return Mode.FAULTED
		"DESTROYED":
			return Mode.DESTROYED
		_:
			push_error("StationModule unknown mode name")
			return Mode.STANDBY

func idle_power() -> float:
	var idle := power_demand * IDLE_POWER_FRACTION
	if power_demand > 0.0 and idle >= power_demand:
		idle = power_demand * 0.5
	return idle

## Crossing the fault line clamps condition and enters FAULTED.
## FAULTED wear can continue down to DESTROYED. Recovery is a sim repair.
func apply_wear(amount: float) -> void:
	if mode == Mode.DESTROYED or mode == Mode.OFF:
		return
	if amount <= 0.0:
		return
	var next := maxf(0.0, condition - amount)
	if mode != Mode.FAULTED and next <= FAULT_CONDITION:
		condition = FAULT_CONDITION
		set_mode(Mode.FAULTED, "wear fault")
		return
	condition = next
	if condition <= 0.0:
		condition = 0.0
		set_mode(Mode.DESTROYED, "condition zero")
