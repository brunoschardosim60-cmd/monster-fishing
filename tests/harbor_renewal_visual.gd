extends "res://tests/living_visual.gd"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/living"))
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.set_process_input(false);game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();camera.far=4000.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=9.;game.world.ocean.weather.settle(0)
	await shot("renewal_bridges_day",Vector3(81,9,-40),Vector3(47,2,-16))
	await shot("renewal_market_day",Vector3(-33,3.7,-4),Vector3(-51,2.7,-9))
	await shot("renewal_boat",Vector3(10,5.2,-16),Vector3(3.9,1.6,-23))
	game.hud.show();game.player.position=Vector3(0,1.55,-17)
	await shot("renewal_clean_hud",Vector3(1,3.5,-22),Vector3(0,3,15))
	game.hud.open_service("market_bridge",game.inventory,game.boat,game.world.village.bridge_district.stock)
	await shot("renewal_market_ui",Vector3(-33,3.7,-4),Vector3(-51,2.7,-9))
	game.hud.close_service();game.hud.hide()
	game.world.ocean.hour=23.
	await shot("renewal_village_night",Vector3(0,3.2,-1),Vector3(0,3,35))
	await shot("renewal_bridge_night",Vector3(77,4,-20),Vector3(41,3,-20))
	var at: Vector3=game.world.harbor_lighthouse.position
	game.world.harbor_lighthouse.set_process(false);game.world.harbor_lighthouse.rotor.rotation.y=-PI*.5
	await shot("renewal_lighthouse",at+Vector3(31,18,-35),at+Vector3.UP*10.)
	game.world.harbor_lighthouse.set_process(true)
	game.world.ocean.hour=16.7
	var fisher: Node3D=game.world.village.bridge_district.fishers[0]
	for frame: int in 1800:
		await process_frame
		if fisher.fishing.state==4:break
	await shot("renewal_working_fisher",fisher.global_position+Vector3(2,1.6,2),fisher.global_position+Vector3(0,1,-1))
	game.world.ocean.hour=12.
	var school: Vector3=game.marine.schools[0].center
	await shot("renewal_swimming",school+Vector3(6,1,7),school)
	game.player.set_physics_process(false);game.player.position=Vector3(0,1.4,-7)
	for i: int in 6:
		game.player.visual.update_animation(1.4,false,.16)
		await shot("renewal_gait_"+str(i),Vector3(2,2.3,-10),Vector3(0,2.4,-7))
	game.audio.stop_all();game.world.life.birdsong.stop();view.queue_free();await process_frame;quit()
