extends RefCounted
class_name LifeSupport
## Station atmosphere. Air, heat, and hull move only from plant power and leaks.
## Pressures are hydrostatic: 1 bar + depth_m / 10. No painted stand-in values.

var air: float = 96.0
var heat_c: float = 19.0
var hull: float = 100.0
var interior_bar: float = 1.03
var station_depth_m: float = 42.0
var powered: bool = false

const TARGET_HEAT_C := 20.0
const SEAWATER_C := 4.0
const AIR_GAIN := 1.15
const AIR_LOSS := 0.7
const HULL_LEAK := 0.05


static func pressure_bar(depth_m: float) -> float:
	return 1.0 + maxf(depth_m, 0.0) / 10.0


func sea_pressure_bar() -> float:
	return pressure_bar(station_depth_m)


func tick(plant: StationModule) -> void:
	var fed: bool = plant.mode == StationModule.Mode.RUNNING \
		and plant.power_granted + 1e-6 >= plant.power_demand \
		and plant.condition > 0.0
	powered = fed
	if fed:
		air = minf(100.0, air + AIR_GAIN)
		heat_c = move_toward(heat_c, TARGET_HEAT_C, 0.4)
		interior_bar = move_toward(interior_bar, 1.0, 0.08)
		return
	air = maxf(0.0, air - AIR_LOSS)
	heat_c = move_toward(heat_c, SEAWATER_C, 0.18)
	var leak := 0.012 + 0.05 * (1.0 - hull / 100.0)
	interior_bar = lerpf(interior_bar, sea_pressure_bar(), leak)
	hull = maxf(0.0, hull - HULL_LEAK)


func export_state() -> Dictionary:
	return {
		"air": air,
		"heat_c": heat_c,
		"hull": hull,
		"interior_bar": interior_bar,
		"station_depth_m": station_depth_m,
	}


func import_state(data: Dictionary) -> void:
	air = clampf(float(data.get("air", air)), 0.0, 100.0)
	heat_c = float(data.get("heat_c", heat_c))
	hull = clampf(float(data.get("hull", hull)), 0.0, 100.0)
	interior_bar = maxf(0.0, float(data.get("interior_bar", interior_bar)))
	if data.has("station_depth_m"):
		station_depth_m = maxf(0.0, float(data["station_depth_m"]))
