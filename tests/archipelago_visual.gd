extends SceneTree
var game: Node3D
var view: SubViewport
var camera: Camera3D
var failures: int=0
func fits(label: String,control: Control) -> void:
	var ok:=Rect2(Vector2.ZERO,Vector2(view.size)).encloses(control.get_global_rect())
	print("PASS " if ok else "FAIL ",label," viewport bounds ",control.get_global_rect())
	if not ok:failures+=1
func _initialize() -> void: call_deferred("run")
func shot(name: String,eye: Vector3,target: Vector3) -> void:
	camera.position=eye;camera.look_at(target)
	for i: int in 45:await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://tests/output/archipelago/"+name+".png")
	print("VIEW ",name," fps=",Performance.get_monitor(Performance.TIME_FPS)," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," vramMB=",Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/archipelago"))
	view=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X;root.add_child(view)
	var display:=TextureRect.new();display.texture=view.get_texture();display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.visible=false
	game.player.controls_enabled=false;game.set_process_input(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	camera=Camera3D.new();camera.far=4000.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=15.
	await shot("01_harbor",Vector3(65,28,-70),Vector3(0,8,35))
	await shot("02_village",Vector3(2,3.1,-1),Vector3(0,2.4,35))
	await shot("03_cabin",Vector3(-14,3.1,5),Vector3(-15,2.3,9))
	await shot("04_island",Vector3(440,340,-350),Vector3(0,25,220))
	await shot("05_trail",Vector3(-55,31,214),Vector3(-28,35,245))
	await shot("06_grotto",Vector3(-170,25,198),Vector3(-170,24,211))
	game.world.ocean.hour=23.
	await shot("07_night",Vector3(20,5,-28),Vector3(0,4,25))
	game.world.ocean.hour=6.7
	await shot("08_dawn",Vector3(-65,118,490),Vector3(-220,0,280))
	game.world.ocean.hour=15.
	await shot("11_tugboat",Vector3(-43,4,-30),Vector3(-34,1.,-22))
	game.hud.visible=true;game.hud.map_view.show()
	await shot("12_map",Vector3(65,28,-70),Vector3(0,8,35));fits("map",game.hud.map_view)
	game.hud.map_view.hide();game.hud.open_service("gear",game.inventory,game.boat)
	await shot("13_shop",Vector3(16,3.,17),Vector3(16,2.,22));fits("shop",game.hud.service_panel)
	game.hud.close_service();game.hud.show_pause()
	await shot("14_weather_menu",Vector3(20,5,-28),Vector3(0,4,25));fits("pause quit button",game.hud.quit_button)
	game.hud.hide_pause();game.hud.visible=false;game.world.ocean.hour=23.
	for i: int in 4:await physics_frame
	var eye:=Vector3(20,4,-90)
	await shot("15_moon",eye,eye+game.world.ocean.moon.global_basis.z*500.)
	game.world.ocean.hour=15.;game.world.ocean.weather.settle(3)
	await shot("16_storm",Vector3(20,3.5,-80),Vector3(35,0,-105))
	game.audio.stop_all();game.world.life.birdsong.stop();view.queue_free();await process_frame;OS.delay_msec(100);print("ARCHIPELAGO VISUAL UI: 3 checks / ",failures," failures");quit(failures)
