extends Node3D
## Phase 1: one seamless playable coast and a navigable ocean.
const G = preload("res://scripts/world/geometry.gd")
const OCEAN = preload("res://assets/shaders/ocean.gdshader")

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
	wood = G.material(Color("a27a4c"))
	dark_wood = G.material(Color("443e31"))
	cream = G.material(Color("e9d3a1"))
	teal = G.material(Color("3b6663"))
	leaf = G.material(Color("345e49"))
	leaf_light = G.material(Color("527959"))
	rock = G.material(Color("717a74"))
	_make_lighting()
	_make_ocean()
	_make_island(Vector3(0, 0, 18), Vector2(29, 32), true)
	_make_island(Vector3(-95, 0, -95), Vector2(20, 24), false)
	_make_island(Vector3(115, 0, -150), Vector2(29, 34), false)
	_make_island(Vector3(35, 0, -265), Vector2(32, 30), false)
	_make_dock()
	_make_cabin(Vector3(-12, 1.25, 7), -0.15, true)
	_make_cabin(Vector3(13, 1.25, 16), 0.18, false)
	_make_market()
	_make_foliage()
	_make_lighthouse(Vector3(-97, 1.25, -94))
	_make_wildlife()
	_make_sign()
	for p: Vector3 in [Vector3(-17, 0, -36), Vector3(24, 0, -60), Vector3(-40, 0, -98), Vector3(59, 0, -114)]:
		_make_buoy(p)

func safe_spawn() -> Vector3:
	return Vector3(0.0, 1.55, -17.0)

func is_land(pos: Vector3) -> bool:
	var radius := Vector2(pos.x / 29.0, (pos.z - 18.0) / 32.0).length()
	return radius < 0.93 or (absf(pos.x) < 1.8 and pos.z > -26.5 and pos.z < -7.0)

func _make_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("487e95")
	sky_mat.sky_horizon_color = Color("d8caad")
	sky_mat.ground_bottom_color = Color("45564d")
	sky_mat.ground_horizon_color = Color("d8caad")
	sky_mat.sky_curve = 0.2
	sky_mat.sun_angle_max = 2.5
	sky_mat.sun_curve = 0.15
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9c5ce")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("a5c1bb")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.08
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-23, -28, 0)
	sun.light_color = Color("ffedcf")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)

func _make_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500, 1500)
	plane.subdivide_width = 180
	plane.subdivide_depth = 180
	var mat := ShaderMaterial.new()
	mat.shader = OCEAN
	var water := G.mesh_node(self, plane, mat, Vector3.ZERO)
	water.name = "Ocean"
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_island(center: Vector3, size: Vector2, playable: bool) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	const RINGS: int = 12
	const SEGMENTS: int = 72
	for ring: int in range(RINGS + 1):
		var radius := float(ring) / float(RINGS)
		for segment: int in range(SEGMENTS):
			var angle := float(segment) / float(SEGMENTS) * TAU
			var edge := 1.0 + sin(angle * 5.0) * 0.025 + cos(angle * 9.0) * 0.016
			var x := cos(angle) * radius * size.x * edge
			var z := sin(angle) * radius * size.y * edge
			var height := 1.25
			if radius > 0.84:
				height = lerpf(1.25, -0.8, (radius - 0.84) / 0.16)
			if not playable and radius < 0.75:
				height += (1.0 - radius / 0.75) * 4.0
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
	var mat := G.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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
		for i: int in range(12):
			var angle := rng.randf() * TAU
			var r := rng.randf_range(0.1, 0.56)
			_make_tree(center + Vector3(cos(angle) * r * size.x, 1.25 + (1.0 - r / 0.75) * 4.0, sin(angle) * r * size.y), rng.randf_range(0.7, 1.3))

func _make_dock() -> void:
	G.box(self, Vector3(0, 1.2, -17), Vector3(3.6, 0.3, 18), dark_wood, true)
	for i: int in range(45):
		var plank := G.box(self, Vector3(0, 1.365, -8.2 - i * 0.4), Vector3(3.6, 0.055, 0.37), wood if i % 3 else cream)
		plank.material_override = wood if i % 3 else G.material(Color("ad885b"))
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
	var roof_mat := G.material(Color("824b3d") if main else Color("5a615d"))
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.mesh_node(house, G.polygon_mesh(roof_vertices, PackedInt32Array([0,2,1,3,4,5,0,3,5,0,5,2,2,5,4,2,4,1])), roof_mat, Vector3.ZERO)
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
	var canvas := G.material(Color("ca9866"))
	G.box(stall, Vector3(0, 3.2, 0), Vector3(4.6, 0.12, 2.5), canvas).rotation.x = 0.12
	G.box(stall, Vector3(0, 2.94, -1.22), Vector3(4.6, 0.4, 0.07), teal)
	var label := G.label(stall, "MERCADO  ·  PEIXE FRESCO", Vector3(0, 2.95, -1.28), 24)
	label.rotation.y = PI
	# Labels face toward the approach from the pier.
	label.rotation.y = 0.0
	G.box(stall, Vector3(-0.8, 1.22, 0), Vector3(1.4, 0.2, 0.9), teal)
	for i: int in range(4):
		var fish := G.sphere(stall, Vector3(-1.25 + i * 0.3, 1.4, -0.1), Vector3(0.12, 0.1, 0.3), G.material(Color("8caaa4")))
		fish.rotation.y = 0.25
	# Vendor, intentionally a replaceable stylised procedural character.
	G.cylinder(stall, Vector3(0.7, 1.32, 1.0), 0.3, 0.95, teal, 0.4)
	G.sphere(stall, Vector3(0.7, 2.08, 1.0), Vector3(0.23, 0.29, 0.23), G.material(Color("bb8e67")))
	G.cylinder(stall, Vector3(0.7, 2.32, 1.0), 0.38, 0.07, cream)
	G.cylinder(stall, Vector3(0.7, 2.43, 1.0), 0.23, 0.2, cream, 0.18)
	for x: float in [0.32, 1.08]:
		G.beam(stall, Vector3(x, 1.65, 0.98), Vector3(x, 1.15, 0.5), 0.1, teal)
	for x: float in [0.53, 0.87]:
		G.cylinder(stall, Vector3(x, 0.53, 1), 0.13, 0.9, dark_wood)
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
		_make_tree(Vector3(x,1.25,z), rng.randf_range(0.75,1.35))
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
		G.sphere(self,pos + Vector3(0,0.25,0),Vector3(0.6,0.4,0.55),leaf_light,7)

func _make_tree(pos: Vector3, tree_scale: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * tree_scale
	tree.rotation.y = rng.randf() * TAU
	add_child(tree)
	G.cylinder(tree,Vector3(0,1.7,0),0.22,3.4,dark_wood,0.12,7)
	G.beam(tree,Vector3(0,2.1,0),Vector3(-0.8,3.6,0.1),0.1,dark_wood)
	G.beam(tree,Vector3(0,2.6,0),Vector3(0.8,4.0,0),0.1,dark_wood)
	G.sphere(tree,Vector3(-0.6,3.6,0),Vector3(1.5,1.45,1.4),leaf,8)
	G.sphere(tree,Vector3(0.7,4.1,0.3),Vector3(1.55,1.6,1.45),leaf_light,8)
	G.sphere(tree,Vector3(0,5.0,0),Vector3(1.15,1.25,1.1),leaf,8)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 3.4
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.7
	body.add_child(collider)
	tree.add_child(body)

func _make_rock(pos: Vector3, dimensions: Vector3) -> void:
	var node := G.sphere(self,pos,dimensions,rock,7)
	node.rotation = Vector3(rng.randf_range(-0.3,0.3),rng.randf() * TAU,rng.randf_range(-0.3,0.3))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = node.mesh.create_convex_shape()
	body.add_child(collider)
	node.add_child(body)

func _make_lighthouse(pos: Vector3) -> void:
	G.cylinder(self,pos + Vector3(0,4,0),1.8,8,cream,1.25,12)
	G.cylinder(self,pos + Vector3(0,5.2,0),1.5,1.3,teal,1.4,12)
	G.cylinder(self,pos + Vector3(0,8.25,0),2.0,0.3,dark_wood,2,12)
	G.cylinder(self,pos + Vector3(0,9.1,0),1.1,1.5,cream,1.1,10)
	G.cylinder(self,pos + Vector3(0,10.2,0),1.6,0.8,teal,0.03,12)
	var lamp := G.material(Color("ffdca0"))
	lamp.emission_enabled = true
	lamp.emission = Color("ffdca0")
	G.sphere(self,pos + Vector3(0,9.1,-1.1),Vector3(0.45,0.55,0.15),lamp)

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
	for i: int in range(gulls.size()):
		var phase := elapsed * (0.14 + i * 0.006) + i * 1.8
		gulls[i].position = Vector3(cos(phase) * (20 + i * 4), 13 + i * 1.8 + sin(elapsed * 0.5 + i), -25 + sin(phase) * (18 + i * 4))
		gulls[i].rotation.y = -phase
		gulls[i].rotation.z = sin(elapsed * 2.0 + i) * 0.08
	for i: int in range(buoys.size()):
		buoys[i].position.y = sin(elapsed * 0.8 + i) * 0.09
		buoys[i].rotation.z = sin(elapsed + i) * 0.05
