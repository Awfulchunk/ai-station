extends RefCounted
class_name Inventory
## Finite bins. No silent overflow delete. No negative stock.

var capacity: Dictionary = {}  # resource_id -> max
var stock: Dictionary = {}     # resource_id -> amount

func set_capacity(res_id: String, max_amount: float) -> void:
	capacity[res_id] = max_amount
	if not stock.has(res_id):
		stock[res_id] = 0.0

func get_amount(res_id: String) -> float:
	return float(stock.get(res_id, 0.0))

func free_capacity(res_id: String) -> float:
	var cap := float(capacity.get(res_id, 0.0))
	return maxf(0.0, cap - get_amount(res_id))

func can_add(res_id: String, amount: float) -> bool:
	return amount <= free_capacity(res_id) + 1e-9

func can_remove(res_id: String, amount: float) -> bool:
	return amount <= get_amount(res_id) + 1e-9

## Returns actual transferred amount. Never overdraws. Never silently deletes overflow.
func transfer_in(res_id: String, requested: float) -> float:
	if requested <= 0.0:
		return 0.0
	var free := free_capacity(res_id)
	var actual := minf(requested, free)
	stock[res_id] = get_amount(res_id) + actual
	return actual

func transfer_out(res_id: String, requested: float) -> float:
	if requested <= 0.0:
		return 0.0
	var avail := get_amount(res_id)
	var actual := minf(requested, avail)
	stock[res_id] = avail - actual
	return actual

## Atomic recipe commit: validate all outs fit AND all ins available, then commit.
## Returns true on full commit; false leaves inventory unchanged.
func try_recipe(inputs: Dictionary, outputs: Dictionary) -> bool:
	for k in inputs.keys():
		if not can_remove(str(k), float(inputs[k])):
			return false
	for k in outputs.keys():
		if not can_add(str(k), float(outputs[k])):
			return false
	for k in inputs.keys():
		transfer_out(str(k), float(inputs[k]))
	for k in outputs.keys():
		transfer_in(str(k), float(outputs[k]))
	return true

func export_state() -> Dictionary:
	return {
		"stock": stock.duplicate(),
		"capacity": capacity.duplicate(),
	}

## Overlay a save onto the bins that already exist. fuel / electricity are not bins.
func import_state(data: Dictionary) -> void:
	var caps = data.get("capacity", {})
	if typeof(caps) == TYPE_DICTIONARY:
		for key in caps.keys():
			var res_id := str(key)
			if _rejected(res_id):
				continue
			set_capacity(res_id, maxf(0.0, float(caps[key])))
	var saved = data.get("stock", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return
	for key in saved.keys():
		var res_id := str(key)
		if _rejected(res_id) or not capacity.has(res_id):
			continue
		var cap := float(capacity[res_id])
		stock[res_id] = clampf(float(saved[key]), 0.0, cap)

func _rejected(res_id: String) -> bool:
	return res_id == "fuel" or res_id == "electricity" or res_id == "power_kw"

func assert_sane() -> bool:
	for k in stock.keys():
		if float(stock[k]) < -1e-6:
			return false
		var cap := float(capacity.get(k, INF))
		if float(stock[k]) > cap + 1e-6:
			return false
	return true
