extends SceneTree
## Isolates lighting artifacts without changing the shipping scene.
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i: int in n: await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/"+label+".png")
func run() -> void:
	var game:=load("res://scenes/main/main.tscn").instantiate() as Node3D
	root.add_child(game); game.begin_play(); game.audio.stop_all(); game.hud.hide()
	game.set_process_input(false); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var camera:=Camera3D.new(); game.add_child(camera); camera.current=true
	camera.position=Vector3(18,4,-31); camera.look_at(Vector3(0,1,-16))
	game.world.ocean.weather.settle(2)
	await frames(120); game.world.ocean.set_physics_process(false)
	await capture("probe_normal")
	game.world.environment.ssr_enabled=false
	await frames(30); await capture("probe_no_ssr")
	game.world.sun.shadow_enabled=false
	await frames(30); await capture("probe_no_shadow")
	for node: Node in game.world.ocean.get_children():
		if node is MeshInstance3D: node.hide()
	await frames(30); await capture("probe_no_seabed")
	var shader:=Shader.new()
	var code: String=game.world.ocean_material.shader.code
	shader.code=code.substr(0,code.find("void fragment()"))+"void fragment(){ ALBEDO=vec3(.05,.4,.6); ROUGHNESS=1.; }"
	game.world.ocean_material.shader=shader
	preload("res://scripts/world/wave_field.gd").bind(game.world.ocean_material)
	await frames(30); await capture("probe_plain_surface")
	shader=Shader.new(); shader.code=code.replace("depth_draw_opaque","depth_draw_always")
	game.world.ocean_material.shader=shader
	preload("res://scripts/world/wave_field.gd").bind(game.world.ocean_material)
	await frames(30); await capture("probe_depth_write")
	game.audio.stop_all(); OS.delay_msec(100); game.queue_free(); await process_frame; quit()
