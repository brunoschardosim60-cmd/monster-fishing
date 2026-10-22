extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view:=SubViewport.new();view.size=Vector2i(1440,900);view.own_world_3d=true;root.add_child(view)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var display:=TextureRect.new();display.texture=view.get_texture();display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate();view.add_child(game);game.begin_play();game.audio.stop_all();game.hud.visible=false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	game.player.global_position=Vector3(0,1.55,-23);game.interact()
	game.boat.global_position=Vector3(15,0,-70);game.boat.rotation.y=PI*.3
	var camera:=Camera3D.new();view.add_child(camera);camera.current=true
	Input.action_press("move_forward")
	for i: int in 240:
		await physics_frame
		camera.global_position=game.boat.global_position+Vector3(9,5,13);camera.look_at(game.boat.global_position+Vector3(0,1,0))
	Input.action_release("move_forward")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://tests/output/first-asset-in-game.png")
	assert(game.boat.imported_model!=null,"Real GLB must replace visual")
	assert(game.boat.speed>2.,"Navigation must work")
	assert(game.player.global_position.distance_to(game.boat.seat_position())<.1,"Player must follow hull marker")
	assert(game.boat.imported_model.meshes.size()==70,"Actual imported hierarchy")
	print("FIRST_ASSET PASS: imported meshes, navigation, hull following, seated marker. speed=",game.boat.speed)
	game.audio.stop_all();view.queue_free();await process_frame;OS.delay_msec(100);quit()
