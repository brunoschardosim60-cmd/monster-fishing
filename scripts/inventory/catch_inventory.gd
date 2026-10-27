class_name MonsterCatchInventory
extends RefCounted
## Minimal Phase 1 basket. Plain dictionaries are ready for versioned save data.

signal changed

var catches: Array[Dictionary] = []
var money: int = 0
var equipment: Dictionary={"rod":0,"line":0,"hook":0,"engine":0,"reel":0,"searchlight":0,"hull":0,"net":0}
var bait: int=0
## Boats owned (ids from harbor_economy.BOATS) and the one in use.
var owned_boats: Array[String]=["aurora"]
var boat_id: String="aurora"
## Paint scheme bought at the shipyard (0 = the boat's factory colours).
var boat_paint: int=0
## Sailors hired at the inn: {"name", "look", "task"} (crew_manager.gd).
var crew: Array=[]
## Fish feed handfuls, crab traps carried aboard.
var feed: int=3
## Two crab traps (covos) come with the boat; more at the fishing shop.
var traps: int=2
## Harpoons for the bow harpoon gun (H) and distress flares that scare monsters away (Y).
var harpoons: int=0
var flares: int=0
var materials: int=0
var goods: Dictionary={"repair_kit":0,"tackle":0,"canvas":0}
var stored_catches: Array[Dictionary]=[]
var encyclopedia: Dictionary={}
## Running totals used by missions: fish recorded, fish sold, feed thrown, traps hauled.
## Catches the boat's hold can carry (set from the hull by harbor_economy.apply).
var hold_limit: int=14
var stats: Dictionary={"caught":0,"sold":0,"fed":0,"traps":0}

func record(data: Dictionary,released: bool=false) -> void:
	var key: String=str(data.get("species_id",data.get("id","unknown")))
	var entry: Dictionary=encyclopedia.get(key,{"name":data.get("name",key),"count":0,"released":0,"record":0.,"rarity":data.get("rarity","Comum")})
	entry.count+=1;entry.released+=1 if released else 0;entry.record=maxf(float(entry.record),float(data.get("weight",0.)))
	entry["observation"]=bool(data.get("observation",false))
	if not entry.observation:stats.caught=int(stats.caught)+1
	encyclopedia[key]=entry;changed.emit()

func add_catch(catch_data: Dictionary) -> bool:
	if not catch_data.has("id") or not catch_data.has("weight") or not catch_data.has("value"):
		return false
	if str(catch_data["id"]).is_empty() or float(catch_data["weight"]) <= 0.0 or int(catch_data["value"]) < 1:
		return false
	if catches.size()>=hold_limit:
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
	stats.sold=int(stats.sold)+catches.size()
	catches.clear()
	changed.emit()
	return reward
