extends "res://tests/archipelago_contract.gd"
func run() -> void:
	Engine.time_scale=6.;Engine.physics_ticks_per_second=120
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all();game.set_process_input(false)
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.player.position=Layout.NORTH_TRAIL[0]+Vector3.UP*.2;await frames(12)
	var reached:=0
	for p: Vector3 in Layout.NORTH_TRAIL.slice(1):
		if await walk_to(p):reached+=1
		else:break
	check(reached==Layout.NORTH_TRAIL.size()-1,"Walk entire new northern mountain loop: %d waypoints"%reached)
	game.player.position=Vector3(-30,1.6,-7);game.player.velocity=Vector3.ZERO;await frames(12)
	var access:=true
	for p: Vector3 in [Vector3(-30,1.4,-4),Vector3(-6,1.4,0),Vector3(8,1.4,8),Vector3(16,1.4,12),game.world.village.services["gear"].global_position]:
		if not await walk_to(p):access=false;break
	check(access,"Walk continuously from village seafront to the fishing shop")
	game.interact();check(game.hud.service_open and game.service_id=="gear","E opens the actual fishing shop after the walk")
	game.hud.close_service();game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	print("EXPANDED ROUTES ",checks," checks / ",failures," failures");quit(1 if failures else 0)
