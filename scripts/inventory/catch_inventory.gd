class_name MonsterCatchInventory
extends RefCounted
## Minimal Phase 1 basket. Plain dictionaries are ready for versioned save data.

signal changed

var catches: Array[Dictionary] = []
var money: int = 0
var equipment: Dictionary={"rod":0,"line":0,"hook":0,"engine":0,"reel":0,"searchlight":0,"hull":0}
var bait: int=0
var materials: int=0
var goods: Dictionary={"repair_kit":0,"tackle":0,"canvas":0}
var stored_catches: Array[Dictionary]=[]
var encyclopedia: Dictionary={}

func record(data: Dictionary,released: bool=false) -> void:
	var key: String=str(data.get("species_id",data.get("id","unknown")))
	var entry: Dictionary=encyclopedia.get(key,{"name":data.get("name",key),"count":0,"released":0,"record":0.,"rarity":data.get("rarity","Comum")})
	entry.count+=1;entry.released+=1 if released else 0;entry.record=maxf(float(entry.record),float(data.get("weight",0.)))
	entry["observation"]=bool(data.get("observation",false))
	encyclopedia[key]=entry;changed.emit()

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
