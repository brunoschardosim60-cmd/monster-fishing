extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view:=SubViewport.new();view.size=Vector2i(900,900);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var scene:=Node3D.new();view.add_child(scene)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("879ba0");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.65;env.environment=e;scene.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);scene.add_child(sun)
	var model: Node3D=load("res://assets/characters/survivalist_rigged.glb").instantiate();scene.add_child(model)
	var anim: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	print("RIG bones=",skeleton.get_bone_count()," animations=",anim.get_animation_list())
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-2,1.3,-3);camera.look_at(Vector3(0,.9,0));camera.current=true
	for key: String in anim.get_animation_list():
		anim.play(key);anim.seek(.3,true);anim.pause()
		for i: int in 8:await process_frame
		await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://tests/output/rig-"+key.replace("/","_")+".png")
	view.queue_free();await process_frame;quit()
