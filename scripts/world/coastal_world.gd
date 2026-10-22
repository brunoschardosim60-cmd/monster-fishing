extends Node3D
## Phase 1: one seamless playable coast and a navigable ocean.
const G = preload("res://scripts/world/geometry.gd")
const OCEAN = preload("res://assets/shaders/ocean.gdshader")
const Materials = preload("res://scripts/visuals/materials.gd")
const Details = preload("res://scripts/world/coastal_details.gd")
const Waves = preload("res://scripts/world/wave_field.gd")
var ocean_material: ShaderMaterial
var environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var ocean: Node3D
var terrain_materials: Array[ShaderMaterial]=[]
var shore_rocks: Array[Vector3]=[]
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var region: Node3D
var village: Node3D
var water_root: Node3D
var life: Node3D
var traffic: Node3D
var lighthouse: Node3D
var harbor_lighthouse: Node3D

var rng := RandomNumberGenerator.new()
var gulls: Array[Node3D] = []
var buoys: Array[Node3D] = []
var elapsed: float = 0.0
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var cream: StandardMaterial3D
var teal: StandardMaterial3D
var leaf: StandardMaterial3D
var leaf_light: StandardMaterial3D
var rock: StandardMaterial3D

func _ready() -> void:
	rng.seed = 241019
	wood = Materials.surface("weathered_wood", Color("d0b894"), 1.1)
	dark_wood = Materials.surface("weathered_wood", Color("655646"), 1.5)
	cream = Materials.surface("paint", Color("c4c4ac"), 1.8)
	teal = Materials.surface("paint", Color("3a6467"), 1.4)
	leaf = G.material(Color("345e49"))
	leaf_light = G.material(Color("527959"))
	rock = Materials.surface("granite", Color("a5aaa3"), 1.2)
	_make_lighting()
	_make_ocean()
	region=preload("res://scripts/world/island_region.gd").new();region.world=self;region.name="AuroraIsland";add_child(region)
	for i: int in range(4,7):
		var island:=Layout.LOBES[i]
		_make_island(Vector3(island.x,0,island.y),Vector2(island.z,island.w),false)
	_make_dock()
	village=preload("res://scripts/world/harbor_village.gd").new();village.world=self;village.name="VilaDaAurora";add_child(village)
	_make_lighthouse(Vector3(-65,Layout.height(Vector2(-65,490)),490))
	harbor_lighthouse=preload("res://scripts/world/navigation_lighthouse.gd").new();harbor_lighthouse.world=self;harbor_lighthouse.position=Vector3(174,Layout.height(Vector2(174,96)),96);harbor_lighthouse.name="FarolDaEntrada";add_child(harbor_lighthouse)
	_make_sign()
	for p: Vector3 in [Vector3(-17, 0, -36), Vector3(24, 0, -60), Vector3(-40, 0, -98), Vector3(59, 0, -114)]:
		_make_buoy(p)
	var dynamic_roots: Array[Node3D] = []
	dynamic_roots.append_array(gulls)
	dynamic_roots.append_array(buoys)
	dynamic_roots.append(region);dynamic_roots.append(village);dynamic_roots.append(lighthouse);dynamic_roots.append(harbor_lighthouse)
	preload("res://scripts/world/static_batch.gd").build(self, dynamic_roots)
	ocean=preload("res://scripts/ocean/ocean_environment.gd").new()
	ocean.world=self; ocean.name="OceanEnvironment"; add_child(ocean)
	traffic=preload("res://scripts/world/maritime_traffic.gd").new();traffic.name="TrafegoMaritimo";add_child(traffic)
	life=preload("res://scripts/world/coastal_life.gd").new();life.world=self;life.name="CoastalLife";add_child(life)

func safe_spawn() -> Vector3:
	return Vector3(0.0, 1.55, -17.0)

func is_land(pos: Vector3) -> bool:
	if ocean!=null and ocean.is_ice(pos): return true
	if Layout.coast(Vector2(pos.x,pos.z)).x< -1.5: return true
	return absf(pos.x) < 1.8 and pos.z > -26.5 and pos.z < -7.0

func _make_lighting() -> void:
	get_viewport().use_occlusion_culling=true
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	environment=env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_material=sky_mat
	sky_mat.shader = preload("res://assets/shaders/coastal_sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", load("res://assets/textures/cloud_noise.png"))
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.5
		env.ssr_enabled = true
		env.ssr_max_steps = 20
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_bloom = 0.0
	else:
		env.adjustment_contrast = 1.0
		env.ambient_light_energy = .8
	env.fog_enabled = true
	env.fog_light_color = Color("7c9da8")
	env.fog_light_energy = 0.7
	env.fog_density = 0.0023
	env.fog_sky_affect = 0.04
	env_node.environment = env
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-17, 145, 0)
	sun.light_color = Color("ffd4a0")
	sun.light_energy = 1.25
	sun.light_angular_distance = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.10
	add_child(sun)
	sky_mat.set_shader_parameter("sun_direction", sun.global_basis.z.normalized())

func _make_ocean() -> void:
	water_root=Node3D.new();water_root.name="FollowingOceanGrid";add_child(water_root)
	var plane := PlaneMesh.new()
	plane.size = Vector2(480, 480)
	plane.subdivide_width = 480
	plane.subdivide_depth = 480
	var mat := ShaderMaterial.new()
	mat.shader = OCEAN
	ocean_material = mat
	mat.set_shader_parameter("normal_tex", load("res://assets/textures/water_normal.png"))
	mat.set_shader_parameter("foam_tex", load("res://assets/textures/foam_noise.png"))
	var water := G.mesh_node(water_root, plane, mat, Vector3.ZERO)
	water.name = "Ocean"
	water.custom_aabb=AABB(Vector3(-240,-8,-240),Vector3(480,16,480))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Four coarse horizon strips avoid doubling the fine mesh under the bay.
	for data: Vector4 in [Vector4(0,-6120,24000,11760),Vector4(0,6120,24000,11760),Vector4(-6120,0,11760,480),Vector4(6120,0,11760,480)]:
		var far_mesh := PlaneMesh.new()
		far_mesh.size = Vector2(data.z, data.w)
		far_mesh.subdivide_width = 32
		far_mesh.subdivide_depth = 32
		var far_water := G.mesh_node(water_root, far_mesh, mat, Vector3(data.x,0,data.y))
		far_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_island(center: Vector3, size: Vector2, playable: bool) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	const RINGS: int = 48
	const SEGMENTS: int = 128
	for ring: int in range(RINGS + 1):
		var radius := float(ring) / float(RINGS)
		for segment: int in range(SEGMENTS):
			var angle := float(segment) / float(SEGMENTS) * TAU
			var edge := 1.0 + sin(angle * 5.0) * 0.025 + cos(angle * 9.0) * 0.016
			var x := cos(angle) * radius * size.x * edge
			var z := sin(angle) * radius * size.y * edge
			var height := _island_height(x,z,radius,playable)
			vertices.append(center + Vector3(x, height, z))
			var variation := rng.randf_range(-0.035, 0.035)
			var col := Color("a99b76")
			if radius < 0.68 and z > -18.0:
				col = Color("506c4d")
				if absf(x) < 2.6 or (absf(z + 10.0) < 2.6 and x > -13.0 and x < 14.0):
					col = Color("998b67")
			col = col.lightened(variation) if variation > 0 else col.darkened(-variation)
			colors.append(col)
	for ring: int in range(RINGS):
		for segment: int in range(SEGMENTS):
			var a := ring * SEGMENTS + segment
			var b := ring * SEGMENTS + (segment + 1) % SEGMENTS
			var c := (ring + 1) * SEGMENTS + segment
			var d := (ring + 1) * SEGMENTS + (segment + 1) % SEGMENTS
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var mesh := G.polygon_mesh(vertices, indices, colors)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/terrain.gdshader")
	mat.set_shader_parameter("meadow_tex",load("res://assets/textures/meadow_color.jpg"))
	mat.set_shader_parameter("floor_tex",load("res://assets/textures/forest_floor_color.jpg"))
	mat.set_shader_parameter("ground_normal",load("res://assets/textures/forest_floor_normal.jpg"))
	terrain_materials.append(mat)
	mat.set_shader_parameter("sand_color", load("res://assets/textures/sand_color.png"))
	mat.set_shader_parameter("sand_normal", load("res://assets/textures/sand_normal.png"))
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/cloud_noise.png"))
	mat.set_shader_parameter("rock_tex",load("res://assets/textures/granite_color.png"))
	mat.set_shader_parameter("rock_normal",load("res://assets/textures/granite_normal.png"))
	var island := G.mesh_node(self, mesh, mat, Vector3.ZERO)
	island.name = "HomeIsland" if playable else "DistantIsland"
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	island.add_child(body)
	if not playable:
		# Exposed headlands form a rocky surf zone, leaving the original routes open.
		for j: int in [0,1,3,4,5,6,7]:
			var a:=float(j)*TAU/8.
			_make_rock(center+Vector3(cos(a)*size.x*.99,-.05,sin(a)*size.y*.99),Vector3(2.8,2.1,3.5))
		for i: int in range(12):
			var angle := rng.randf() * TAU
			var r := rng.randf_range(0.1, 0.56)
			var x:=cos(angle)*r*size.x
			var z:=sin(angle)*r*size.y
			_make_tree(center+Vector3(x,_island_height(x,z,r,false),z),rng.randf_range(.7,1.3))

func _island_height(x: float,z: float,radius: float,playable: bool) -> float:
	var h:=1.25
	if playable:
		# The harbor, market and cabins retain their original flat circulation area.
		var ridge:=exp(-pow((x+10.)/13.,2.)-pow((z-15.)/13.,2.))*14.
		ridge+=exp(-pow((x-12.)/9.,2.)-pow((z-22.)/11.,2.))*10.
		var erosion:=1.+sin(x*.57+z*.22)*.11+sin(z*.61-x*.2)*.08
		ridge=ridge*erosion+sin(x*1.3+z*.7)*.65+sin(z*1.1-x*.8)*.4
		var stratum:=ridge/2.8
		ridge=lerpf(ridge,(floorf(stratum)+smoothstep(.55,.95,fposmod(stratum,1.)))*2.8,.55)
		h+=ridge*smoothstep(4.,14.,z)*(1.-smoothstep(.72,.98,radius))
	else:
		h+=pow(maxf(0.,1.-radius/.87),.95)*(18.+sin(x*.2+z*.13)*5.+cos(z*.24)*3.)
	if radius>.84:
		h=lerpf(h,-.8,smoothstep(.84,1.,radius))
	return h

func home_surface_height(x: float,z: float) -> float:
	return Layout.height(Vector2(x,z))

func _make_dock() -> void:
	G.box(self, Vector3(0, 1.2, -17), Vector3(3.6, 0.3, 18), dark_wood, true)
	G.box(self,Vector3(0,1.2,-5),Vector3(3.6,.3,6),dark_wood,true)
	for i: int in range(45):
		var plank := G.box(self, Vector3(0, 1.365, -8.2 - i * 0.4), Vector3(3.6, 0.055, 0.37), wood if i % 3 else cream)
		plank.material_override = wood
		plank.rotation.y = rng.randf_range(-.004,.004)
	for z: float in [-9.0, -14.0, -19.0, -25.0]:
		for x: float in [-1.65, 1.65]:
			G.cylinder(self, Vector3(x, 0.4, z), 0.16, 3.5, dark_wood, 0.13)
			G.cylinder(self, Vector3(x, 1.97, z), 0.19, 0.12, wood)
	for x: float in [-1.65, 1.65]:
		G.beam(self, Vector3(x, 1.85, -9), Vector3(x, 1.85, -19), 0.035, cream)
		G.beam(self, Vector3(x, 1.7, -9), Vector3(x, 1.7, -19), 0.025, cream)
	# Open boarding gap at the end of the pier.
	G.box(self, Vector3(-1.1, 1.65, -22), Vector3(0.7, 0.55, 1), teal, true)
	G.box(self, Vector3(-1.1, 1.95, -22), Vector3(0.76, 0.08, 1.06), cream)
	_make_lamp(Vector3(-1.55, 1.35, -25))
	_make_lamp(Vector3(1.55, 1.35, -10))

func _make_lamp(pos: Vector3) -> void:
	G.cylinder(self, pos + Vector3(0, 1.15, 0), 0.07, 2.3, dark_wood)
	G.box(self, pos + Vector3(0, 2.4, 0), Vector3(0.28, 0.48, 0.28), dark_wood)
	var glow := G.material(Color("ffd286"))
	glow.emission_enabled = true
	glow.emission = Color("ffc276")
	glow.emission_energy_multiplier = 0.8
	G.box(self, pos + Vector3(0, 2.4, -0.15), Vector3(0.19, 0.31, 0.025), glow)
	G.cylinder(self, pos + Vector3(0, 2.7, 0), 0.25, 0.2, dark_wood, 0.04)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 2.35, 0)
	light.light_color = Color("ffc385")
	light.light_energy = 0.6
	light.omni_range = 6
	add_child(light)

func _make_cabin(pos: Vector3, angle: float, main: bool) -> void:
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = angle
	add_child(house)
	G.box(house, Vector3(0, 0.14, 0), Vector3(6.4, 0.28, 5), rock, true)
	G.box(house, Vector3(0, 1.65, 0), Vector3(5.8, 3.0, 4.6), teal, true)
	for y: float in [0.45, 0.85, 1.25, 1.65, 2.05, 2.45, 2.85]:
		G.box(house, Vector3(0, y, -2.32), Vector3(5.86, 0.035, 0.05), dark_wood)
	for x: float in [-2.95, 2.95]:
		G.box(house, Vector3(x, 1.7, -2.35), Vector3(0.14, 3.1, 0.14), cream)
	var roof_vertices := PackedVector3Array([Vector3(-3.5, 3.1, -2.9), Vector3(3.5, 3.1, -2.9), Vector3(0, 4.8, -2.9), Vector3(-3.5, 3.1, 2.9), Vector3(3.5, 3.1, 2.9), Vector3(0, 4.8, 2.9)])
	var roof_mat := Materials.surface("weathered_wood",Color("947c70") if main else Color("7a8887"),1.8)
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.mesh_node(house, G.polygon_mesh(roof_vertices, PackedInt32Array([0,2,1,3,4,5,0,3,5,0,5,2,2,5,4,2,4,1])), roof_mat, Vector3.ZERO)
	# Clad gables and timber siding give the existing footprint construction scale.
	for x_index: int in range(-6,7):
		var x:=float(x_index)*.46
		var height:=1.7*(1.-absf(x)/3.5)
		for z: float in [-2.92,2.92]:
			G.box(house,Vector3(x,3.1+height*.5,z),Vector3(.43,height,.045),teal)
	for y: float in [.45,.85,1.25,1.65,2.05,2.45,2.85]:
		for x: float in [-2.92,2.92]:
			G.box(house,Vector3(x,y,0),Vector3(.04,.035,4.62),dark_wood)
	for z_index: int in range(15):
		var z:=-2.8+z_index*.4
		G.beam(house,Vector3(-3.5,3.12,z),Vector3(0,4.82,z),.018,roof_mat)
		G.beam(house,Vector3(0,4.82,z),Vector3(3.5,3.12,z),.018,roof_mat)
	for z: float in [-2.95, 2.95]:
		G.beam(house, Vector3(-3.5, 3.1, z), Vector3(0, 4.8, z), 0.095, cream)
		G.beam(house, Vector3(0, 4.8, z), Vector3(3.5, 3.1, z), 0.095, cream)
	G.box(house, Vector3(0, 1.2, -2.38), Vector3(1.05, 2.1, 0.1), dark_wood)
	G.sphere(house, Vector3(0.34, 1.15, -2.46), Vector3(0.055, 0.055, 0.055), cream)
	var warm := G.material(Color("ffcf86"))
	warm.emission_enabled = true
	warm.emission = Color("e3a454")
	warm.emission_energy_multiplier = 0.5
	for x: float in [-1.8, 1.8]:
		G.box(house, Vector3(x, 1.9, -2.39), Vector3(1.2, 1.35, 0.12), cream)
		G.box(house, Vector3(x, 1.9, -2.47), Vector3(1.0, 1.12, 0.05), warm)
		G.box(house, Vector3(x, 1.9, -2.51), Vector3(0.06, 1.12, 0.05), dark_wood)
		G.box(house, Vector3(x, 1.9, -2.51), Vector3(1.0, 0.06, 0.05), dark_wood)
		G.box(house, Vector3(x, 1.15, -2.6), Vector3(1.3, 0.15, 0.42), wood)
		for side: float in [-1.,1.]:
			G.box(house,Vector3(x+side*.78,1.9,-2.40),Vector3(.25,1.3,.07),wood)
	G.box(house, Vector3(1.9, 4.15, 1.3), Vector3(0.6, 2.0, 0.6), rock)
	G.box(house, Vector3(1.9, 5.15, 1.3), Vector3(0.8, 0.15, 0.8), cream)
	G.box(house, Vector3(0, 0.1, -3.1), Vector3(5.6, 0.2, 1.6), wood)
	if main:
		G.label(house, "CABANA DO FAROLEIRO", Vector3(0, 2.8, -2.5), 19)
	_make_lamp(pos + Vector3(-3.6, 0, -3.0))

func _make_market() -> void:
	var stall := Node3D.new()
	stall.position = Vector3(6, 1.25, -3.0)
	add_child(stall)
	G.box(stall, Vector3(0, 0.52, 0), Vector3(3.7, 1.04, 1.45), dark_wood, true)
	for x: float in [-1.6,-0.8,0.0,0.8,1.6]:
		G.box(stall, Vector3(x, 0.52, -0.74), Vector3(0.75, 1.0, 0.08), wood)
	G.box(stall, Vector3(0, 1.06, 0), Vector3(4.1, 0.16, 1.7), cream)
	for x: float in [-1.8, 1.8]:
		G.cylinder(stall, Vector3(x, 1.65, 0.5), 0.09, 3.3, dark_wood)
	var canvas := Materials.surface("fabric",Color("b7a383"),5.)
	G.box(stall, Vector3(0, 3.2, 0), Vector3(4.6, 0.12, 2.5), canvas).rotation.x = 0.12
	G.box(stall, Vector3(0, 2.94, -1.22), Vector3(4.6, 0.4, 0.07), teal)
	var label := G.label(stall, "MERCADO  ·  PEIXE FRESCO", Vector3(0, 2.95, -1.28), 24)
	label.rotation.y = PI
	# Labels face toward the approach from the pier.
	label.rotation.y = PI
	G.box(stall, Vector3(-0.8, 1.22, 0), Vector3(1.4, 0.2, 0.9), teal)
	for i: int in range(4):
		var fish := G.sphere(stall, Vector3(-1.25 + i * 0.3, 1.4, -0.1), Vector3(0.12, 0.1, 0.3), G.material(Color("8caaa4")))
		fish.rotation.y = 0.25
	var vendor=preload("res://scripts/player/imported_angler.gd").new()
	vendor.position=Vector3(6.7,1.25,-1.5);add_child(vendor)
	_make_barrel(Vector3(8.7, 1.25, -2.4))
	_make_barrel(Vector3(9.2, 1.25, -1.3))

func _make_barrel(pos: Vector3) -> void:
	G.cylinder(self, pos + Vector3(0,0.5,0), 0.43, 1.0, wood, 0.39, 12)
	for y: float in [0.15,0.8]:
		G.cylinder(self, pos + Vector3(0,y,0), 0.44, 0.08, dark_wood, 0.44, 12)

func _make_foliage() -> void:
	for i: int in range(30):
		var x := rng.randf_range(-21,21)
		var z := rng.randf_range(0,42)
		if absf(x) < 4.0 or Vector2(x + 12, z - 7).length() < 7.2 or Vector2(x - 13,z - 16).length() < 7.0:
			continue
		if Vector2(x / 29, (z - 18) / 32).length() > 0.74:
			continue
		_make_tree(Vector3(x,home_surface_height(x,z),z), rng.randf_range(0.75,1.35))
	for i: int in range(23):
		var angle := rng.randf() * TAU
		var pos := Vector3(cos(angle) * 25.0,0.8,sin(angle) * 28.0 + 18.0)
		if absf(pos.x) < 5.0 and pos.z < 0:
			continue
		_make_rock(pos, Vector3(rng.randf_range(0.65,1.7),rng.randf_range(0.5,1.2),rng.randf_range(0.7,1.9)))
	for i: int in range(45):
		var pos := Vector3(rng.randf_range(-22,22),1.22,rng.randf_range(-2,41))
		if Vector2(pos.x / 29,(pos.z - 18) / 32).length() > 0.77 or absf(pos.x) < 4:
			continue
		if Vector2(pos.x + 12, pos.z - 7).length() < 5.5 or Vector2(pos.x - 13,pos.z - 16).length() < 5.5:
			continue
		pos.y=home_surface_height(pos.x,pos.z)
		Details.shrub(self,pos,rng)

func _make_tree(pos: Vector3, tree_scale: float) -> void:
	var kind:=rng.randi_range(0,3)
	if pos.z<80. and absf(pos.x)<110.:kind=2 if rng.randf()<.65 else 1
	preload("res://scripts/world/nature_library.gd").plant(self,kind,pos,tree_scale*.65,rng.randf()*TAU)

func _make_rock(pos: Vector3, dimensions: Vector3) -> void:
	if pos.y<1.5:
		var c:=Waves.coast(Vector2(pos.x,pos.z))
		shore_rocks.append(pos+Vector3(c.y,0,c.z)*maxf(dimensions.x,dimensions.z)*1.05)
	var node := Details.stone(self, pos, dimensions, rock, rng.randi())
	node.rotation.y = rng.randf() * TAU

func _make_lighthouse(pos: Vector3) -> void:
	lighthouse=preload("res://scripts/world/navigation_lighthouse.gd").new();lighthouse.world=self;lighthouse.position=pos;lighthouse.name="FarolDaAurora";add_child(lighthouse)

func _make_wildlife() -> void:
	var white := G.material(Color("eee6cf"))
	for i: int in range(7):
		var gull := Node3D.new()
		add_child(gull)
		var vertices := PackedVector3Array([Vector3(0,0,-0.25),Vector3(-0.9,0.1,0.18),Vector3(-0.4,0.03,0.05),Vector3(0,0,0.15),Vector3(0.9,0.1,0.18),Vector3(0.4,0.03,0.05)])
		var mat := white.duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		G.mesh_node(gull,G.polygon_mesh(vertices,PackedInt32Array([0,1,2,0,2,3,0,3,5,0,5,4])),mat,Vector3.ZERO)
		gulls.append(gull)

func _make_buoy(pos: Vector3) -> void:
	var buoy := Node3D.new()
	buoy.position = pos
	add_child(buoy)
	G.sphere(buoy,Vector3(0,0,0),Vector3(0.55,0.2,0.55),teal)
	G.cylinder(buoy,Vector3(0,0.55,0),0.18,1.1,cream,0.14)
	G.cylinder(buoy,Vector3(0,1.15,0),0.23,0.25,G.material(Color("c87147")),0.0)
	buoys.append(buoy)

func _make_sign() -> void:
	G.cylinder(self,Vector3(-3.5,2.1,-5),0.09,1.7,dark_wood)
	G.box(self,Vector3(-3.5,2.8,-5),Vector3(3,0.6,0.12),teal)
	G.label(self,"ENSEADA DA AURORA",Vector3(-3.5,2.82,-5.08),20)

func _process(delta: float) -> void:
	elapsed += delta
	preload("res://scripts/world/nature_library.gd").wind(Waves.time,Waves.wind,Waves.direction)
	for i: int in range(gulls.size()):
		var phase := elapsed * (0.14 + i * 0.006) + i * 1.8
		gulls[i].position = Vector3(cos(phase) * (20 + i * 4), 13 + i * 1.8 + sin(elapsed * 0.5 + i), -25 + sin(phase) * (18 + i * 4))
		gulls[i].rotation.y = -phase
		gulls[i].rotation.z = sin(elapsed * 2.0 + i) * 0.08
	for i: int in range(buoys.size()):
		buoys[i].position.y = Waves.height_at(buoys[i].global_position)
		buoys[i].rotation.z = sin(elapsed + i) * 0.05
