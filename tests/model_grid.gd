extends SceneTree
# usage: --script _grid.gd -- out.png yaw pitch res1 res2 ...
func _init():
	var args=OS.get_cmdline_user_args()
	var out=args[0]; var yaw=float(args[1]); var pitch=float(args[2]); var list=args.slice(3)
	var cols=mini(4,list.size()); var rows=ceili(list.size()/float(cols))
	root.size=Vector2i(400,400)
	var env=WorldEnvironment.new(); var e=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color(.5,.6,.7); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color(.55,.55,.6); e.tonemap_mode=Environment.TONE_MAPPER_FILMIC; env.environment=e; root.add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-45,-40,0); sun.light_energy=1.3; root.add_child(sun)
	var cam=Camera3D.new(); root.add_child(cam); cam.fov=35
	var img=Image.create(400*cols,400*rows,false,Image.FORMAT_RGBA8)
	await process_frame
	for i in list.size():
		var r=load(list[i]); var n:Node3D
		if r is PackedScene: n=r.instantiate()
		else:
			var mi:=MeshInstance3D.new(); mi.mesh=r; n=mi
			var sizes={"container_ship":240.,"cargo_ship":88.,"sailing_ship":40.,"rowboat":4.5,"shark":4.,"turtle":1.2,"crab":.4,"serpent":28.}
			var nm:String=list[i].get_file().get_basename(); var L:float=sizes.get(nm,.6)
			var mat:=ShaderMaterial.new(); mat.shader=load("res://assets/shaders/imported_model.gdshader"); mi.material_override=mat
			mi.set_instance_shader_parameter("model_scale",L); mi.set_instance_shader_parameter("hull_paint",Color("1f3d5c") if i%2==0 else Color("7a1f2b"))
			if nm=="rowboat": mi.set_instance_shader_parameter("hull_paint",Color("3d8b7a"))
			mi.scale=Vector3.ONE*L
			if L>3.:
				var sea:=MeshInstance3D.new(); var pm:=PlaneMesh.new(); pm.size=Vector2(2,2); sea.mesh=pm; sea.scale=Vector3.ONE*L
				var sm:=StandardMaterial3D.new(); sm.albedo_color=Color(.1,.3,.4,.55); sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; sea.material_override=sm; mi.add_child(sea); sea.scale=Vector3.ONE
		root.add_child(n); await process_frame
		var ab:=AABB(); var first=true
		for mi in [n]+n.find_children("*","MeshInstance3D",true,false):
			if not (mi is MeshInstance3D) or mi.mesh is PlaneMesh: continue
			var b=mi.global_transform*mi.mesh.get_aabb()
			ab=b if first else ab.merge(b); first=false
		cam.rotation_degrees=Vector3(pitch,yaw,0)
		cam.position=ab.get_center()+cam.basis.z*ab.size.length()*1.3; print(list[i]," ",ab," cam ",cam.global_transform)
		for k in 4: await process_frame
		var im=root.get_texture().get_image(); im.convert(Image.FORMAT_RGBA8)
		var sq=mini(im.get_width(),im.get_height()); im=im.get_region(Rect2i((im.get_width()-sq)/2,(im.get_height()-sq)/2,sq,sq)); im.resize(400,400)
		img.blit_rect(im,Rect2i(0,0,400,400),Vector2i((i%cols)*400,(i/cols)*400))
		n.queue_free(); await process_frame
	img.save_png(out); quit()
