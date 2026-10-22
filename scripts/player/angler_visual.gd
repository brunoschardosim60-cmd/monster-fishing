class_name AnglerVisual
extends Node3D
## Articulated coastal explorer. Controller and rod-tip contract unchanged.
const Sculpt = preload("res://scripts/visuals/sculpt.gd")
const Materials = preload("res://scripts/visuals/materials.gd")

var seated: bool = false
var _phase: float = 0.0
var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _rod: Node3D
var _tip: Marker3D
var _knees: Array[Node3D] = []
var _elbows: Array[Node3D] = []

func _ready() -> void:
	_build_visual()

func update_animation(speed: float, fishing: bool, delta: float) -> void:
	if not is_instance_valid(_body):
		return
	_phase += delta * (5.0 + absf(speed) * 1.7)
	var stride: float = clampf(absf(speed) / 5.0, 0.0, 1.0)
	var left_swing: float = sin(_phase) * stride * 0.5
	var right_swing: float = -left_swing
	_left_leg.rotation.x = 1.28 if seated else left_swing
	_right_leg.rotation.x = 1.28 if seated else right_swing
	for i: int in _knees.size():
		_knees[i].rotation.x = -1.28 if seated else -maxf(0.,sin(_phase+i*PI)) * stride*.65
	for i: int in _elbows.size():
		_elbows[i].rotation.x = lerpf(_elbows[i].rotation.x,.65 if fishing else (.85 if seated else .15),delta*8.)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.85 if fishing else (0.0 if seated else right_swing * 0.65), delta * 8.0)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.45 if fishing else (0.6 if seated else left_swing * 0.65), delta * 8.0)
	_body.position.y = (-0.78 if seated else absf(sin(_phase)) * stride * 0.045)
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
	var coat := Materials.surface("fabric",Color("4f5b59"),8.,false)
	var coat_shadow := Materials.surface("fabric",Color("4c4538"),7.,false)
	var coat_light := Materials.surface("fabric",Color("6e6551"),7.,false)
	var trousers := Materials.surface("fabric",Color("354146"),7.,false)
	var boots := _material(Color("302d26"))
	var skin := _material(Color("c88c60"))
	var hair := _material(Color("342a23"))
	var thread := _material(Color("b3aa91"))
	var cap := Materials.surface("fabric",Color("263b43"),8.,false)
	# Narrow waist, chest and sloped shoulders underneath a canvas fishing vest.
	_ring_mesh(_body,[Vector3(.20,.77,.13),Vector3(.19,.89,.125),Vector3(.175,1.04,.12),Vector3(.215,1.23,.15),Vector3(.22,1.34,.13),Vector3(.14,1.43,.095)],coat)
	_ring_mesh(_body,[Vector3(.204,.86,.137),Vector3(.183,1.04,.135),Vector3(.224,1.25,.16),Vector3(.213,1.35,.135)],coat_shadow)
	_box(_body,Vector3(.012,.45,.012),Vector3(0,1.11,-.159),thread)
	for x: float in [-.12,.12]:
		for y: float in [.98,1.22]:
			_box(_body,Vector3(.13,.14,.042),Vector3(x,y,-.168),coat_light)
			_box(_body,Vector3(.135,.028,.048),Vector3(x,y+.065,-.171),coat_shadow)
			_box(_body,Vector3(.018,.025,.008),Vector3(x,y+.04,-.20),thread)
	_ring_mesh(_body,[Vector3(.065,1.41,.065),Vector3(.06,1.51,.06)],skin)
	Sculpt.ellipsoid(_body,Vector3(0,1.65,0),Vector3(.095,.13,.09),skin)
	Sculpt.ellipsoid(_body,Vector3(0,1.59,-.014),Vector3(.079,.075,.077),hair)
	Sculpt.ellipsoid(_body,Vector3(0,1.635,-.01),Vector3(.080,.077,.077),skin)
	Sculpt.ellipsoid(_body,Vector3(0,1.64,-.091),Vector3(.017,.026,.025),skin)
	for x: float in [-.038,.038]:
		Sculpt.ellipsoid(_body,Vector3(x,1.67,-.083),Vector3(.013,.006,.007),thread)
		Sculpt.ellipsoid(_body,Vector3(x,1.67,-.089),Vector3(.004,.005,.003),hair)
		Sculpt.ellipsoid(_body,Vector3(x*2.5,1.65,.005),Vector3(.014,.025,.016),skin)
		_box(_body,Vector3(.031,.007,.008),Vector3(x,1.683,-.081),hair)
	Sculpt.ellipsoid(_body,Vector3(0,1.602,-.087),Vector3(.026,.004,.004),hair)
	Sculpt.ellipsoid(_body,Vector3(0,1.70,.025),Vector3(.098,.085,.08),hair)
	# Six-panel cap and forward bill match the exploration reference silhouette.
	_ring_mesh(_body,[Vector3(.103,1.715,.10),Vector3(.105,1.76,.103),Vector3(.084,1.80,.086),Vector3(.035,1.818,.04)],cap)
	Sculpt.ellipsoid(_body,Vector3(0,1.718,-.125),Vector3(.108,.012,.13),cap)
	_box(_body,Vector3(.035,.03,.009),Vector3(0,1.755,-.103),coat_light)
	_left_leg = _limb(_body, Vector3(-0.105, 0.77, 0.0))
	_right_leg = _limb(_body, Vector3(0.105, 0.77, 0.0))
	for leg: Node3D in [_left_leg, _right_leg]:
		_ring_mesh(leg,[Vector3(.098,-.01,.10),Vector3(.095,-.08,.10),Vector3(.087,-.23,.09),Vector3(.079,-.35,.08)],trousers)
		_box(leg,Vector3(.04,.14,.12),Vector3(.085,-.17,.01),coat_shadow)
		var knee := _limb(leg,Vector3(0,-.34,0))
		_knees.append(knee)
		_ring_mesh(knee,[Vector3(.081,0,.082),Vector3(.085,-.1,.085),Vector3(.068,-.23,.068)],trousers)
		_ring_mesh(knee,[Vector3(.072,-.2,.075),Vector3(.077,-.34,.085)],boots)
		Sculpt.ellipsoid(knee,Vector3(0,-.34,-.039),Vector3(.086,.068,.14),boots)
		_box(knee,Vector3(.17,.03,.26),Vector3(0,-.395,-.039),boots)
		for y: float in [-.245,-.275,-.305]:
			_box(knee,Vector3(.065,.009,.009),Vector3(0,y,-.080),thread).rotation.z=.18
	_left_arm = _limb(_body, Vector3(-0.245, 1.34, 0.0))
	_right_arm = _limb(_body, Vector3(0.245, 1.34, 0.0))
	_left_arm.rotation.z = -0.12
	_right_arm.rotation.z = 0.12
	for arm: Node3D in [_left_arm, _right_arm]:
		Sculpt.ellipsoid(arm,Vector3(0,-.02,0),Vector3(.084,.095,.085),coat)
		_ring_mesh(arm,[Vector3(.087,0,.09),Vector3(.082,-.13,.085),Vector3(.067,-.25,.07)],coat)
		var elbow := _limb(arm,Vector3(0,-.24,0))
		_elbows.append(elbow)
		_ring_mesh(elbow,[Vector3(.070,0,.072),Vector3(.072,-.08,.074),Vector3(.058,-.23,.06)],coat)
		_ring_mesh(elbow,[Vector3(.062,-.20,.065),Vector3(.058,-.25,.06)],coat_light)
		Sculpt.ellipsoid(elbow,Vector3(0,-.295,0),Vector3(.043,.065,.03),skin)
		Sculpt.ellipsoid(elbow,Vector3(-.034,-.278,-.005),Vector3(.017,.035,.018),skin)
	# Canvas pack, separate pockets, webbing and shoulder harness.
	_box(_body,Vector3(.34,.46,.18),Vector3(0,1.15,.205),coat_shadow)
	_box(_body,Vector3(.31,.11,.20),Vector3(0,1.39,.21),coat_light)
	_box(_body,Vector3(.26,.23,.065),Vector3(0,1.09,.32),coat_light)
	for x: float in [-.13,.13]:
		_box(_body,Vector3(.035,.42,.025),Vector3(x,1.17,.35),boots)
		_box(_body,Vector3(.045,.034,.025),Vector3(x,1.08,.37),thread)
		_beam(_body,Vector3(x,1.41,.20),Vector3(x,1.44,-.08),.042,coat_shadow)
		_beam(_body,Vector3(x,1.44,-.08),Vector3(x,1.02,-.17),.035,coat_shadow)
	_box(_body,Vector3(.37,.055,.029),Vector3(0,1.19,-.20),coat_shadow)
	_box(_body,Vector3(.04,.04,.015),Vector3(0,1.19,-.22),thread)
	# Fishing rod lives in the right hand. Marker is the true global line origin.
	_rod = Node3D.new()
	_rod.position = Vector3(0.0, -0.30, -0.025)
	_elbows[1].add_child(_rod)
	var rod_material := _material(Color("394a4d"))
	var cork := _material(Color("c9a779"))
	_beam(_rod, Vector3(0.0, -0.1, 0.12), Vector3(0.0, 0.26, -0.20), 0.045, cork)
	_beam(_rod, Vector3(0.0, 0.26, -0.20), Vector3(0.0, 1.35, -1.25), 0.018, rod_material)
	_beam(_rod, Vector3(0.0, 1.35, -1.25), Vector3(0.0, 1.70, -1.72), 0.010, rod_material)
	_box(_rod, Vector3(0.11, 0.10, 0.08), Vector3(0.0, 0.12, -0.05), boots)
	_tip = Marker3D.new()
	_tip.position = Vector3(0.0, 1.70, -1.72)
	_rod.add_child(_tip)
	# Merge only fixed torso/head pieces, retaining every articulated joint.
	preload("res://scripts/world/static_batch.gd").build(_body,[_left_leg,_right_leg,_left_arm,_right_arm])

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
	var mesh := Sculpt.rounded_box(size,.035)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _beam(parent: Node3D, from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var beam := _box(parent, Vector3(width, width, from.distance_to(to)), (from + to) * 0.5, material)
	beam.quaternion = Quaternion(Vector3.FORWARD, (to - from).normalized())

func _ring_mesh(parent: Node3D, rings: Array, material: Material) -> void:
	# Each Vector3 stores x radius, y height and z radius of a smooth ring.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var sides: int = 32
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
			var vertices: Array=[a,b,c,a,c,d] if high.y>low.y else [a,c,b,a,d,c]
			for vertex: Vector3 in vertices:
				st.add_vertex(vertex)
	st.set_smooth_group(0xffffffff)
	for ring_index: int in [0, rings.size() - 1]:
		var ring: Vector3 = rings[ring_index]
		var top_cap: bool=(ring_index==0)==(rings[0].y>rings[rings.size()-1].y)
		for i in range(sides):
			var angle_a: float = TAU * float(i) / float(sides) + PI / 8.0
			var angle_b: float = TAU * float(i + 1) / float(sides) + PI / 8.0
			st.add_vertex(Vector3(0.0, ring.y, 0.0))
			var a:=Vector3(cos(angle_a)*ring.x,ring.y,sin(angle_a)*ring.z)
			var b:=Vector3(cos(angle_b)*ring.x,ring.y,sin(angle_b)*ring.z)
			st.add_vertex(a if top_cap else b)
			st.add_vertex(b if top_cap else a)
	st.index()
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	parent.add_child(instance)
