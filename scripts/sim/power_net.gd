extends RefCounted
class_name PowerNet
## generated / requested / granted. Core priority. No single fake stock.power.

var generated: float = 0.0
var requested: float = 0.0
var granted_total: float = 0.0
var grants: Dictionary = {}  # module_id -> granted kW
var requests: Dictionary = {}  # module_id -> requested kW
var priorities: Dictionary = {}  # module_id -> int tier (0=core first)

## Priority tiers from Extreme Spec §6.3:
## 0 = Core/emergency; 1 = dock/safety; 2 = processing/refining; 3 = research/optional

func clear_requests() -> void:
	requests.clear()
	requested = 0.0

func set_generation(kw: float) -> void:
	generated = maxf(0.0, kw)

func request(module_id: String, kw: float, priority: int) -> void:
	requests[module_id] = maxf(0.0, kw)
	priorities[module_id] = priority
	requested = 0.0
	for k in requests.keys():
		requested += float(requests[k])

func allocate() -> void:
	grants.clear()
	granted_total = 0.0
	var remaining := generated
	# Sort by priority ascending, then stable id
	var ids: Array = requests.keys()
	ids.sort_custom(func(a, b):
		var pa := int(priorities.get(a, 99))
		var pb := int(priorities.get(b, 99))
		if pa != pb:
			return pa < pb
		return str(a) < str(b)
	)
	for id in ids:
		var req := float(requests[id])
		var g := minf(req, remaining)
		grants[id] = g
		granted_total += g
		remaining -= g

func granted(module_id: String) -> float:
	return float(grants.get(module_id, 0.0))
