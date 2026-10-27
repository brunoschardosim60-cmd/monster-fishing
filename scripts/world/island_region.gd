extends Node3D
## Terrain is divided into 80 m chunks; foliage and local collision share each chunk.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
const Details=preload("res://scripts/world/coastal_details.gd")
const Materials=preload("res://scripts/visuals/materials.gd")
const Nature=preload("res://scripts/world/nature_library.gd")
var world: Node3D
var terrain_material: ShaderMaterial
var chunks: Array[Node3D]=[]
var tree_templates: Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var foliage_count: int=0
var distant_material: StandardMaterial3D
var grass_mesh: ArrayMesh

func _ready() -> void:
	rng.seed=711024
	distant_material=StandardMaterial3D.new();distant_material.albedo_texture=load("res://assets/textures/pine_impostor.png")
	distant_material.albedo_color=Color(.33,.43,.26)
	distant_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;distant_material.alpha_scissor_threshold=.35
	distant_material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;distant_material.billboard_keep_scale=true;distant_material.cull_mode=BaseMaterial3D.CULL_DISABLED;distant_material.roughness=1.
	terrain_material=ShaderMaterial.new();terrain_material.shader=preload("res://assets/shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("meadow_tex",load("res://assets/textures/meadow_color.jpg"))
	terrain_material.set_shader_parameter("floor_tex",load("res://assets/textures/forest_floor_color.jpg"))
	terrain_material.set_shader_parameter("ground_normal",load("res://assets/textures/forest_floor_normal.jpg"))
	for key: String in ["sand_color","sand_normal","rock_tex","rock_normal","noise_tex"]:
		var file: String={"rock_tex":"cliff_granite_color","rock_normal":"granite_normal","noise_tex":"cloud_noise"}.get(key,key)
		terrain_material.set_shader_parameter(key,load("res://assets/textures/"+file+".png"))
	world.terrain_materials.append(terrain_material)
	_make_grass_template()
	for x: int in range(-6,5):
		for z: int in range(-1,14): _chunk(Vector2(x*80,z*80))
	_make_cliffs()
	_make_sea_arch()
	# The surface template is no longer needed after extracting reusable meshes.

func _chunk(origin: Vector2) -> void:
	if Layout.coast(origin+Vector2(40,40)).x>65.: return
	var chunk:=Node3D.new();chunk.name="Terrain_%d_%d"%[origin.x,origin.y];add_child(chunk);chunks.append(chunk)
	chunk.position=Vector3(origin.x,0,origin.y)
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	const N: int=32
	_grid.resize((N+1)*(N+1));_grid_origin=origin
	for z: int in N+1:
		for x: int in N+1:
			var p:=origin+Vector2(x*2.5,z*2.5);var h:=Layout.height(p)
			_grid[z*(N+1)+x]=h
			vertices.append(Vector3(x*2.5,h,z*2.5))
			normals.append(Vector3(Layout.height(p-Vector2(1,0))-Layout.height(p+Vector2(1,0)),2.,Layout.height(p-Vector2(0,1))-Layout.height(p+Vector2(0,1))).normalized())
			var path:=Layout.path_at(p).x;var col:=Color("45653e")
			if Layout.coast(p).x> -14.+Layout.noise(p,3.)*3.5 or path<3.4 or Layout.plot_ground(p): col=Color("a99b76")
			colors.append(col)
	for z: int in N:
		for x: int in N:
			var a:=z*(N+1)+x;var b:=a+1;var c:=a+N+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var terrain:=G.mesh_node(chunk,mesh,terrain_material,Vector3.ZERO);terrain.name="WalkableGround"
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();body.add_child(collision);chunk.add_child(body)
	_living_forest(chunk,origin)
	_ground_cover(chunk,origin)

## Heights of the chunk being built (its 33×33 terrain samples): plants are set on the surface exactly
## as meshed, the same plane the collision uses (Layout.ground does this for any point, slower).
var _grid:=PackedFloat32Array()
var _grid_origin:=Vector2.ZERO
func _gh(p: Vector2) -> float:
	var g:=(p-_grid_origin)/2.5
	var ix: int=int(floorf(g.x));var iz: int=int(floorf(g.y))
	if ix<0 or iz<0 or ix>=32 or iz>=32:return Layout.ground(p)
	var fx: float=g.x-float(ix);var fz: float=g.y-float(iz)
	var a: float=_grid[iz*33+ix];var b: float=_grid[iz*33+ix+1];var c: float=_grid[(iz+1)*33+ix];var d: float=_grid[(iz+1)*33+ix+1]
	if fx+fz<=1.:return a+(b-a)*fx+(c-a)*fz
	return d+(c-d)*(1.-fx)+(b-d)*(1.-fz)

func _living_forest(chunk: Node3D,origin: Vector2) -> void:
	var kinds: Array[Array]=[[],[],[],[],[]]
	for i: int in 60:
		var p:=origin+Vector2(rng.randf_range(2,78),rng.randf_range(2,78));var h:=_gh(p);var coast:=Layout.coast(p).x
		if coast> -9. or h>170. or Layout.path_at(p).x<6. or (p.y<76. and absf(p.x)<110.) or Layout.in_town(p) or Layout.near_avenue(p,6.):continue
		if p.distance_to(Vector2(-110,310))<28. or p.distance_to(Vector2(-80,775))<32. or p.distance_to(Vector2(-170,210))<14.:continue
		var slope:=absf(_gh(p+Vector2(2,0))-h)+absf(_gh(p+Vector2(0,2))-h)
		if slope>2.2:continue
		# On a slope the trunk is set a little into the hill, so its downhill side shows no gap.
		h-=minf(.6,slope*.18)+.05
		var kind:=rng.randi_range(0,1)
		if coast> -45. or (p.y<150. and rng.randf()<.55):kind=rng.randi_range(2,3)
		var size:=rng.randf_range(.7,1.4)
		var t:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(p.x-origin.x,h,p.y-origin.y))
		kinds[kind].append(t);foliage_count+=1
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.26*size;cylinder.height=4.*size;shape.shape=cylinder;shape.position=t.origin+Vector3(0,2.*size,0);body.add_child(shape);chunk.add_child(body)
	for i: int in 70:
		var p:=origin+Vector2(rng.randf_range(1,79),rng.randf_range(1,79));var h:=_gh(p)
		if Layout.coast(p).x> -16. or Layout.path_at(p).x<3.3 or Layout.plot_ground(p) or Layout.in_town(p) or Layout.near_avenue(p,4.) or h>155.:continue
		if p.y<75. and absf(p.x)<110.:continue
		if absf(_gh(p+Vector2.ONE)-h)>1.:continue
		h-=.06
		kinds[4].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.7,1.6)),Vector3(p.x-origin.x,h,p.y-origin.y)))
	for kind: int in 5:
		var transforms: Array[Transform3D]=[];transforms.assign(kinds[kind]);Nature.grove(chunk,kind,transforms)

func _make_cliffs() -> void:
	for p: Vector2 in [Vector2(-220,410),Vector2(-270,520),Vector2(-250,730),Vector2(-170,860),Vector2(-85,900),Vector2(20,890),Vector2(190,750),Vector2(200,560),Vector2(-205,270),Vector2(160,270),Vector2(40,350)]:
		if Layout.path_at(p).x<22.:continue
		var h:=Layout.height(p)
		var node:=Nature.plant(self,5,Vector3(p.x,h-3.,p.y),rng.randf_range(.7,1.5),rng.randf()*TAU)
		for part: Node in node.get_children():
			if part is MeshInstance3D:
				var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var shape:=CollisionShape3D.new();shape.shape=part.mesh.create_trimesh_shape();body.add_child(shape);part.add_child(body)

func _make_sea_arch() -> void:
	# The western pillar grows out of the headland; the central channel remains open.
	for p: Vector3 in [Vector3(232,-5,305),Vector3(223,-5,325),Vector3(239,-4,289)]:
		var rock:=Nature.plant(self,5,p,2.1,rng.randf()*TAU)
		for part: Node in rock.get_children():
			if part is MeshInstance3D:
				var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
				var shape:=CollisionShape3D.new();shape.shape=part.mesh.create_trimesh_shape();body.add_child(shape);part.add_child(body)
	var arch: Node3D=preload("res://assets/environment/geology/aurora_sea_arch.glb").instantiate()
	arch.name="ArcoDasMares";arch.position=Vector3(285,0,275);add_child(arch)
	for part: Node in arch.find_children("*","MeshInstance3D",true,false):
		part.material_override=Materials.surface("cliff_granite",Color.WHITE,.13)
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();shape.shape=part.mesh.create_trimesh_shape();body.add_child(shape);part.add_child(body)

func _make_grass_template() -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 9:
		var a:=float(i)*2.4;var side:=Vector3(cos(a),0,sin(a))*.018
		var base:=Vector3(sin(a)*.16,0,cos(a)*.16);var tip:=base+Vector3(cos(a)*.14,.24+fposmod(i*.13,.22),sin(a)*.14)
		for p: Vector3 in [base-side,tip,base+side]:
			st.set_color(Color("35472a").lerp(Color("8e9550"),p.y));st.set_normal(Vector3.UP);st.add_vertex(p)
	grass_mesh=st.commit()

func _ground_cover(chunk: Node3D,origin: Vector2) -> void:
	var instances: Array[Transform3D]=[]
	for i: int in 900:
		var p:=origin+Vector2(rng.randf_range(0,80),rng.randf_range(0,80))
		if p.y<75. and absf(p.x)<110.:continue
		if Layout.coast(p).x> -13. or Layout.path_at(p).x<4. or Layout.near_avenue(p,2.5):continue
		var h:=_gh(p)
		if h>100. or absf(_gh(p+Vector2(1,0))-h)>.55:continue
		instances.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.8,1.6)),Vector3(p.x-origin.x,h-.02,p.y-origin.y)))
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=grass_mesh;multi.instance_count=instances.size()
	for i: int in instances.size():multi.set_instance_transform(i,instances[i])
	var node:=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=Details.leaves_material();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=90.;node.visibility_range_end_margin=15.;chunk.add_child(node)

func _make_tree_templates() -> void:
	for variant: int in 3:
		var temp:=Node3D.new();add_child(temp)
		var tree:=Details.pine(temp,Vector3.ZERO,1.,rng,Materials.surface("weathered_wood",Color("5d5844"),3.))
		var wood:=SurfaceTool.new();wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		var foliage: Mesh
		for node: Node in tree.get_children():
			if node is MeshInstance3D:
				if node.material_override==Details.pine_leaves_material(): foliage=node.mesh
				else: wood.append_from(node.mesh,0,node.transform)
		tree_templates.append({"wood":wood.commit(),"leaves":foliage})
		remove_child(temp);temp.free()

func _forest(chunk: Node3D, origin: Vector2) -> void:
	var transforms: Array[Transform3D]=[]
	for i: int in 38:
		var p:=origin+Vector2(rng.randf_range(1.,79.),rng.randf_range(1.,79.))
		var c:=Layout.coast(p).x;var h:=_gh(p)
		if c> -20. or h>108. or Layout.path_at(p).x<7. or (p.y<75. and absf(p.x)<110.): continue
		if p.distance_to(Vector2(-80,775))<32. or p.distance_to(Vector2(-170,210))<14.: continue
		if p.distance_to(Vector2(-110,310))<28.:continue
		var slope:=absf(_gh(p+Vector2(2,0))-h)+absf(_gh(p+Vector2(0,2))-h)
		if slope>2.: continue
		h-=minf(.6,slope*.18)+.05
		var s:=rng.randf_range(1.2,2.5);var t:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s,s*rng.randf_range(.9,1.25),s)),Vector3(p.x-origin.x,h,p.y-origin.y))
		transforms.append(t);foliage_count+=1
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();var trunk:=CylinderShape3D.new();trunk.radius=.22*s;trunk.height=4.*s;shape.shape=trunk;shape.position=t.origin+Vector3(0,2.*s,0);body.add_child(shape);chunk.add_child(body)
	if transforms.is_empty(): return
	var template: Dictionary=tree_templates[absi(int(origin.x+origin.y)/80)%3]
	for kind: String in ["wood","leaves"]:
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=template[kind];multi.instance_count=transforms.size()
		for i: int in transforms.size(): multi.set_instance_transform(i,transforms[i])
		var node:=MultiMeshInstance3D.new();node.multimesh=multi
		node.material_override=Details.pine_leaves_material() if kind=="leaves" else Materials.surface("weathered_wood",Color("5d5844"),3.)
		node.visibility_range_end=110.;node.visibility_range_end_margin=15.
		if kind=="leaves":node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.add_child(node)
	# A closed canopy proxy avoids rendering thousands of alpha-tested needles
	# again in each shadow cascade; visible foliage keeps its full detail.
	var canopy:=SphereMesh.new();canopy.radius=1.9;canopy.height=3.6;canopy.radial_segments=12;canopy.rings=6
	var shadows:=MultiMesh.new();shadows.transform_format=MultiMesh.TRANSFORM_3D;shadows.mesh=canopy;shadows.instance_count=transforms.size()
	for i: int in transforms.size():shadows.set_instance_transform(i,transforms[i]*Transform3D(Basis.IDENTITY,Vector3(0,3.7,0)))
	var shadow_node:=MultiMeshInstance3D.new();shadow_node.multimesh=shadows;shadow_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;shadow_node.visibility_range_end=110.;chunk.add_child(shadow_node)
	var quad:=QuadMesh.new();quad.size=Vector2(6.5,6.5);quad.center_offset=Vector3(0,3.25,0)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=quad;multi.instance_count=transforms.size()
	for i: int in transforms.size():multi.set_instance_transform(i,transforms[i])
	var far_trees:=MultiMeshInstance3D.new();far_trees.multimesh=multi;far_trees.material_override=distant_material
	far_trees.visibility_range_begin=110.;far_trees.visibility_range_begin_margin=15.;far_trees.visibility_range_end=1500.;far_trees.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;chunk.add_child(far_trees)
