extends "res://tests/living_visual.gd"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/living"))
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.set_process_input(false);game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();camera.far=4000.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=9.;game.world.ocean.weather.settle(0)
	await shot("modeled_house",Vector3(-23,5.,-7),Vector3(-14,3.,7))
	await shot("sea_arch",Vector3(350,20,195),Vector3(285,22,275))
	var query:=PhysicsRayQueryParameters3D.create(Vector3(285,2,225),Vector3(285,2,325),1)
	var passage_blocked:=not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	print("ARCH_PASSAGE ","FAIL" if passage_blocked else "PASS")
	game.player.set_physics_process(false);game.player.position=Vector3(0,1.385,-7);game.player.visual.rotation.y=0.;game.player.visual.update_animation(0.,false,.5)
	await shot("fisherman_new",Vector3(-2.2,2.7,-10.1),Vector3(0,2.4,-7))
	await shot("fisherman_backpack",Vector3(2.2,2.7,-4),Vector3(0,2.4,-7))
	var ship: Node3D=game.world.traffic.vessels[2]
	await shot("moving_support_ship",ship.position+Vector3(32,14,24),ship.position+Vector3.UP*4.)
	game.hud.show();game.hud.show_pause()
	await shot("graphics_settings",Vector3(8,4,-28),Vector3(0,2,-5))
	game.hud.hide();game.world.ocean.hour=12.
	var school: Vector3=game.marine.schools[0].center
	await shot("underwater_school",school+Vector3(7,1.2,7),school)
	game.player.position=game.marine.guardian.position+Vector3(10,4,10);game.boat.speed=0.
	for frame: int in 180:await process_frame
	var guardian: Vector3=game.marine.guardian.position
	await shot("guardian_encounter",guardian+Vector3(12,2,14),guardian)
	game.hud.hide();game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("16313b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;environment.environment=env;view.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);view.add_child(sun)
	var animation_failures:=1 if passage_blocked else 0
	for id: String in ["mackerel","tuna","lanternfish","abyssal_guardian"]:
		var visual:=preload("res://scripts/creatures/marine_visual.gd").new();visual.species=id;visual.face_forward=false;view.add_child(visual)
		if id=="abyssal_guardian":await shot("model_"+id,Vector3(12,11,18),Vector3(-1,0,0))
		else:await shot("model_"+id,Vector3(.5,.25,1.65),Vector3(-.1,0,0))
		var before:=view.get_texture().get_image()
		for frame: int in 36:await process_frame
		await RenderingServer.frame_post_draw
		var after:=view.get_texture().get_image();var changed:=0
		for y: int in range(0,900,3):
			for x: int in range(0,1440,3):
				if absf(before.get_pixel(x,y).v-after.get_pixel(x,y).v)>.03:changed+=1
		if changed<30:animation_failures+=1
		after.save_png("res://tests/output/living/model_"+id+"_swimming.png")
		print("SWIM_RENDER ",id," ","PASS" if changed>=30 else "FAIL"," changed pixels=",changed)
		visual.queue_free();await process_frame
	view.queue_free();await process_frame;quit(1 if animation_failures else 0)
