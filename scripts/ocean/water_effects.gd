extends Node3D
## Bounded pool: local ripples and spray. No allocations on a splash.
const Waves=preload("res://scripts/world/wave_field.gd")
signal splashed(at: Vector3, strength: float)
var rings: Array[MeshInstance3D]=[]
var sprays: Array[CPUParticles3D]=[]
var ages: Array[float]=[]
var sizes: Array[float]=[]
var cursor: int=0
var total_splashes: int=0

static func drop_material() -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo=true
	mat.albedo_color=Color(.65,.82,.85,.5)
	var gradient:=Gradient.new()
	gradient.set_color(0,Color(1,1,1,.9)); gradient.set_color(1,Color(1,1,1,0))
	var texture:=GradientTexture2D.new(); texture.width=32; texture.height=64
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5); texture.fill_to=Vector2(.5,0.)
	texture.gradient=gradient; mat.albedo_texture=texture
	mat.distance_fade_mode=BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance=.35; mat.distance_fade_max_distance=1.1
	return mat

func _ready() -> void:
	var plane:=PlaneMesh.new()
	plane.size=Vector2(10,10); plane.subdivide_width=20; plane.subdivide_depth=20
	var drop:=QuadMesh.new(); drop.size=Vector2(.035,.09); drop.material=drop_material()
	for i: int in 12:
		var ring:=MeshInstance3D.new()
		ring.mesh=plane
		var mat:=ShaderMaterial.new(); mat.shader=preload("res://assets/shaders/ripple.gdshader")
		mat.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
		ring.material_override=mat; ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring); rings.append(ring); ages.append(10.); sizes.append(1.); ring.hide()
		var spray:=CPUParticles3D.new()
		spray.emitting=false; spray.one_shot=true; spray.explosiveness=.92
		spray.amount=40; spray.lifetime=1.2; spray.mesh=drop
		spray.direction=Vector3.UP; spray.spread=65.
		spray.gravity=Vector3(0,-9.8,0); spray.initial_velocity_min=1.5; spray.initial_velocity_max=4.
		spray.local_coords=false
		spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gradient:=Gradient.new(); gradient.set_color(0,Color(1,1,1,.7)); gradient.set_color(1,Color(1,1,1,0))
		spray.color_ramp=gradient
		add_child(spray); sprays.append(spray)

func splash(at: Vector3, strength: float=1., spray: bool=true) -> void:
	var cam:=get_viewport().get_camera_3d()
	if cam!=null and cam.global_position.distance_to(at)>95.: return
	var i:=cursor; cursor=(cursor+1)%rings.size(); total_splashes+=1
	ages[i]=0.; sizes[i]=clampf(strength,.25,2.5)
	rings[i].global_position=Vector3(at.x,0,at.z); rings[i].show()
	if spray:
		sprays[i].global_position=Vector3(at.x,Waves.height_at(at)+.12,at.z)
		sprays[i].initial_velocity_min=1.2+strength*.4
		sprays[i].initial_velocity_max=2.+strength*2.1
		sprays[i].restart(); sprays[i].emitting=true
		splashed.emit(at,strength)

func _process(delta: float) -> void:
	for i: int in rings.size():
		ages[i]+=delta
		if ages[i]>3.5: rings[i].hide(); continue
		var mat:=rings[i].material_override as ShaderMaterial
		Waves.bind(mat)
		mat.set_shader_parameter("age",ages[i]); mat.set_shader_parameter("strength",sizes[i])
