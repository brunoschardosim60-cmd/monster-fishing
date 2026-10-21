class_name AnglerVisual
extends Node3D
## Original faceted raincoat character; procedural rig is replaceable by a GLTF rig.

var seated: bool = false
var _phase: float = 0.0
var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _rod: Node3D
var _tip: Marker3D

func _ready() -> void:
	_build_visual()

func update_animation(speed: float, fishing: bool, delta: float) -> void:
	if not is_instance_valid(_body):
		return
	_phase += delta * (5.0 + absf(speed) * 1.7)
	var stride: float = clampf(absf(speed) / 5.0, 0.0, 1.0)
	var left_swing: float = sin(_phase) * stride * 0.5
	var right_swing: float = -left_swing
	_left_leg.rotation.x = 1.15 if seated else left_swing
	_right_leg.rotation.x = 1.15 if seated else right_swing
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.85 if fishing else (0.0 if seated else right_swing * 0.65), delta * 8.0)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.45 if fishing else (0.6 if seated else left_swing * 0.65), delta * 8.0)
	_body.position.y = (-0.35 if seated else absf(sin(_phase)) * stride * 0.045)
	_rod.rotation.x = lerpf(_rod.rotation.x, -0.22 if fishing else 0.22, delta * 6.0)
	_rod.visible = not seated or fishing

func rod_tip() -> Vector3:
	if is_instance_valid(_tip):
		return _tip.global_position
	return to_global(Vector3(0.35, 2.3, -1.1))

func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "ProceduralAnglerRig"
	add_child(_body)
	var coat := _material(Color("d5a53d"))
	var coat_shadow := _material(Color("ad7c2f"))
	var coat_light := _material(Color("e6be62"))
	var trousers := _material(Color("354e55"))
	var boots := _material(Color("26393e"))
	var skin := _material(Color("c88c60"))
	var face_light := _material(Color("dea777"))
	var hair := _material(Color("49382f"))
	var thread := _material(Color("f1dfaf"))
	# Custom eight-sided tapered raincoat: wide skirt and sloped shoulders.
	_ring_mesh(_body, [Vector3(0.29, 0.72, 0.19), Vector3(0.25, 1.17, 0.15), Vector3(0.22, 1.40, 0.13)], coat)
	_box(_body, Vector3(0.025, 0.60, 0.025), Vector3(0.0, 1.05, -0.175), coat_shadow)
	for y: float in [0.85, 1.01, 1.17]:
		_box(_body, Vector3(0.035, 0.035, 0.025), Vector3(0.035, y, -0.18), thread)
	for x: float in [-0.16, 0.16]:
		var pocket := _box(_body, Vector3(0.15, 0.16, 0.035), Vector3(x, 0.90, -0.19), coat_shadow)
		pocket.rotation.z = x * 0.3
		_box(_body, Vector3(0.16, 0.025, 0.04), Vector3(x, 0.99, -0.19), coat_light)
	_box(_body, Vector3(0.24, 0.09, 0.25), Vector3(0.0, 1.42, 0.0), coat_light)
	# Head: faceted mesh with a protruding nose, hair and visible eyes.
	_ring_mesh(_body, [Vector3(0.10, 1.44, 0.09), Vector3(0.16, 1.54, 0.13), Vector3(0.145, 1.69, 0.125)], skin)
	_box(_body, Vector3(0.21, 0.13, 0.035), Vector3(0.0, 1.59, -0.122), face_light)
	_box(_body, Vector3(0.055, 0.065, 0.065), Vector3(0.0, 1.565, -0.167), skin)
	for x: float in [-0.058, 0.058]:
		_box(_body, Vector3(0.027, 0.026, 0.015), Vector3(x, 1.62, -0.149), boots)
	_box(_body, Vector3(0.12, 0.027, 0.018), Vector3(0.0, 1.505, -0.14), hair)
	_box(_body, Vector3(0.29, 0.10, 0.10), Vector3(0.0, 1.66, 0.083), hair)
	# Broad sou'wester hat, with sculpted brim and darker hatband.
	_ring_mesh(_body, [Vector3(0.29, 1.68, 0.25), Vector3(0.29, 1.71, 0.25)], coat)
	_ring_mesh(_body, [Vector3(0.17, 1.71, 0.16), Vector3(0.14, 1.81, 0.14)], coat_light)
	_ring_mesh(_body, [Vector3(0.173, 1.72, 0.163), Vector3(0.164, 1.755, 0.158)], coat_shadow)
	_left_leg = _limb(_body, Vector3(-0.14, 0.77, 0.0))
	_right_leg = _limb(_body, Vector3(0.14, 0.77, 0.0))
	for leg: Node3D in [_left_leg, _right_leg]:
		_ring_mesh(leg, [Vector3(0.105, -0.03, 0.105), Vector3(0.085, -0.44, 0.085)], trousers)
		_ring_mesh(leg, [Vector3(0.11, -0.38, 0.11), Vector3(0.115, -0.69, 0.12)], boots)
		_box(leg, Vector3(0.23, 0.13, 0.36), Vector3(0.0, -0.70, -0.06), boots)
	_left_arm = _limb(_body, Vector3(-0.26, 1.32, 0.0))
	_right_arm = _limb(_body, Vector3(0.26, 1.32, 0.0))
	_left_arm.rotation.z = -0.12
	_right_arm.rotation.z = 0.12
	for arm: Node3D in [_left_arm, _right_arm]:
		_ring_mesh(arm, [Vector3(0.11, 0.02, 0.12), Vector3(0.078, -0.41, 0.085)], coat)
		_ring_mesh(arm, [Vector3(0.084, -0.37, 0.09), Vector3(0.082, -0.43, 0.087)], coat_shadow)
		_ring_mesh(arm, [Vector3(0.072, -0.43, 0.075), Vector3(0.067, -0.54, 0.072)], skin)
	# Worn canvas satchel and shoulder strap.
	_box(_body, Vector3(0.27, 0.30, 0.14), Vector3(-0.26, 0.93, 0.17), coat_shadow)
	var strap := _box(_body, Vector3(0.055, 0.66, 0.025), Vector3(-0.08, 1.10, 0.17), boots)
	strap.rotation.z = -0.40
	# Fishing rod lives in the right hand. Marker is the true global line origin.
	_rod = Node3D.new()
	_rod.position = Vector3(0.0, -0.48, -0.025)
	_right_arm.add_child(_rod)
	var rod_material := _material(Color("394a4d"))
	var cork := _material(Color("c9a779"))
	_beam(_rod, Vector3(0.0, -0.1, 0.12), Vector3(0.0, 0.26, -0.20), 0.045, cork)
	_beam(_rod, Vector3(0.0, 0.26, -0.20), Vector3(0.0, 1.35, -1.25), 0.018, rod_material)
	_beam(_rod, Vector3(0.0, 1.35, -1.25), Vector3(0.0, 1.70, -1.72), 0.010, rod_material)
	_box(_rod, Vector3(0.11, 0.10, 0.08), Vector3(0.0, 0.12, -0.05), boots)
	_tip = Marker3D.new()
	_tip.position = Vector3(0.0, 1.70, -1.72)
	_rod.add_child(_tip)

func _limb(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _beam(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var beam := _box(parent, Vector3(width, width, from.distance_to(to)), (from + to) * 0.5, material)
	beam.quaternion = Quaternion(Vector3.FORWARD, (to - from).normalized())

func _ring_mesh(parent: Node3D, rings: Array, material: Material) -> void:
	# Each Vector3 stores x radius, y height, z radius of an octagonal ring.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 8
	for ring_index in range(rings.size() - 1):
		var low: Vector3 = rings[ring_index]
		var high: Vector3 = rings[ring_index + 1]
		for i in range(sides):
			var angle_a: float = TAU * float(i) / float(sides) + PI / 8.0
			var angle_b: float = TAU * float(i + 1) / float(sides) + PI / 8.0
			var a := Vector3(cos(angle_a) * low.x, low.y, sin(angle_a) * low.z)
			var b := Vector3(cos(angle_b) * low.x, low.y, sin(angle_b) * low.z)
			var c := Vector3(cos(angle_b) * high.x, high.y, sin(angle_b) * high.z)
			var d := Vector3(cos(angle_a) * high.x, high.y, sin(angle_a) * high.z)
			for vertex: Vector3 in [a, b, c, a, c, d]:
				st.add_vertex(vertex)
	for ring_index: int in [0, rings.size() - 1]:
		var ring: Vector3 = rings[ring_index]
		for i in range(sides):
			var angle_a: float = TAU * float(i) / float(sides) + PI / 8.0
			var angle_b: float = TAU * float(i + 1) / float(sides) + PI / 8.0
			st.add_vertex(Vector3(0.0, ring.y, 0.0))
			st.add_vertex(Vector3(cos(angle_a) * ring.x, ring.y, sin(angle_a) * ring.z))
			st.add_vertex(Vector3(cos(angle_b) * ring.x, ring.y, sin(angle_b) * ring.z))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	parent.add_child(instance)
