extends "res://tests/archipelago_contract.gd"
## Gear upgrades come in three levels with rising prices, and each level changes the fishing numbers.
## --headless --fixed-fps 60 --script res://tests/upgrades_contract.gd
const Shop=preload("res://scripts/inventory/harbor_economy.gd")
func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.player.controls_enabled=false
	await frames(10)
	var inv: RefCounted=game.inventory;var boat: CharacterBody3D=game.boat;var fishing: Node=game.fishing
	inv.money=1000
	check(Shop.buy("rod",inv,boat,fishing).begins_with("Nova vara"),"first rod upgrade is accepted")
	check(inv.equipment.rod==1,"rod is at level 1")
	check(absf(fishing.rod_bonus-.15)<1e-4,"level 1 rod adds +15%% reel speed (%.2f)"%fishing.rod_bonus)
	var before:int=inv.money
	Shop.buy("rod",inv,boat,fishing)
	check(inv.equipment.rod==2 and before-inv.money==130,"level 2 costs double (%d moedas)"%(before-inv.money))
	Shop.buy("rod",inv,boat,fishing)
	check(inv.equipment.rod==3,"rod reaches level 3")
	check(Shop.buy("rod",inv,boat,fishing)=="Nível máximo já alcançado.","a fourth level is refused")
	check(inv.equipment.rod==3,"refused upgrade does not change the level")
	inv.money=10
	check(Shop.buy("reel",inv,boat,fishing).begins_with("Moedas insuficientes"),"an upgrade is refused without enough money")
	check(inv.equipment.reel==0,"refused upgrade leaves the reel at level 0")
	inv.money=500
	Shop.buy("line",inv,boat,fishing);Shop.buy("hook",inv,boat,fishing)
	check(absf(fishing.line_bonus-.15)<1e-4 and absf(fishing.hook_bonus-.08)<1e-4,"line and hook bonuses apply after purchase")
	# Crafting turns materials into goods and bait; missing parts are refused without spending anything.
	inv.materials=5;inv.goods.tackle=0;inv.goods.canvas=0;inv.bait=0
	check(Shop.buy("craft_tackle",inv,boat,fishing).begins_with("Montagem concluída") and inv.goods.tackle==1 and inv.materials==3,"crafting a tackle box spends 2 materials")
	check(Shop.buy("craft_bait",inv,boat,fishing).begins_with("Montagem") and inv.bait==6 and inv.materials==2,"crafting bait turns 1 material into 6 baits")
	inv.materials=3
	check(Shop.buy("craft_canvas",inv,boat,fishing).begins_with("Montagem") and inv.goods.canvas==1 and inv.materials==0,"canvas crafting spends its 3 materials")
	inv.materials=0
	check(Shop.buy("craft_tackle",inv,boat,fishing).begins_with("Faltam materiais"),"crafting is refused without materials")
	print("UPGRADES %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
