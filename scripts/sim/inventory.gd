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

func assert_sane() -> bool:
	for k in stock.keys():
		if float(stock[k]) < -1e-6:
			return false
		var cap := float(capacity.get(k, INF))
		if float(stock[k]) > cap + 1e-6:
			return false
	return true
