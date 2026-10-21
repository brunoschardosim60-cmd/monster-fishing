class_name MonsterCatchInventory
extends RefCounted
## Minimal Phase 1 basket. Plain dictionaries are ready for versioned save data.

signal changed

var catches: Array[Dictionary] = []
var money: int = 0

func add_catch(catch_data: Dictionary) -> bool:
	if not catch_data.has("id") or not catch_data.has("weight") or not catch_data.has("value"):
		return false
	if str(catch_data["id"]).is_empty() or float(catch_data["weight"]) <= 0.0 or int(catch_data["value"]) < 1:
		return false
	catches.append(catch_data.duplicate(true))
	changed.emit()
	return true

func count() -> int:
	return catches.size()

func total_value() -> int:
	var result: int = 0
	for item: Dictionary in catches:
		result += int(item.get("value", 0))
	return result

func sell_all() -> int:
	var reward: int = total_value()
	if reward <= 0:
		return 0
	money += reward
	catches.clear()
	changed.emit()
	return reward
