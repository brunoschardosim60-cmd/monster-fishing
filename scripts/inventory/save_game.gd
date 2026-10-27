extends RefCounted
## Saves and loads the player's progress (user://progresso.save, Godot binary variants, versioned):
## money and gear, boats owned, catches aboard and in storage, encyclopedia and running totals, hull
## condition, places discovered, missions and market orders, monsters already observed, tutorial steps,
## time of day, and where the boat and the player were (only if it was safe water / land).
## main.gd saves automatically every minute, when selling, delivering, finishing a mission and on quit.
const PATH: String="user://progresso.save"
const VERSION: int=1
const INVENTORY_FIELDS: Array[String]=["money","bait","feed","traps","harpoons","flares","materials","boat_id"]
const INVENTORY_DICTS: Array[String]=["equipment","goods","encyclopedia","stats"]

static func exists(path: String=PATH) -> bool:
	return FileAccess.file_exists(path)

static func erase(path: String=PATH) -> void:
	if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func save(game: Node,path: String=PATH) -> bool:
	var inv=game.inventory
	var data:={"version":VERSION,"time":Time.get_unix_time_from_system()}
	for key: String in INVENTORY_FIELDS:data[key]=inv.get(key)
	for key: String in INVENTORY_DICTS:data[key]=(inv.get(key) as Dictionary).duplicate(true)
	data["catches"]=inv.catches.duplicate(true);data["stored_catches"]=inv.stored_catches.duplicate(true)
	data["owned_boats"]=Array(inv.owned_boats)
	data["integrity"]=float(game.boat.integrity)
	data["discovered"]=(game.world.village.discovered as Dictionary).duplicate(true)
	data["flags"]={"boarded":game.boarded_once,"sailed":game.sailed_once,"caught":game.caught_once,"sold":game.sold_once}
	data["hour"]=float(game.world.ocean.hour)
	if game.missions!=null:
		data["missions"]={"step":game.missions.step,"contracts":game.missions.contracts.duplicate(true),"completed":game.missions.completed_contracts}
	if game.lairs!=null:
		var lairs:={}
		for lair: Dictionary in game.lairs.lairs:lairs[lair.name]={"observed":lair.observed,"victories":int(lair.get("victories",0))}
		data["lairs"]=lairs
	if game.get("diving")!=null:data["chests"]=(game.diving.opened as Dictionary).duplicate()
	if not game.boat.sinking:
		data["boat"]={"position":game.boat.global_position,"yaw":game.boat.rotation.y}
	if not game.player.in_boat and not game.player.swimming and not game.player.flying:
		data["player"]=game.player.global_position
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_var(data);file.close()
	return true

## Restores a save into a freshly started game. Returns false if there is none or it cannot be read.
static func load_into(game: Node,path: String=PATH) -> bool:
	if not FileAccess.file_exists(path):return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return false
	var data=file.get_var();file.close()
	if not data is Dictionary or int(data.get("version",0))<1:return false
	var inv=game.inventory
	for key: String in INVENTORY_FIELDS:
		if data.has(key):inv.set(key,data[key])
	for key: String in INVENTORY_DICTS:
		if data.has(key):
			var merged: Dictionary=(inv.get(key) as Dictionary).duplicate(true)
			merged.merge(data[key],true);inv.set(key,merged)
	inv.catches.assign(data.get("catches",[]));inv.stored_catches.assign(data.get("stored_catches",[]))
	inv.owned_boats.assign(data.get("owned_boats",["aurora"]))
	preload("res://scripts/inventory/harbor_economy.gd").apply(inv,game.boat,game.fishing)
	game.boat.integrity=clampf(float(data.get("integrity",1.)),.05,1.)
	var discovered: Dictionary=data.get("discovered",{})
	(game.world.village.discovered as Dictionary).merge(discovered,true)
	var flags: Dictionary=data.get("flags",{})
	game.boarded_once=bool(flags.get("boarded",false));game.sailed_once=bool(flags.get("sailed",false))
	game.caught_once=bool(flags.get("caught",false));game.sold_once=bool(flags.get("sold",false))
	game.world.ocean.hour=float(data.get("hour",game.world.ocean.hour))
	if data.has("missions") and game.missions!=null:
		var m: Dictionary=data.missions
		game.missions.step=int(m.get("step",0));game.missions.completed_contracts=int(m.get("completed",0))
		if (m.get("contracts",[]) as Array).size()>0:game.missions.contracts.assign(m.contracts)
	if data.has("lairs") and game.lairs!=null:
		for lair: Dictionary in game.lairs.lairs:
			var saved: Dictionary=(data.lairs as Dictionary).get(lair.name,{})
			lair.observed=bool(saved.get("observed",false));lair["victories"]=int(saved.get("victories",0))
	if data.has("boat"):
		game.boat.global_position=data.boat.position;game.boat.rotation=Vector3(0,float(data.boat.yaw),0)
	if data.has("player"):
		game.player.global_position=data.player
	if data.has("chests") and game.get("diving")!=null:game.diving.restore_opened(data.chests)
	inv.changed.emit()
	return true
