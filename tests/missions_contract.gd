extends "res://tests/archipelago_contract.gd"
## Missions: the story objective follows the tutorial and advances with real progress (feeding fish,
## hauling a trap…), paying a reward; market orders are delivered from the catch aboard.
## --headless --fixed-fps 60 --script res://tests/missions_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var m=game.missions
	check(m.contracts.size()==3,"the market board holds three orders")
	game.boarded_once=true;game.sailed_once=true;game.caught_once=true;game.sold_once=true
	await frames(5)
	check(game.hud.objective.text.begins_with("MISSÃO 1/"),"after the tutorial the story objective is shown (%s)"%game.hud.objective.text.get_slice("\n",0))
	var money: int=game.inventory.money
	game.inventory.stats.fed=1
	await frames(70)
	check(m.step==1 and game.inventory.money==money+20,"feeding fish completes the first mission and pays (+%d)"%(game.inventory.money-money))
	check(game.hud.objective.text.contains("EXPLORADOR"),"the next objective appears")
	# Deliver an order with matching fish aboard.
	var order: Dictionary=m.contracts[0]
	for i: int in int(order.count):
		var fish: Dictionary=game.gear.make_catch(str(order.species))
		fish.weight=maxf(float(fish.weight),float(order.min_weight)+.1)
		game.inventory.add_catch(fish)
	check(m.have(0)>=int(order.count),"fish aboard count for the order (%s)"%m.describe(0))
	money=game.inventory.money
	var reply: String=m.deliver(0)
	check(game.inventory.money==money+int(order.reward) and m.completed_contracts==1 and m.contracts.size()==3,"delivering pays the order and a new one replaces it (%s)"%reply)
	check(m.deliver(1).begins_with("Ainda falta"),"an order without the fish is refused")
	print("MISSIONS %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
