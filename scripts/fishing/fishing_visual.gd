extends Node3D
var line_mesh: ImmediateMesh
var bobber: MeshInstance3D
var ripple: MeshInstance3D
var target: Vector3 = Vector3.ZERO
var elapsed: float = 0

func _ready() -> void:
	line_mesh = ImmediateMesh.new()
	var line := MeshInstance3D.new()
	line.mesh = line_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.92, 0.77)
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	bobber = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	bobber.mesh = sphere
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ed8057")
	red.emission_enabled = true
	red.emission = Color("ab4a27")
	bobber.material_override = red
	add_child(bobber)
	ripple = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.68
	ripple.mesh = torus
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.albedo_color = Color("a6dcd7")
	ripple.material_override = foam
	add_child(ripple)
	visible = false

func update_line(origin: Vector3, state: int, delta: float) -> void:
	elapsed += delta
	visible = state >= 1 and state <= 4
	if not visible:
		return
	var end := target + Vector3(sin(elapsed * 1.8) * 0.15, 0.16 + sin(elapsed * 2.0) * 0.06, 0)
	if state == 3:
		end.y += sin(elapsed * 24.0) * 0.18
	bobber.global_position = end
	ripple.global_position = Vector3(end.x, 0.12, end.z)
	ripple.scale = Vector3.ONE * (0.7 + fmod(elapsed, 1.5) * 0.6)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 17:
		var t := float(i) / 16.0
		var p := origin.lerp(end, t)
		p.y -= sin(t * PI) * (0.1 if state == 4 else 0.5)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()
