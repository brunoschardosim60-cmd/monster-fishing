extends SceneTree
## Rendered acceptance scenarios, fixed 1440x900 framebuffer on the real GPU.
const Waves=preload("res://scripts/world/wave_field.gd")
var game: Node3D
var view: SubViewport
var camera: Camera3D
var reports: Array[Dictionary]=[]
var output: String="res://tests/output/ocean"
var follow: bool=false
var offset:=Vector3(6,4,10)
var ticks: Array[float]=[]
var last_tick: int=0

func _initialize() -> void: call_deferred("_run")
func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
		if follow:
			camera.global_position=game.boat.global_position+offset
			camera.look_at(game.boat.global_position+Vector3(0,.4,-1))
		var now:=Time.get_ticks_usec()
		if last_tick>0: ticks.append(float(now-last_tick)/1000.)
		last_tick=now

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img:=view.get_texture().get_image()
	img.save_png(output.path_join(label+".png"))
	ticks.sort()
	var report:={"scenario":label,"wind":game.world.ocean.weather.wind,"swell":game.world.ocean.weather.energy,"rain":game.world.ocean.weather.rain,"wave_height_at_boat":Waves.height_at(game.boat.global_position),"wake_samples":game.boat.trail.samples.size(),"splash_events":game.world.ocean.effects.total_splashes,"frame_ms_p50":ticks[ticks.size()/2] if not ticks.is_empty() else 0.,"frame_ms_p95":ticks[int(ticks.size()*.95)] if not ticks.is_empty() else 0.,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"vram_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.}
	reports.append(report); print("SCENARIO: ",JSON.stringify(report))
	ticks.clear(); last_tick=0

func _place(state: int, at: Vector3, eye: Vector3, target: Vector3) -> void:
	follow=false; Input.action_release("move_forward"); Input.action_release("move_right")
	game.world.ocean.weather.settle(state)
	game.boat.speed=0.; game.boat.velocity=Vector3.ZERO
	game.boat.heave_velocity=0.; game.boat._hull.position.y=0.
	game.boat.global_position=at; game.boat.rotation=Vector3.ZERO; game.boat.trail.clear_trail()
	camera.global_position=eye; camera.look_at(target)
	ticks.clear(); last_tick=0

func _run() -> void:
	if RenderingServer.get_current_rendering_method()=="gl_compatibility": output+="-compatibility"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	view=SubViewport.new(); view.size=Vector2i(1440,900); view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; view.msaa_3d=Viewport.MSAA_2X
	root.add_child(view)
	var display:=TextureRect.new(); display.texture=view.get_texture()
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(display)
	root.position=Vector2i(40,40)
	game=load("res://scenes/main/main.tscn").instantiate(); view.add_child(game)
	game.begin_play(); game.set_process_input(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.audio.stop_all(); game.player.controls_enabled=false
	game.player.global_position=Vector3(0,1.55,-23); game.interact()
	game.hud.visible=false
	camera=Camera3D.new(); camera.fov=62.; camera.far=2200.; view.add_child(camera); camera.current=true
	await _frames(180)
	_place(0,Vector3(15,0,-55),Vector3(21,3.6,-46),Vector3(15,.4,-55))
	await _frames(180); await _capture("01_calm_boat")
	_place(1,Vector3(20,0,-65),Vector3(26,5,-55),Vector3(20,0,-65))
	follow=true; Input.action_press("move_forward")
	await _frames(300); await _capture("02_open_water")
	_place(2,Vector3(5,0,-105),Vector3(11,4,-94),Vector3(5,0,-105))
	follow=true; Input.action_press("move_forward")
	await _frames(220); await _capture("03_large_waves")
	_place(2,Vector3(20,0,-18),Vector3(29,4,-14),Vector3(12,0,-9))
	await _frames(180); await _capture("04_beach_breakers")
	_place(2,Vector3(-68,0,-89),Vector3(-62,4,-79),Vector3(-79,1,-95))
	await _frames(180); await _capture("05_rock_coast")
	_place(2,Vector3(4,0,-24),Vector3(18,4,-31),Vector3(0,1,-16))
	await _frames(180); await _capture("06_sheltered_harbor")
	_place(2,Vector3(15,0,-88),Vector3(22,4,-77),Vector3(15,0,-88))
	game.world.ocean.weather.choose(3)
	for i: int in 1200: game.world.ocean.weather.advance(1./60.)
	await _frames(180); await _capture("07a_heavy_rain")
	for i: int in 3000: game.world.ocean.weather.advance(1./60.)
	game.world.ocean.flash_clock=1.5
	await _frames(240); await _capture("07b_storm")
	game.world.ocean.flash_clock=.2
	await _frames(15); await _capture("07c_lightning")
	await _frames(60)
	game.world.ocean.weather.choose(4)
	for i: int in 2400: game.world.ocean.weather.advance(1./60.)
	await _frames(240); await _capture("08_after_storm")
	_place(1,Vector3(20,0,-60),Vector3(18.5,2.6,-66),Vector3(16,0,-68))
	await _frames(3)
	game.fish_action(); game.fishing.set_process(false)
	camera.global_position=game.fishing_visual.target+Vector3(1.6,1.6,2.4)
	camera.look_at(game.fishing_visual.target)
	game.fishing.state=game.fishing.State.WAITING
	await _frames(180); await _capture("09_fishing_float")
	game.fishing.state=game.fishing.State.BITE; game.fish_action()
	await _frames(22); await _capture("09b_hooked_fish_breach")
	game.fishing.cancel()
	_place(1,Vector3(30,0,-65),Vector3(30,10,-55),Vector3(30,0,-65))
	follow=true; offset=Vector3(0,11,13); Input.action_press("move_forward")
	await _frames(300); Input.action_press("move_right")
	await _frames(180); Input.action_release("move_right"); Input.action_release("move_forward")
	await _frames(60); await _capture("10_persistent_turning_wake")
	_place(1,Vector3(593,0,-603),Vector3(591,4,-593),Vector3(608,0,-624))
	await _frames(180); await _capture("11_cold_floes")
	_place(2,Vector3(504,0,-620),Vector3(499,6,-611),Vector3(505,0,-628))
	await _frames(180); await _capture("14_ice_channel")
	_place(0,Vector3(12,0,-22),Vector3(12,-1.,-20),Vector3(12,-4.,-24))
	await _frames(120); await _capture("12_underwater")
	game.hud.visible=true; game.hud.show_pause(); camera.global_position=Vector3(15,6,-30); camera.look_at(Vector3(0,1,-5))
	await _frames(30); await _capture("13_weather_menu")
	var f:=FileAccess.open(output.path_join("scenarios.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"framebuffer":"1440x900","samples":reports},"\t")); f.close()
	game.audio.stop_all(); OS.delay_msec(100); game.queue_free(); await process_frame
	quit()
