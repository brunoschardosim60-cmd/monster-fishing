extends Node3D
const Waves = preload("res://scripts/world/wave_field.gd")
var line_mesh: ImmediateMesh
var bobber: MeshInstance3D
var ripple: MeshInstance3D
var target: Vector3 = Vector3.ZERO
var elapsed: float = 0
var cast_start:=Vector3.ZERO
var cast_elapsed: float=0.

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
	sphere.radius = 0.085
	sphere.height = 0.30
	bobber.mesh = sphere
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ed8057")
	red.emission_enabled = true
	red.emission = Color("ab4a27")
	bobber.material_override = red
	add_child(bobber)
	ripple = MeshInstance3D.new()
	var plane:=PlaneMesh.new(); plane.size=Vector2(10,10)
	plane.subdivide_width=20; plane.subdivide_depth=20
	ripple.mesh = plane
	var foam := ShaderMaterial.new()
	foam.shader=preload("res://assets/shaders/ripple.gdshader")
	foam.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	ripple.material_override = foam
	add_child(ripple)
	visible = false

func update_line(origin: Vector3, state: int, delta: float) -> void:
	elapsed += delta
	visible = state >= 1 and state <= 4
	if not visible:
		return
	var end := target + Vector3(sin(elapsed * 1.8) * 0.15, 0.16 + sin(elapsed * 2.0) * 0.06, 0)
	end.y = Waves.height_at(end) + .13
	if state==1:
		cast_elapsed+=delta
		var t:=clampf(cast_elapsed/.85,0.,1.)
		end=cast_start.lerp(end,t)+Vector3.UP*sin(t*PI)*maxf(2.,cast_start.distance_to(target)*.2)
	if state == 3:
		end.y += sin(elapsed * 24.0) * 0.18
	bobber.global_position = end
	ripple.global_position = Vector3(end.x, 0, end.z)
	ripple.visible=state!=1
	Waves.bind(ripple.material_override)
	ripple.material_override.set_shader_parameter("age",fmod(elapsed,2.5))
	ripple.material_override.set_shader_parameter("strength",.4 if state!=3 else .9)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 17:
		var t := float(i) / 16.0
		var p := origin.lerp(end, t)
		p.y -= sin(t * PI) * (0.1 if state == 4 else 0.5)
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()
