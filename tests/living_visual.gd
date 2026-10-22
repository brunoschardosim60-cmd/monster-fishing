extends SceneTree
var view: SubViewport
var camera: Camera3D
var game: Node3D
func _initialize() -> void:call_deferred("run")
func shot(id: String,eye: Vector3,target: Vector3) -> void:
	camera.position=eye;camera.look_at(target)
	for i: int in 40:await process_frame
	await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://tests/output/living/"+id+".png")
	print("SHOT ",id)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/living"))
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.set_process_input(false);game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();camera.far=4000.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=16.8
	await shot("village",Vector3(0,3.2,-.5),Vector3(2,3,35))
	await shot("old_port",Vector3(-160,27,-76),Vector3(-110,5,-17))
	await shot("old_port_stalls",Vector3(-61,4.,1),Vector3(-78,2.8,-10))
	await shot("forest",Vector3(-55,31,214),Vector3(-28,35,245))
	await shot("island",Vector3(650,450,-350),Vector3(-35,50,430))
	game.world.ocean.hour=22.
	game.boat.searchlight_upgraded=true;game.boat.update_lights()
	await shot("boat_lights",Vector3(10,4.6,-31),Vector3(3.9,1.8,-23))
	game.world.ocean.hour=15.
	game.hud.show();game.hud.open_service("workshop_oldport",game.inventory,game.boat)
	await shot("accessories_shop",Vector3(-61,4.,1),Vector3(-78,2.8,-10))
	game.hud.hide();game.audio.stop_all();game.world.life.birdsong.stop();game.queue_free();await process_frame
	# Isolated actual palm renders at controlled wind times avoid false positives
	# from ocean, clouds, camera motion or animated NPCs.
	view.use_taa=false
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("38525a");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.75;env.environment=e;view.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);view.add_child(sun)
	var holder:=Node3D.new();view.add_child(holder)
	const Nature=preload("res://scripts/world/nature_library.gd")
	Nature.plant(holder,2,Vector3.ZERO);Nature.plant(holder,0,Vector3(-12,0,-5))
	camera.position=Vector3(0,7,24);camera.look_at(Vector3(-4,6,0))
	var counts: Array[int]=[];var root_changes:=0
	for strength: float in [0.,1.]:
		var captures: Array[Image]=[]
		for phase: float in [0.,1.2]:
			Nature.wind(phase,strength,Vector2.RIGHT)
			for i: int in 12:await process_frame
			await RenderingServer.frame_post_draw;var img:=view.get_texture().get_image();captures.append(img);img.save_png("res://tests/output/living/wind_%s_%s.png"%[str(strength),str(phase)])
		var changed:=0
		for y: int in range(0,900,2):
			for x: int in range(0,1440,2):
				if absf(captures[0].get_pixel(x,y).v-captures[1].get_pixel(x,y).v)>.035:changed+=1
		counts.append(changed)
		if strength==1.:
			# Lower palm trunk: motion must stay in foliage, with the root anchored.
			for y: int in range(550,610):
				for x: int in range(765,800):
					if absf(captures[0].get_pixel(x,y).v-captures[1].get_pixel(x,y).v)>.035:root_changes+=1
	var ok:=counts[1]>300 and counts[1]>counts[0] and root_changes==0
	print("WIND_RENDER ","PASS" if ok else "FAIL"," calm/storm changed sampled pixels=",counts," root_changes=",root_changes)
	view.queue_free();await process_frame;quit(0 if ok else 1)
