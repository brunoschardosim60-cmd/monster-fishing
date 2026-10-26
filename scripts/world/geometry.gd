extends RefCounted
## Original, replaceable low-poly modelling helpers. No external assets.

static func material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

static func mesh_node(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = scale_value
	parent.add_child(node)
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := mesh_node(parent, mesh, mat, pos)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top_radius: float = -1.0, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh_node(parent, mesh, mat, pos)

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, segments: int = 24) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = 12
	return mesh_node(parent, mesh, mat, pos, size)

## Ellipsoid sized by its full diameters along x, y and z (G.sphere takes radii).
static func ellipsoid(parent: Node3D, pos: Vector3, diameter: Vector3, mat: Material, segments: int = 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	return mesh_node(parent, mesh, mat, pos, diameter)

static func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var node := cylinder(parent, (a + b) * 0.5, thickness, a.distance_to(b), mat, thickness, 7)
	var direction := (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		node.quaternion = Quaternion(Vector3.UP, direction)
	return node

static func polygon_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in indices:
		if not colors.is_empty():
			st.set_color(colors[index])
		st.add_vertex(vertices[index])
	st.generate_normals()
	return st.commit()

static func label(parent: Node3D, text: String, pos: Vector3, size: int = 32) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.visibility_range_end=18.
	node.visibility_range_end_margin=3.
	node.rotation.y = PI
	node.position = pos
	node.font_size = size
	node.pixel_size = 0.012
	node.modulate = Color("fff0cf")
	node.outline_modulate = Color("193f3d")
	node.outline_size = 5
	parent.add_child(node)
	return node
