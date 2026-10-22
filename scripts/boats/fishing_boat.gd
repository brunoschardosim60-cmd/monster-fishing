class_name FishingBoat
extends CharacterBody3D
const Sculpt = preload("res://scripts/visuals/sculpt.gd")
const Materials = preload("res://scripts/visuals/materials.gd")
const Waves = preload("res://scripts/world/wave_field.gd")
const G = preload("res://scripts/world/geometry.gd")
## Horizontal collision controller plus a damped, four-point waterline sampler.
@export var hydrodynamics: Resource=preload("res://data/boats/coastal_launch.tres")
var water_effects: Node3D
var imported_model: Node3D
var bucket: Marker3D
var integrity: float=1.
var trail: MeshInstance3D
var heave_velocity: float=0.
var impact_cooldown: float=0.

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
var _wake_material: ShaderMaterial
const DOCK_POSITION: Vector3 = Vector3(3.9, 0.0, -23.0)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.65, 1.0, 8.1) if ResourceLoader.exists("res://assets/boats/fishing_boat.glb") else Vector3(2.05, 1.0, 4.8)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)
	_build_visual()
	_build_bucket()
	trail=preload("res://scripts/ocean/wake_trail.gd").new()
	add_child(trail)

func _physics_process(delta: float) -> void:
	_clock += delta
	var throttle: float = 0.0
	var steering: float = 0.0
	if occupied and controls_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steering = Input.get_axis("move_left", "move_right")
	if throttle > 0.0:
		var exposure:=Waves.exposure(Vector2(global_position.x,global_position.z))
		var limit: float=max_speed*(.55+.45*integrity)*(1.-hydrodynamics.storm_drag*maxf(0.,Waves.wind-.45)*exposure)
		speed = move_toward(speed, limit, 2.7 * delta)
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
		if absf(speed)>2.: integrity=maxf(.15,integrity-absf(speed)*delta*.003)
		speed = move_toward(speed, 0.0, 9.0 * delta)
	position.y = 0.0
	var wrapped:=preload("res://scripts/world/archipelago_layout.gd").wrapped(global_position)
	if wrapped.distance_to(global_position)>100.:
		global_position=wrapped;trail.clear_trail()
	wake_strength = clampf(absf(speed) / max_speed, 0.0, 1.0)
	trail.advance(global_position,global_basis,speed,delta)
	impact_cooldown=maxf(0.,impact_cooldown-delta)
	if is_instance_valid(_hull):
		var half_beam: float=hydrodynamics.beam*.5
		var half_length: float=hydrodynamics.waterline_length*.5
		var right:=Waves.height_at(global_position+global_basis.x*half_beam)
		var left:=Waves.height_at(global_position-global_basis.x*half_beam)
		var front:=Waves.height_at(global_position-global_basis.z*half_length)
		var back:=Waves.height_at(global_position+global_basis.z*half_length)
		var target: float=(right+left+front+back)*.125+Waves.height_at(global_position)*.5-hydrodynamics.draft_offset
		var omega:=sqrt(float(hydrodynamics.heave_stiffness)/float(hydrodynamics.mass_kg))
		heave_velocity+=((target-_hull.position.y)*omega*omega-2.*hydrodynamics.damping_ratio*omega*heave_velocity)*delta
		_hull.position.y+=heave_velocity*delta
		_hull.position.y=clampf(_hull.position.y,target-.2,target+.2)
		var blend: float=1.-exp(-delta*hydrodynamics.angular_response)
		var roll: float=atan((right-left)/hydrodynamics.beam)-steering*wake_strength*.065
		var pitch: float=atan((front-back)/hydrodynamics.waterline_length)+wake_strength*.025
		_hull.rotation.z=lerpf(_hull.rotation.z,clampf(roll,-hydrodynamics.maximum_tilt,hydrodynamics.maximum_tilt),blend)
		_hull.rotation.x=lerpf(_hull.rotation.x,clampf(pitch,-hydrodynamics.maximum_tilt,hydrodynamics.maximum_tilt),blend)
		if water_effects!=null and impact_cooldown<=0. and wake_strength>.18 and front-_hull.position.y>.17:
			water_effects.splash(global_position-global_basis.z*2.1,.4+wake_strength*Waves.energy,true)
			impact_cooldown=.65
		_propeller.rotation.z += delta * speed * 8.0
		_foam_left.visible = wake_strength > 0.08
		_foam_right.visible = wake_strength > 0.08
		_foam_left.scale.z = 0.5 + wake_strength * 2.3
		_foam_right.scale.z = 0.5 + wake_strength * 2.3
		Waves.bind(_wake_material)
		_wake_material.set_shader_parameter("strength", wake_strength)

func set_occupied(value: bool) -> void:
	occupied = value

func seat_position() -> Vector3:
	if imported_model!=null: return imported_model.get_node("Helm").global_position
	return _hull.to_global(Vector3(0.0, 0.95, 0.5)) if is_instance_valid(_hull) else to_global(Vector3(0.0,0.95,0.5))

func reset_to_dock() -> void:
	global_position = DOCK_POSITION
	rotation = Vector3.ZERO
	speed = 0.0
	velocity = Vector3.ZERO
	heave_velocity=0.; _hull.position.y=Waves.height_at(global_position)
	if trail!=null: trail.clear_trail()

func _build_visual() -> void:
	if ResourceLoader.exists("res://assets/boats/fishing_boat.glb"):
		_build_external_visual(); return
	_hull = Node3D.new()
	_hull.name = "HandcraftedLaunch"
	add_child(_hull)
	var cream := Materials.surface("paint",Color("d4d9d1"),1.7,false)
	var teal := Materials.surface("paint",Color("21434c"),1.6,false)
	cream.cull_mode = BaseMaterial3D.CULL_DISABLED
	teal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim := _material(Color("d9a15b"))
	var wood := Materials.surface("teak",Color.WHITE,2.0,false)
	var dark := _material(Color("233d42"))
	var metal := _material(Color("9ca9a3"), 0.65)
	var points := PackedVector2Array([
		Vector2(0.0, -2.85), Vector2(-0.72, -2.25), Vector2(-1.10, -1.1),
		Vector2(-1.16, 0.9), Vector2(-1.02, 2.1), Vector2(1.02, 2.1),
		Vector2(1.16, 0.9), Vector2(1.10, -1.1), Vector2(0.72, -2.25)])
	points = _smooth_outline(points)
	_ring_hull(points, 0.78, 0.12, 1.0, 0.83, cream)
	_ring_hull(points, 0.12, -0.33, .83, .40, teal)
	_ring_hull(points, 0.92, 0.72, 1.025, 1.0, teal)
	_ring_hull(points, 0.98, 0.91, 1.04, 1.025, trim)
	_ring_hull(points, 0.90, 0.46, .92, .80, cream)
	_polygon_deck(points, 0.45, 0.84, wood)
	for z_index in range(12):
		var z: float = -1.7 + float(z_index) * 0.31
		_box(_hull, Vector3(1.72, 0.025, 0.018), Vector3(0.0, 0.47, z), dark)
	for bench_z in [-1.35, 0.65, 1.58]:
		_box(_hull, Vector3(1.88, 0.12, 0.33), Vector3(0.0, 0.80, bench_z), trim)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(-0.70, 0.62, bench_z), teal)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(0.70, 0.62, bench_z), teal)
	var canvas := Materials.surface("fabric",Color("b6c5be"),7.,false)
	_box(_hull,Vector3(.72,.11,.38),Vector3(0,.91,.65),canvas)
	_box(_hull,Vector3(.70,.32,.09),Vector3(0,1.12,.88),canvas)
	# Open bow rails, cleats and ribs follow the hull rather than a rectangular frame.
	for side: float in [-1.,1.]:
		var rail := [Vector3(side*.98,1.06,-.9),Vector3(side*.73,1.16,-1.8),Vector3(side*.27,1.19,-2.5)]
		for i: int in range(rail.size()-1):
			G.beam(_hull,rail[i],rail[i+1],.022,metal)
		for p: Vector3 in rail:
			G.beam(_hull,p-Vector3(0,.23,0),p,.018,metal)
		for z: float in [-.6,.45,1.55]:
			G.beam(_hull,Vector3(side*.84,.48,z),Vector3(side*1.02,.88,z),.035,cream)
		for z: float in [-1.3,1.8]:
			_box(_hull,Vector3(.06,.05,.21),Vector3(side*1.03,1.015,z),metal)
			G.cylinder(_hull,Vector3(side*1.03,.99,z),.025,.08,metal,.025,12)
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
	for x: float in [-.23,.23]:
		var dial:=G.cylinder(_hull,Vector3(x,1.075,-.275),.063,.02,metal,.063,24)
		dial.rotation.x=PI*.5
		var face:=G.cylinder(_hull,Vector3(x,1.075,-.26),.049,.022,dark,.049,24)
		face.rotation.x=PI*.5
		_box(_hull,Vector3(.005,.036,.005),Vector3(x+.01,1.08,-.24),cream).rotation.z=-.4
	G.beam(_hull,Vector3(.40,.94,-.35),Vector3(.40,1.13,-.22),.012,metal)
	Sculpt.ellipsoid(_hull,Vector3(.40,1.13,-.22),Vector3(.03,.04,.03),dark)
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
	for i: int in range(1,4):
		var loop:=coil.duplicate() as MeshInstance3D
		loop.scale=Vector3.ONE*(1.-float(i)*.18)
		loop.position.y+=float(i)*.012
		_hull.add_child(loop)
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
	_wake_material=ShaderMaterial.new()
	_wake_material.shader=preload("res://assets/shaders/wake.gdshader")
	_wake_material.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	_foam_left = _make_wake(Vector3(-1.12,0,2.4))
	_foam_right = _make_wake(Vector3(1.12,0,2.4))
	_foam_left.rotation.y = -0.18
	_foam_right.rotation.y = 0.18
	_foam_left.visible = false
	_foam_right.visible = false
	# Fixed fittings share draws in hull space; the whole assembly still rocks.
	preload("res://scripts/world/static_batch.gd").build(_hull,[_propeller])

func _build_external_visual() -> void:
	hydrodynamics=preload("res://data/boats/tripo_fishing_boat.tres").duplicate()
	_hull=Node3D.new(); _hull.name="WaveFollowingHull"; add_child(_hull)
	imported_model=preload("res://scenes/models/fishing_boat_model.tscn").instantiate(); _hull.add_child(imported_model)
	_propeller=Node3D.new(); _hull.add_child(_propeller)
	var metal:=Materials.surface("paint",Color("253e43"),3.,false)
	G.cylinder(_hull,Vector3(0,1.55,.85),.06,.85,metal)
	var wheel:=TorusMesh.new(); wheel.inner_radius=.16; wheel.outer_radius=.2
	var wheel_node:=G.mesh_node(_hull,wheel,metal,Vector3(0,1.96,.85));wheel_node.rotation.x=PI*.3
	_wake_material=ShaderMaterial.new();_wake_material.shader=preload("res://assets/shaders/wake.gdshader")
	_wake_material.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	_foam_left=_make_wake(Vector3(-1.8,0,3.9));_foam_right=_make_wake(Vector3(1.8,0,3.9))
	_foam_left.rotation.y=-.18;_foam_right.rotation.y=.18

func _make_wake(at: Vector3) -> MeshInstance3D:
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(.85,2.4)
	mesh.subdivide_width=4
	mesh.subdivide_depth=12
	var instance:=G.mesh_node(self,mesh,_wake_material,at)
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _build_bucket() -> void:
	var at:=Vector3(1.,1.12,2.55) if imported_model!=null else Vector3(-.65,.48,1.4)
	var metal:=Materials.surface("paint",Color("9faea3"),2.,false)
	metal.metallic=.55;metal.roughness=.32;metal.cull_mode=BaseMaterial3D.CULL_DISABLED
	var shell:=CylinderMesh.new();shell.top_radius=.26;shell.bottom_radius=.21;shell.height=.43;shell.radial_segments=24;shell.cap_top=false
	G.mesh_node(_hull,shell,metal,at+Vector3.UP*.215)
	G.cylinder(_hull,at+Vector3.UP*.05,.2,.02,G.material(Color("213f43")),.2,24)
	var rim:=TorusMesh.new();rim.inner_radius=.245;rim.outer_radius=.27;rim.rings=24;rim.ring_segments=8
	G.mesh_node(_hull,rim,metal,at+Vector3.UP*.43)
	for side: float in [-1.,1.]:G.beam(_hull,at+Vector3(side*.255,.35,0),at+Vector3(side*.2,.7,0),.012,metal)
	G.beam(_hull,at+Vector3(-.2,.7,0),at+Vector3(.2,.7,0),.014,metal)
	bucket=Marker3D.new();bucket.position=at+Vector3.UP*.24;_hull.add_child(bucket)

func _smooth_outline(control: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var n:=control.size()
	for i: int in n:
		var a:=control[(i+n-1)%n]
		var b:=control[i]
		var c:=control[(i+1)%n]
		var d:=control[(i+2)%n]
		for j: int in range(5):
			var t:=float(j)/5.
			result.append(.5*((2.*b)+(-a+c)*t+(2.*a-5.*b+4.*c-d)*t*t+(-a+3.*b-3.*c+d)*t*t*t))
	return result

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.76
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := Sculpt.rounded_box(size,.07)
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result

func _ring_hull(points: PackedVector2Array, upper_y: float, lower_y: float, upper_scale: float, lower_scale: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in range(points.size()):
		var j: int = (i + 1) % points.size()
		var a := Vector3(points[i].x * upper_scale, upper_y, points[i].y)
		var b := Vector3(points[j].x * upper_scale, upper_y, points[j].y)
		var c := Vector3(points[j].x * lower_scale, lower_y, points[j].y * 0.94)
		var d := Vector3(points[i].x * lower_scale, lower_y, points[i].y * 0.94)
		for vertex: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(vertex)
	st.index()
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
