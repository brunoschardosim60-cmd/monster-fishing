extends MeshInstance3D
## Samples live in world space and survive throttle release. Fixed budget, 12 s.
const Waves=preload("res://scripts/world/wave_field.gd")
const LIFETIME:=12.
var samples: Array[Dictionary]=[]
var clock: float=0.
var accumulator: float=0.
var stern_offset: float=3.9
var half_width: float=1.65
var trail_mesh:=ImmediateMesh.new()
var mat:=ShaderMaterial.new()

func _ready() -> void:
	top_level=true; global_transform=Transform3D.IDENTITY
	mesh=trail_mesh; mat.shader=preload("res://assets/shaders/wake.gdshader")
	mat.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	mat.set_shader_parameter("trail",true); mat.set_shader_parameter("strength",1.)
	material_override=mat; cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb=AABB(Vector3(-2400,-8,-2400),Vector3(4800,16,4800))

func clear_trail() -> void:
	samples.clear(); trail_mesh.clear_surfaces()

func advance(at: Vector3, basis: Basis, speed: float, delta: float) -> void:
	clock+=delta; accumulator+=delta
	if samples.size()>0 and at.distance_to(samples[-1].p)>20.: clear_trail()
	if absf(speed)>1. and accumulator>=.12:
		accumulator=0.
		samples.append({"p":at+basis.z*stern_offset,"side":basis.x,"born":clock,"strength":clampf(absf(speed)/8.,0.,1.)})
	while not samples.is_empty() and (clock-samples[0].born>LIFETIME or samples.size()>102): samples.pop_front()
	Waves.bind(mat); trail_mesh.clear_surfaces()
	if samples.size()<2: return
	for side: float in [-1.,1.]:
		trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for s: Dictionary in samples:
			var age: float=clock-s.born
			var width:=.55+age*.19
			var center: Vector3=s.p+s.side*side*(half_width+age*.37)
			for edge: int in 2:
				trail_mesh.surface_set_color(Color(1,1,1,pow(1.-age/LIFETIME,1.5)*s.strength))
				trail_mesh.surface_set_uv(Vector2(float(edge),s.born*.35))
				var p: Vector3=center+s.side*(float(edge)*2.-1.)*width
				p.y=0.; trail_mesh.surface_add_vertex(p)
		trail_mesh.surface_end()
