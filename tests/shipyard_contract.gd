extends "res://tests/archipelago_contract.gd"
## Boatyard: berth opens the shop, boats can be bought and switched, shipwrights work.
## --headless --fixed-fps 60 --script res://tests/shipyard_contract.gd

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var yard=game.world.village.shipyard
	check(yard!=null and game.world.village.services.has("shipyard"),"the boatyard stands on the shore with a shop counter")
	check(Layout.coast(Vector2(yard.berth.x,yard.berth.z)).x>4.,"its berth is in open water off the pier")
	game.boat.set_occupied(true);game.player.set_boating(true)
	game.boat.global_position=yard.berth+Vector3(0,0,0);game.boat.speed=0.
	await frames(10)
	check(game.hud.service_open and game.service_id=="shipyard","bringing the boat into the berth opens the boatyard shop")
	game.hud.close_service();await frames(5)
	check(not game.hud.service_open,"the shop does not reopen while the boat stays in the berth")
	game.inventory.money=500
	game._service_action("boat:veloz")
	check(game.inventory.boat_id=="veloz" and game.inventory.money==200 and is_equal_approx(game.boat.max_speed,14.8),"buying the fast launch changes the boat (%.1f m/s)"%game.boat.max_speed)
	check(not is_equal_approx(game.boat._hull.scale.x,1.),"the new boat has its own hull size")
	game._service_action("boat:aurora")
	check(game.inventory.boat_id=="aurora" and game.inventory.money==200 and is_equal_approx(game.boat.max_speed,11.),"owned boats can be switched back for free")
	game.inventory.money=40;game._service_action("boat:traineira")
	check(game.inventory.boat_id=="aurora" and game.inventory.money==40,"a boat you cannot afford is not sold")
	var starts: Array=[]
	for w in yard.workers:starts.append(w.position)
	await frames(300)
	var moving:=0
	for i: int in yard.workers.size():
		if yard.workers[i].position.distance_to(starts[i])>.5:moving+=1
	check(moving>=2,"shipwrights carry planks to the hull on the slipway (%d moving)"%moving)
	print("SHIPYARD %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
