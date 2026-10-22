extends CharacterBody3D

const Visual = preload("res://scripts/player/angler_visual.gd")
var visual: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var controls_enabled: bool = true
var movement_locked: bool = false
var in_boat: bool = false
var first_person: bool = false
var yaw: float = 0.0
var pitch: float = -0.22
var walk_speed: float = 4.4
var animation_time: float = 0.0
signal fell_into_water

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	visual = Visual.new()
	add_child(visual)
	pivot = Node3D.new()
	pivot.position.y = 1.65
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 6.8
	arm.margin = 0.2
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 2200.0
	arm.add_child(camera)
	camera.current = true
	_update_camera(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0023, -1.15, 0.45)
	if event.is_action_pressed("camera_toggle"):
		first_person = not first_person

func _physics_process(delta: float) -> void:
	if controls_enabled:
		yaw += Input.get_axis("look_right", "look_left") * delta * 1.5
	if not in_boat:
		var axis := Vector2.ZERO
		if controls_enabled and not movement_locked:
			axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
		var speed_now := walk_speed * (1.65 if Input.is_action_pressed("sprint") else 1.0)
		velocity.x = move_toward(velocity.x, direction.x * speed_now, delta * 24.0)
		velocity.z = move_toward(velocity.z, direction.z * speed_now, delta * 24.0)
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		else:
			velocity.y = -0.1
		move_and_slide()
		if direction.length() > 0.1:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 12.0)
		if global_position.y < -0.8:
			fell_into_water.emit()
	visual.update_animation(Vector2(velocity.x, velocity.z).length() if not in_boat else 0.0, movement_locked, delta)
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	camera.position.y=move_toward(camera.position.y,0.,delta*2.)
	# Orbit distance can otherwise push a third-person camera under the water.
	if not first_person:
		pitch = minf(pitch, 0.15)
	pivot.rotation = Vector3(pitch, yaw, 0)
	pivot.position.y = lerpf(pivot.position.y, 1.65 if not in_boat else 2.0, minf(delta * 8.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, 0.0 if first_person else (10.5 if in_boat else 6.8), minf(delta * 10.0, 1.0))
	visual.visible = not first_person

func set_boating(value: bool) -> void:
	in_boat = value
	collision_layer = 0 if value else 4
	collision_mask = 0 if value else 1
	velocity = Vector3.ZERO
	visual.set("seated", value)

func rod_tip() -> Vector3:
	if first_person:
		return camera.global_position + camera.global_basis * Vector3(0.35, -0.25, -1.0)
	return visual.rod_tip()

func keep_camera_above_water() -> void:
	if not in_boat: return
	var sea=preload("res://scripts/world/wave_field.gd")
	var water: float=sea.height_at(camera.global_position)
	var deficit:=water+.3-camera.global_position.y
	if deficit>0.: camera.global_position.y+=deficit
