extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view:=SubViewport.new();view.size=Vector2i(512,512);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var scene:=Node3D.new();view.add_child(scene)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_CLEAR_COLOR;e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.9;env.environment=e;scene.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-20,0);sun.light_energy=.7;scene.add_child(sun)
	var rng:=RandomNumberGenerator.new();rng.seed=37
	preload("res://scripts/world/coastal_details.gd").pine(scene,Vector3.ZERO,1.,rng,preload("res://scripts/visuals/materials.gd").surface("weathered_wood",Color("5d5844"),3.))
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.5;scene.add_child(camera);camera.position=Vector3(0,3.,12);camera.look_at(Vector3(0,3.,0));camera.current=true
	for i: int in 30:await process_frame
	await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://assets/textures/pine_impostor.png")
	view.queue_free();await process_frame;quit()
