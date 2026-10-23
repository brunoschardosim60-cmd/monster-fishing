extends SceneTree
## Capturas para comparar o estilo visual. Uso: godot --path . --script res://tests/style_shots.gd -- <pasta>
var view: SubViewport
var camera: Camera3D
var game: Node3D
var out_dir := "before"
func _initialize() -> void:call_deferred("run")
func shot(id: String,eye: Vector3,target: Vector3) -> void:
	camera.position=eye;camera.look_at(target)
	for i: int in 2:await process_frame
	await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://tests/output/style/"+out_dir+"/"+id+".png")
	print("SHOT ",id)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>0:out_dir=args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output/style/"+out_dir))
	view=SubViewport.new();view.size=Vector2i(640,400);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_2X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	game=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.hide();game.set_process_input(false);game.player.controls_enabled=false
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;camera=Camera3D.new();camera.far=4000.;camera.fov=68.;view.add_child(camera);camera.current=true
	game.world.ocean.cycle_enabled=false;game.world.ocean.hour=16.8
	var p:Vector3=game.player.global_position
	print("READY t=",Time.get_ticks_msec()/1000.)
	var wanted:=args.slice(1)
	var all:={
		"player_front":[p+Vector3(0,1.5,-3.4),p+Vector3(0,1.1,0)],
		"player_back":[p+Vector3(1.2,2.0,4.5),p+Vector3(0,1.2,0)],
		"village":[Vector3(0,3.2,-.5),Vector3(2,3,35)],
		"old_port":[Vector3(-160,27,-76),Vector3(-110,5,-17)],
		"island":[Vector3(650,450,-350),Vector3(-35,50,430)],
		"sea":[Vector3(60,6,-60),Vector3(120,1,-200)],
	}
	for id: String in all:
		if wanted.is_empty() or id in wanted:
			await shot(id,all[id][0],all[id][1]);print("t=",Time.get_ticks_msec()/1000.)
	game.audio.stop_all();quit(0)
