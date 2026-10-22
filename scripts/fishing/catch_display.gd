extends Node3D
## Original procedural trophy fish. The caller owns this node's world position.

var remaining: float = 0.0
var fish_root: Node3D
var _elapsed: float = 0.0
var held: bool=false

func _ready() -> void:
	visible = false

func show_catch(data: Dictionary) -> void:
	if is_instance_valid(fish_root):
		remove_child(fish_root)
		fish_root.queue_free()
	fish_root = Node3D.new()
	add_child(fish_root)
	var species: String = str(data.get("species_id", data.get("id", "sardine")))
	var body_color: Color = Color.from_string(str(data.get("color", "83c6cf")), Color(0.51, 0.78, 0.81))
	var size_factor: float = 1.0
	if species == "sardine":
		size_factor = 0.8
	elif species == "seabass":
		size_factor = 1.12
	fish_root.scale = Vector3.ONE * size_factor
	if species in ["mackerel","tuna","lanternfish"]:
		var imported:=preload("res://scripts/creatures/marine_visual.gd").new();imported.species=species;imported.face_forward=false;fish_root.add_child(imported)
		if species=="tuna":fish_root.scale=Vector3.ONE*1.1
	else:_build_fish(body_color, species)
	remaining = 4.0
	_elapsed = 0.0
	rotation.y = -0.45
	visible = true

func _process(delta: float) -> void:
	if held:
		_elapsed+=delta
		if fish_root!=null: fish_root.rotation.z=sin(_elapsed*7.)*.035
		return
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	_elapsed += delta
	rotation.y += delta * 0.48
	if is_instance_valid(fish_root):
		fish_root.position.y = sin(_elapsed * 3.0) * 0.045
		fish_root.rotation.z = sin(_elapsed * 2.5) * 0.045
	if remaining <= 0.0:
		visible = false

func _material(color: Color, shiny: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28 if shiny else 0.65
	material.metallic = 0.22 if shiny else 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_fish(body_color: Color, species: String) -> void:
	# A tapered six-ring body with a silver underside and dark dorsal ridge.
	var profile: Array[Vector3] = [
		Vector3(-0.43, 0.04, 0.035), Vector3(-0.28, 0.13, 0.085),
		Vector3(-0.04, 0.18, 0.12), Vector3(0.22, 0.155, 0.115),
		Vector3(0.39, 0.105, 0.077), Vector3(0.48, 0.035, 0.026),
	]
	var body: SurfaceTool = SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS: int = 20
	for ring: int in range(profile.size() - 1):
		for step: int in range(SEGMENTS):
			var angle_a: float = TAU * float(step) / float(SEGMENTS)
			var angle_b: float = TAU * float(step + 1) / float(SEGMENTS)
			var points: Array[Vector3] = [
				_profile_point(profile[ring], angle_a), _profile_point(profile[ring + 1], angle_a),
				_profile_point(profile[ring + 1], angle_b), _profile_point(profile[ring], angle_b),
			]
			for index: int in [0, 2, 1, 0, 3, 2]:
				var vertex: Vector3 = points[index]
				var dorsal: float = clampf((vertex.y + 0.04) * 4.0, 0.0, 1.0)
				var tint: Color = body_color.lightened(0.48).lerp(body_color.darkened(0.38), dorsal)
				body.set_color(tint)
				body.set_normal(Vector3(vertex.x * 0.65, vertex.y / 0.18, vertex.z / 0.12).normalized())
				body.add_vertex(vertex)
	var body_material: StandardMaterial3D = _material(Color.WHITE, true)
	body_material.vertex_color_use_as_albedo = true
	_add_mesh(body.commit(), body_material)
	var fin_color: Color = body_color.darkened(0.28)
	# Forked tail silhouette, dorsal fan and paired translucent-looking fins.
	_polygon([Vector3(-0.41, 0.0, 0.0), Vector3(-0.70, 0.23, 0.0), Vector3(-0.64, 0.015, 0.015)], fin_color)
	_polygon([Vector3(-0.41, 0.0, 0.0), Vector3(-0.64, -0.015, 0.015), Vector3(-0.70, -0.22, 0.0)], fin_color)
	_polygon([Vector3(-0.23, 0.14, 0.0), Vector3(-0.13, 0.32, 0.0), Vector3(0.13, 0.16, 0.0)], fin_color.lightened(0.08))
	_polygon([Vector3(-0.18, -0.13, 0.0), Vector3(-0.30, -0.26, 0.0), Vector3(0.02, -0.16, 0.0)], fin_color)
	for side: float in [-1.0, 1.0]:
		_polygon([Vector3(0.17, -0.02, 0.10 * side), Vector3(-0.12, -0.15, 0.24 * side), Vector3(0.02, -0.07, 0.10 * side)], fin_color.lightened(0.12))
		# Gold iris, black pupil, and tiny bright catchlight on both sides.
		_sphere(Vector3(0.335, 0.052, 0.086 * side), 0.039, Color(0.88, 0.78, 0.48), Vector3(1.0, 1.0, 0.40))
		_sphere(Vector3(0.338, 0.054, 0.099 * side), 0.023, Color(0.025, 0.05, 0.055), Vector3(1.0, 1.0, 0.36))
		_sphere(Vector3(0.343, 0.063, 0.105 * side), 0.007, Color(0.96, 1.0, 1.0), Vector3.ONE)
		_polygon([Vector3(0.245, 0.10, 0.09 * side), Vector3(0.225, -0.075, 0.096 * side), Vector3(0.238, -0.056, 0.106 * side)], body_color.darkened(0.55))
		# Small facet scales follow the flank instead of forming separate blocks.
		for column: int in range(5):
			for row: int in range(3):
				var sx: float = -0.24 + float(column) * 0.085
				var sy: float = -0.075 + float(row) * 0.065
				var shape_width: float = _flank_width(profile, sx, sy)
				var sz: float = side * (shape_width + 0.0015)
				var scale_color: Color = body_color.lightened(0.15 if row < 2 else 0.03)
				if species == "mackerel" and column % 2 == 0:
					scale_color = body_color.darkened(0.26)
				_polygon([Vector3(sx, sy, sz), Vector3(sx + 0.032, sy + 0.015, sz), Vector3(sx + 0.047, sy, sz)], scale_color)
	# Lips close the narrow front end and make the head readable in silhouette.
	_sphere(Vector3(0.477, -0.008, 0.0), 0.031, body_color.darkened(0.48), Vector3(0.50, 0.34, 1.0))

func _profile_point(profile: Vector3, angle: float) -> Vector3:
	return Vector3(profile.x, sin(angle) * profile.y, cos(angle) * profile.z)

func _flank_width(profile: Array[Vector3], x: float, y: float) -> float:
	for index: int in range(profile.size() - 1):
		var current: Vector3 = profile[index]
		var next: Vector3 = profile[index + 1]
		if x >= current.x and x <= next.x:
			var fraction: float = inverse_lerp(current.x, next.x, x)
			var radius_y: float = lerpf(current.y, next.y, fraction)
			var radius_z: float = lerpf(current.z, next.z, fraction)
			return radius_z * sqrt(maxf(0.0, 1.0 - pow(y / radius_y, 2.0)))
	return 0.08

func _polygon(points: Array[Vector3], color: Color) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in points:
		surface.add_vertex(point)
	surface.generate_normals()
	_add_mesh(surface.commit(), _material(color, true))

func _sphere(location: Vector3, radius: float, color: Color, proportions: Vector3) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var instance: MeshInstance3D = _add_mesh(sphere, _material(color, true))
	instance.position = location
	instance.scale = proportions

func _add_mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	fish_root.add_child(instance)
	return instance
