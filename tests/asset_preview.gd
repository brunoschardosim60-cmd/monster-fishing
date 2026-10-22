extends SceneTree
var view: SubViewport
func _initialize() -> void: call_deferred("run")
func run() -> void:
	view=SubViewport.new(); view.size=Vector2i(1200,800); view.own_world_3d=true
	root.add_child(view)
	var display:=TextureRect.new(); display.texture=view.get_texture(); display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(display)
	var scene:=Node3D.new(); view.add_child(scene)
	var env:=WorldEnvironment.new(); var e:=Environment.new(); e.background_mode=Environment.BG_COLOR;e.background_color=Color("8ea5ad");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.6;e.tonemap_mode=Environment.TONE_MAPPER_ACES;env.environment=e;scene.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.shadow_enabled=true;scene.add_child(sun)
	var asset: Node3D=load("res://scenes/models/fishing_boat_model.tscn").instantiate();scene.add_child(asset)
	var camera:=Camera3D.new();camera.position=Vector3(10,6,12);scene.add_child(camera);camera.look_at(Vector3(0,2,0));camera.current=true
	for i: int in 40: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://tests/output/fishing-boat-asset.png")
	print("ASSET_PREVIEW bounds=",asset.bounds," meshes=",asset.meshes.size())
	view.queue_free();await process_frame;quit()
