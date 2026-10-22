extends "res://tests/archipelago_contract.gd"
func run() -> void:
	Engine.time_scale=3.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.set_process_input(false)
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;await frames(10)
	var district: Node3D=game.world.village.bridge_district
	game.player.position=Vector3(29,1.65,-7);game.player.velocity=Vector3.ZERO;await frames(10)
	var reached:=0
	for at: Vector3 in [Vector3(29,1.4,-18),Vector3(45,2.,-18),Vector3(63,1.75,-18),Vector3(70,1.4,-18),Vector3(70,1.4,-7),Vector3(70,1.3,4)]:
		if await walk_to(at):reached+=1
		else:break
	check(reached==6 and not game.player.swimming,"Walk the full east bridge loop and return to shore without jumping")
	game.player.position=Vector3(-30,1.65,-4);game.player.velocity=Vector3.ZERO;await frames(10)
	var market: Vector3=game.world.village.services.market_bridge.global_position
	check(await walk_to(Vector3(-49,1.8,-4)) and await walk_to(market),"Walk arched western bridge into the market bay")
	game.interact();check(game.hud.service_open and game.service_id=="market_bridge","E opens actual bridge market after physical approach")
	game.inventory.money=100
	game._service_action("buy_goods:repair_kit");game.boat.integrity=.4;game._service_action("use_kit")
	check(game.inventory.money==76 and game.inventory.goods.repair_kit==0 and is_equal_approx(game.boat.integrity,.75),"Market purchase consumes currency and repair kit restores 35 percent hull")
	game._service_action("use_kit");check(is_equal_approx(game.boat.integrity,.75),"Consumed item cannot be reused")
	game._service_action("buy_goods:tackle");game._service_action("sell_goods:tackle");var money: int=game.inventory.money;game._service_action("sell_goods:tackle")
	check(money==68 and game.inventory.money==money and game.inventory.goods.tackle==0,"Trade resale pays advertised price and cannot duplicate goods")
	game._service_action("buy_goods:tackle");game._service_action("use_tackle")
	check(game.inventory.bait==6 and game.inventory.goods.tackle==0,"Tackle box produces usable fishing bait")
	game._service_action("sell_bait");check(game.inventory.bait==5 and game.inventory.money==53,"Bait can be sold individually")
	game.inventory.materials=2;game._service_action("buy_goods:canvas");game._service_action("craft_kit")
	check(game.inventory.goods.repair_kit==1 and game.inventory.materials==0 and game.inventory.goods.canvas==0,"Canvas and gathered materials craft a real repair kit")
	game.hud.close_service()
	# Sample physical schooling trajectories, including capped turning and acceleration.
	var fish: Node3D=game.marine.schools[0].members[0];var previous: Vector3=fish.position;var previous_yaw: float=fish.rotation.y;var maximum_step:=0.;var maximum_turn:=0.
	for i: int in 180:
		await physics_frame
		maximum_step=maxf(maximum_step,fish.position.distance_to(previous));maximum_turn=maxf(maximum_turn,absf(angle_difference(previous_yaw,fish.rotation.y)));previous=fish.position;previous_yaw=fish.rotation.y
	check(maximum_step<.2 and maximum_turn<.15,"Fish motion has bounded steps and turns: %.3f m / %.3f rad"%[maximum_step,maximum_turn])
	var resident: Node3D=game.world.village.residents[0]
	resident.wait=2.;resident.velocity=Vector3.ZERO;var start: Vector3=resident.position
	await frames(10);check(resident.position.distance_to(start)<.01,"Resting villagers hold their position")
	resident.wait=0.;await frames(1);check(resident.velocity.length()<resident.speed*.5,"Walking accelerates gradually from rest")
	# Real fishing state machines must complete catches and transfer them to stock.
	for i: int in 1600:
		await physics_frame
		if district.stock.size()>=2:break
	check(district.stock.size()>=2 and district.fishers[0].caught_count+district.fishers[1].caught_count>=2,"Working fishers cast, strike, reel, store fish and supply market stock")
	if not district.stock.is_empty():
		game.inventory.money=500;var count: int=game.inventory.count();var stock_count: int=district.stock.size();var price:=ceili(float(district.stock[0].value)*1.25)
		game.service_id="market_bridge";game._service_action("buy_stock:0")
		check(game.inventory.count()==count+1 and district.stock.size()==stock_count-1 and game.inventory.money==500-price,"Buying NPC fish transfers a real catch and removes market stock")
		var value: int=game.inventory.catches.back().value;game._service_action("sell_fish:"+str(game.inventory.count()-1))
		check(game.inventory.count()==count and game.inventory.money==500-price+value,"Individual capture sale removes the fish and credits its value")
		game.hud.close_service()
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=23.;await frames(5)
	check(game.world.environment.ambient_light_energy>=.45 and game.world.village.night_lights.size()>25,"Night ambient fill and connected street lighting keep town readable")
	var angle: float=game.world.lighthouse.rotor.rotation.y;await frames(40)
	check(game.world.lighthouse.rotor.visible and absf(angle_difference(angle,game.world.lighthouse.rotor.rotation.y))>.1,"Night lighthouse rotates its actual beam")
	check(not game.hud.objective.visible and game._interaction_hint().length()<80,"HUD hides tutorial blocks and keeps context prompts brief")
	game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	print("HARBOR RENEWAL ",checks," checks / ",failures," failures");quit(1 if failures else 0)
