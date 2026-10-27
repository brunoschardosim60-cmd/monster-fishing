extends "res://tests/archipelago_contract.gd"
## Save game: progress written to a file comes back after the game state changes, and tests never touch
## the real save (saving is off when run with --script).
## --headless --fixed-fps 60 --script res://tests/save_contract.gd
const SaveGame=preload("res://scripts/inventory/save_game.gd")
const PATH:="user://teste_progresso.save"

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	check(not game.saving_enabled,"tests run with saving disabled")
	var inv=game.inventory
	inv.money=777;inv.harpoons=3;inv.flares=2;inv.equipment.rod=2;inv.equipment["harpoon"]=1
	inv.add_catch(game.gear.make_catch("caranguejo"));inv.record({"id":"sargo","name":"Sargo","weight":1.2})
	game.world.village.discovered["teste"]=true
	game.missions.step=4;game.boat.integrity=.6;game.sold_once=true;game.world.ocean.hour=20.
	game.lairs.lairs[0].observed=true
	check(SaveGame.save(game,PATH),"the save file is written")
	inv.money=1;inv.harpoons=0;inv.flares=0;inv.equipment.rod=0;inv.catches.clear();inv.encyclopedia.clear()
	game.world.village.discovered.erase("teste");game.missions.step=0;game.boat.integrity=1.;game.sold_once=false;game.lairs.lairs[0].observed=false
	check(SaveGame.load_into(game,PATH),"the save file loads")
	check(inv.money==777 and inv.harpoons==3 and inv.flares==2,"money, harpoons and flares come back")
	check(int(inv.equipment.rod)==2 and int(inv.equipment.get("harpoon",0))==1,"upgrades come back")
	check(inv.catches.size()==1 and inv.encyclopedia.has("sargo"),"catch aboard and encyclopedia come back")
	check(game.world.village.discovered.has("teste") and game.missions.step==4,"discoveries and story progress come back")
	check(absf(game.boat.integrity-.6)<.01 and game.sold_once and game.lairs.lairs[0].observed,"hull, tutorial and monster sightings come back")
	SaveGame.erase(PATH)
	check(not SaveGame.exists(PATH),"a new game erases the save")
	print("SAVE %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
