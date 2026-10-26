extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var view:=SubViewport.new();view.size=Vector2i(1200,800);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var display:=TextureRect.new();display.texture=view.get_texture();root.add_child(display)
	var scene:=Node3D.new();view.add_child(scene)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("879ba0");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.65;env.environment=e;scene.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);scene.add_child(sun)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
	for key: String in ["survivalist","tugboat"]:
		var asset:=preload("res://scripts/assets/external_model.gd").new()
		var folder: String={"harbor":"environment","survivalist":"characters","goat":"props","dragon":"monsters","tugboat":"boats"}[key]
		asset.asset_path="res://assets/"+folder+"/"+key+".glb";asset.material_family="original" if key in ["goat","survivalist"] else ("boat" if key=="tugboat" else "creature")
		asset.length_m=10. if key!="harbor" else 30.;asset.heading_degrees=0.;asset.waterline_m=0.;scene.add_child(asset)
		camera.position=Vector3(16,11,21) if key!="harbor" else Vector3(30,24,33);camera.look_at(Vector3(0,4,0))
		for i: int in 30:await process_frame
		await RenderingServer.frame_post_draw;view.get_texture().get_image().save_png("res://tests/output/"+key+"-preview.png")
		print("GALLERY ",key," bounds=",asset.bounds);asset.queue_free();await process_frame
	view.queue_free();await process_frame;quit()
