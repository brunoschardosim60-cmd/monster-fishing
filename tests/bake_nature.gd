extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view:=SubViewport.new();view.size=Vector2i(512,512);view.transparent_bg=true;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X;root.add_child(view)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(0,0,0,0);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.7;env.environment=e;view.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=.8;view.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18.;camera.position=Vector3(0,8,35);view.add_child(camera);camera.look_at(Vector3(0,8,0));camera.current=true
	const Nature=preload("res://scripts/world/nature_library.gd")
	for kind: int in 4:
		var holder:=Node3D.new();view.add_child(holder);Nature.plant(holder,kind,Vector3.ZERO)
		for i: int in 8:await process_frame
		await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://assets/environment/nature/"+Nature.NAMES[kind]+"_impostor.png")
		holder.queue_free();await process_frame
	view.queue_free();await process_frame;quit()
