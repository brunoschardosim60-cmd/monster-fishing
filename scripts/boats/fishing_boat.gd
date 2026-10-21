class_name FishingBoat
extends CharacterBody3D
## Small coastal launch. Physics stays level; only the handcrafted hull bobs.

var occupied: bool = false
var controls_enabled: bool = true
var speed: float = 0.0
var max_speed: float = 11.0
var wake_strength: float = 0.0
var _clock: float = 0.0
var _hull: Node3D
var _propeller: Node3D
var _foam_left: MeshInstance3D
var _foam_right: MeshInstance3D
const DOCK_POSITION: Vector3 = Vector3(3.9, 0.0, -23.0)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.05, 1.0, 4.8)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)
	_build_visual()

func _physics_process(delta: float) -> void:
	_clock += delta
	var throttle: float = 0.0
	var steering: float = 0.0
	if occupied and controls_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steering = Input.get_axis("move_left", "move_right")
	if throttle > 0.0:
		speed = move_toward(speed, max_speed, 2.7 * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -3.2, (5.5 if speed > 0.2 else 1.8) * delta)
	else:
		speed = move_toward(speed, 0.0, 0.85 * delta)
	if absf(speed) > 0.12:
		rotation.y -= steering * signf(speed) * (0.3 + minf(absf(speed), 9.0) * 0.065) * delta
	velocity = -global_transform.basis.z * speed
	velocity.y = 0.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed = move_toward(speed, 0.0, 9.0 * delta)
	position.y = 0.0
	var flat_position := Vector2(position.x, position.z)
	if flat_position.length() > 178.0:
		var boundary := flat_position.normalized() * 177.8
		position.x = boundary.x
		position.z = boundary.y
		speed = minf(speed, 0.0)
	wake_strength = clampf(absf(speed) / max_speed, 0.0, 1.0)
	if is_instance_valid(_hull):
		_hull.position.y = sin(_clock * 1.7 + position.x * 0.07) * 0.055
		_hull.rotation.z = sin(_clock * 1.2) * 0.018 - steering * wake_strength * 0.055
		_hull.rotation.x = cos(_clock * 1.4) * 0.013 - wake_strength * 0.025
		_propeller.rotation.z += delta * speed * 8.0
		_foam_left.visible = wake_strength > 0.08
		_foam_right.visible = wake_strength > 0.08
		_foam_left.scale.z = 0.5 + wake_strength * 2.3
		_foam_right.scale.z = 0.5 + wake_strength * 2.3

func set_occupied(value: bool) -> void:
	occupied = value

func seat_position() -> Vector3:
	return to_global(Vector3(0.0, 0.95, 0.5))

func reset_to_dock() -> void:
	global_position = DOCK_POSITION
	rotation = Vector3.ZERO
	speed = 0.0
	velocity = Vector3.ZERO

func _build_visual() -> void:
	_hull = Node3D.new()
	_hull.name = "HandcraftedLaunch"
	add_child(_hull)
	var cream := _material(Color("ddd9bb"))
	var teal := _material(Color("245861"))
	var trim := _material(Color("d9a15b"))
	var wood := _material(Color("9c6b45"))
	var dark := _material(Color("233d42"))
	var metal := _material(Color("9ca9a3"), 0.65)
	var points := PackedVector2Array([
		Vector2(0.0, -2.85), Vector2(-0.72, -2.25), Vector2(-1.10, -1.1),
		Vector2(-1.16, 0.9), Vector2(-1.02, 2.1), Vector2(1.02, 2.1),
		Vector2(1.16, 0.9), Vector2(1.10, -1.1), Vector2(0.72, -2.25)])
	_ring_hull(points, 0.78, -0.30, 1.0, 0.63, cream)
	_ring_hull(points, 0.92, 0.72, 1.025, 1.0, teal)
	_ring_hull(points, 0.98, 0.91, 1.04, 1.025, trim)
	_polygon_deck(points, 0.45, 0.84, wood)
	for z_index in range(12):
		var z: float = -1.7 + float(z_index) * 0.31
		_box(_hull, Vector3(1.72, 0.025, 0.018), Vector3(0.0, 0.47, z), dark)
	for bench_z in [-1.35, 0.65, 1.58]:
		_box(_hull, Vector3(1.88, 0.12, 0.33), Vector3(0.0, 0.80, bench_z), trim)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(-0.70, 0.62, bench_z), teal)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(0.70, 0.62, bench_z), teal)
	# Forward console and windscreen frame, leaving a clear central seat.
	_box(_hull, Vector3(0.75, 0.58, 0.40), Vector3(0.0, 0.76, -0.50), teal)
	_box(_hull, Vector3(0.86, 0.08, 0.54), Vector3(0.0, 1.08, -0.50), wood)
	var windscreen := _material(Color(0.35, 0.66, 0.69, 0.42))
	windscreen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(_hull, Vector3(0.76, 0.33, 0.035), Vector3(0.0, 1.28, -0.72), windscreen)
	for x: float in [-0.42, 0.42]:
		_box(_hull, Vector3(0.045, 0.37, 0.045), Vector3(x, 1.27, -0.72), cream)
	_box(_hull, Vector3(0.90, 0.045, 0.045), Vector3(0.0, 1.46, -0.72), cream)
	# Wheel is a simple torus, orientated toward the driver.
	var wheel := MeshInstance3D.new()
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.13
	wheel_mesh.outer_radius = 0.17
	wheel_mesh.rings = 16
	wheel_mesh.ring_segments = 6
	wheel.mesh = wheel_mesh
	wheel.material_override = dark
	wheel.position = Vector3(0.0, 1.16, -0.22)
	wheel.rotation.x = PI * 0.5
	_hull.add_child(wheel)
	_box(_hull, Vector3(0.025, 0.30, 0.025), wheel.position, metal)
	_box(_hull, Vector3(0.30, 0.025, 0.025), wheel.position, metal)
	# Stern motor, rudder and animated propeller.
	_box(_hull, Vector3(0.55, 0.58, 0.51), Vector3(0.0, 0.84, 2.27), dark)
	_box(_hull, Vector3(0.56, 0.12, 0.52), Vector3(0.0, 1.16, 2.27), cream)
	_box(_hull, Vector3(0.12, 0.84, 0.22), Vector3(0.0, 0.20, 2.30), metal)
	_propeller = Node3D.new()
	_propeller.position = Vector3(0.0, -0.10, 2.49)
	_hull.add_child(_propeller)
	_box(_propeller, Vector3(0.60, 0.07, 0.04), Vector3.ZERO, dark)
	_box(_propeller, Vector3(0.07, 0.60, 0.04), Vector3.ZERO, dark)
	# Rope coil, fishing crate and painted bow identifier.
	var coil := MeshInstance3D.new()
	var rope := TorusMesh.new()
	rope.inner_radius = 0.16
	rope.outer_radius = 0.23
	rope.rings = 20
	rope.ring_segments = 6
	coil.mesh = rope
	coil.material_override = trim
	coil.position = Vector3(0.38, 0.87, -1.35)
	_hull.add_child(coil)
	_box(_hull, Vector3(0.50, 0.37, 0.44), Vector3(-0.61, 0.66, 1.15), teal)
	_box(_hull, Vector3(0.54, 0.07, 0.48), Vector3(-0.61, 0.88, 1.15), cream)
	for side: float in [-1.0, 1.0]:
		_box(_hull, Vector3(0.15, 0.30, 0.20), Vector3(side * 1.16, 0.52, 0.15), dark)
		_box(_hull, Vector3(0.15, 0.30, 0.20), Vector3(side * 1.15, 0.52, 1.1), dark)
	var lamp_material := _material(Color("ffd28a"))
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("efb968")
	lamp_material.emission_energy_multiplier = 1.2
	_box(_hull, Vector3(0.11, 0.13, 0.11), Vector3(0.0, 1.12, -2.3), lamp_material)
	var bow_light := OmniLight3D.new()
	bow_light.position = Vector3(0.0, 1.25, -2.3)
	bow_light.light_color = Color("ffd296")
	bow_light.light_energy = 0.6
	bow_light.omni_range = 3.0
	_hull.add_child(bow_light)
	var foam := _material(Color(0.70, 0.88, 0.86, 0.55))
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foam_left = _box(self, Vector3(0.18, 0.015, 1.8), Vector3(-1.12, 0.10, 2.4), foam)
	_foam_right = _box(self, Vector3(0.18, 0.015, 1.8), Vector3(1.12, 0.10, 2.4), foam)
	_foam_left.rotation.y = -0.18
	_foam_right.rotation.y = 0.18
	_foam_left.visible = false
	_foam_right.visible = false

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.76
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result

func _ring_hull(points: PackedVector2Array, upper_y: float, lower_y: float, upper_scale: float, lower_scale: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var j: int = (i + 1) % points.size()
		var a := Vector3(points[i].x * upper_scale, upper_y, points[i].y)
		var b := Vector3(points[j].x * upper_scale, upper_y, points[j].y)
		var c := Vector3(points[j].x * lower_scale, lower_y, points[j].y * 0.94)
		var d := Vector3(points[i].x * lower_scale, lower_y, points[i].y * 0.94)
		for vertex: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(vertex)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	_hull.add_child(instance)

func _polygon_deck(points: PackedVector2Array, height: float, deck_scale: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var j: int = (i + 1) % points.size()
		st.add_vertex(Vector3(0.0, height, 0.0))
		st.add_vertex(Vector3(points[i].x * deck_scale, height, points[i].y * deck_scale))
		st.add_vertex(Vector3(points[j].x * deck_scale, height, points[j].y * deck_scale))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	_hull.add_child(instance)
