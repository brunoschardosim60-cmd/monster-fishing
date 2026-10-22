extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("81949c");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;scene.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);scene.add_child(sun)
	for i: int in 4:
		var roof: Node3D=load("res://assets/environment/harbor_roof_%d.glb"%i).instantiate();scene.add_child(roof);roof.scale=Vector3(8,3,7);roof.position.x=i*11-16
		for part: Node in roof.find_children("*","MeshInstance3D",true,false):
			part.material_override=preload("res://scripts/world/geometry.gd").material(Color("c39b73"));print(i," ",part.get_aabb()," ",part.transform)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(1,16,-32);camera.look_at(Vector3(0,0,0));camera.current=true
	for i: int in 8:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://tests/output/roof-preview.png");quit()
