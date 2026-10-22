extends RefCounted
const G = preload("res://scripts/world/geometry.gd")
const M = preload("res://scripts/visuals/materials.gd")
static var foliage_material: StandardMaterial3D
static var pine_material: StandardMaterial3D

static func pine_leaves_material() -> StandardMaterial3D:
	if pine_material==null:
		pine_material=leaves_material().duplicate()
		pine_material.albedo_texture=load("res://assets/textures/pine_frond.png")
		pine_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		pine_material.alpha_scissor_threshold=.4
		pine_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return pine_material

static func leaves_material() -> StandardMaterial3D:
	if foliage_material==null:
		foliage_material=StandardMaterial3D.new()
		foliage_material.vertex_color_use_as_albedo=true
		foliage_material.cull_mode=BaseMaterial3D.CULL_DISABLED
		foliage_material.roughness=.95
	return foliage_material

static func pine(parent: Node3D, pos: Vector3, scale_value: float, rng: RandomNumberGenerator, bark: Material) -> Node3D:
	var tree := Node3D.new()
	parent.add_child(tree)
	tree.position = pos
	tree.scale = Vector3.ONE * scale_value
	tree.rotation.y = rng.randf() * TAU
	G.cylinder(tree,Vector3(.08,2.5,0),.21,5.,bark,.055,12)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level: int in range(6):
		var y := 2.2 + level * .57
		var reach := 2.2 - level * .29
		for branch: int in range(7):
			var angle := float(branch)*TAU/7. + level*.83 + rng.randf_range(-.3,.3)
			var direction := Vector3(cos(angle),0,sin(angle))
			var start := Vector3(0,y,0)
			var end := start + direction*reach + Vector3(0,.38,0)
			G.beam(tree,start,end,.045 if level<3 else .027,bark)
			for tuft: int in range(13):
				var center := start.lerp(end,rng.randf_range(.36,1.14))
				center += Vector3(rng.randf_range(-.38,.38),rng.randf_range(-.2,.3),rng.randf_range(-.38,.38))
				var color := Color("749d5b").lerp(Color("b9c383"),rng.randf()*.7)
				for needle: int in range(3):
					var a := rng.randf()*TAU
					var forward := Vector3(cos(a),rng.randf_range(.12,.5),sin(a))*.62
					var side := Vector3(-sin(a),.15,cos(a))*.3
					var points: Array[Vector3]=[center-side,center+side,center+forward+side,center+forward-side]
					var uv: Array[Vector2]=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
					for index: int in [0,2,1,0,3,2]:
						leaves.set_color(color)
						leaves.set_normal(Vector3.UP)
						leaves.set_uv(uv[index])
						leaves.add_vertex(points[index])
	G.mesh_node(tree,leaves.commit(),pine_leaves_material(),Vector3.ZERO)
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius=.24
	cylinder.height=3.4
	shape.shape=cylinder
	shape.position.y=1.7
	body.add_child(shape)
	tree.add_child(body)
	return tree

static func shrub(parent: Node3D,pos: Vector3,rng: RandomNumberGenerator) -> void:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem: int in range(18):
		var angle:=rng.randf()*TAU
		var reach:=rng.randf_range(.25,.6)
		var end:=Vector3(cos(angle)*reach,rng.randf_range(.25,.65),sin(angle)*reach)
		for leaf: int in range(7):
			var center:=end*float(leaf+1)/8.
			var direction:=Vector3(cos(angle+leaf*2.4),.2,sin(angle+leaf*2.4))*.19
			var width:=direction.cross(Vector3.UP).normalized()*.055
			var color:=Color("3d5030").lerp(Color("7f8950"),rng.randf())
			for v: Vector3 in [center,center+direction*.5+width,center+direction,center,center+direction,center+direction*.5-width]:
				st.set_color(color)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	G.mesh_node(parent,st.commit(),leaves_material(),pos)

static func stone(parent: Node3D,pos: Vector3,size: Vector3,mat: Material,seed_value: int) -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed=seed_value
	noise.frequency=1.8
	var source := SphereMesh.new()
	source.radial_segments=28
	source.rings=16
	source.radius=1
	source.height=2
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in vertices.size():
		var v := vertices[i]
		var f := 1.+noise.get_noise_3dv(v)*.33
		vertices[i]=v*f*size
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh,0)
	st.generate_normals()
	var node := G.mesh_node(parent,st.commit(),mat,pos)
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	var collision := CollisionShape3D.new()
	collision.shape=node.mesh.create_convex_shape()
	body.add_child(collision)
	node.add_child(body)
	return node

static func dress_harbor(parent: Node3D,rng: RandomNumberGenerator,wood: Material,dark: Material,stone_mat: Material) -> void:
	# Functional details sit beside existing routes, never across the boarding gap.
	var metal := G.material(Color("525d60"),.33)
	metal.metallic=.7
	for z: float in [-11,-16,-21,-25]:
		for x: float in [-1.48,1.48]:
			for offset: float in [-.11,.11]:
				G.cylinder(parent,Vector3(x+offset,1.405,z),.025,.012,metal,.025,8)
	for z: float in [-12,-18]:
		for x: float in [-1.66,1.66]:
			var tire := TorusMesh.new()
			tire.inner_radius=.17
			tire.outer_radius=.31
			tire.rings=24
			tire.ring_segments=12
			var node := G.mesh_node(parent,tire,G.material(Color("272b2c")),Vector3(x,.82,z))
			node.rotation.z=PI*.5
			G.beam(parent,Vector3(x,1.8,z),Vector3(x,.9,z),.022,wood)
	# Hand-laid stone footings around the cabin and planted shore margins.
	for i: int in range(12):
		stone(parent,Vector3(-15+i*.55,1.37,3.8),Vector3(.27,.15,.25),stone_mat,650+i)
	var grass_mesh := SurfaceTool.new()
	grass_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in range(7):
		var angle := blade*2.4
		var side := Vector3(cos(angle),0,sin(angle))*.035
		var base := Vector3(sin(angle)*.07,0,cos(angle)*.07)
		var tip := base+Vector3(sin(angle)*.15,.35+blade*.04,cos(angle)*.15)
		for v: Vector3 in [base-side,tip,base+side]:
			grass_mesh.set_color(Color("344225").lerp(Color("92945b"),v.y*1.3))
			grass_mesh.set_normal(Vector3.UP)
			grass_mesh.add_vertex(v)
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=grass_mesh.commit()
	var positions: Array[Transform3D]=[]
	for i: int in range(2400):
		var x:=rng.randf_range(-25,25)
		var z:=rng.randf_range(-6,45)
		if Vector2(x/29.,(z-18.)/32.).length()>.78 or absf(x)<3.8: continue
		if Vector2(x+12,z-7).length()<5.6 or Vector2(x-13,z-16).length()<5.6: continue
		if z<2 and x>1: continue
		var ground: float=parent.home_surface_height(x,z)
		if ground>5.: continue
		var scale_value:=rng.randf_range(.65,1.5)
		positions.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(x,ground-.035,z)))
	multi.instance_count=positions.size()
	for i: int in positions.size(): multi.set_instance_transform(i,positions[i])
	var grass:=MultiMeshInstance3D.new()
	grass.multimesh=multi
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=1.
	grass.material_override=material
	grass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end=110
	parent.add_child(grass)
