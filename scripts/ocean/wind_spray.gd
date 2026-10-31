extends Node3D
## Spray torn off wave crests by strong wind. Around the camera, crests that stand high above the mean
## sea (sampled from wave_field, the same field the shader and the hulls use) shed a puff of white spray
## that flies downwind and falls back. Nothing is spawned in light airs; a gale fills the air with it.
## The boat adds its own: when the bow slams into a sea at speed, spray bursts over the foredeck.
const Waves=preload("res://scripts/world/wave_field.gd")
const COUNT: int=72
var multimesh: MultiMesh
var _pos: PackedVector3Array=PackedVector3Array()
var _vel: PackedVector3Array=PackedVector3Array()
var _life: PackedFloat32Array=PackedFloat32Array()
var _size: PackedFloat32Array=PackedFloat32Array()
var _rng:=RandomNumberGenerator.new()
var _spawn_clock: float=0.
var _next: int=0
var _mat: ShaderMaterial

func _ready() -> void:
	_rng.seed=4242;add_to_group("wind_spray")
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;multimesh.mesh=quad;multimesh.instance_count=COUNT
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/spray_puff.gdshader")
	_mat=mat
	var node:=MultiMeshInstance3D.new();node.name="Borrifos";node.multimesh=multimesh;node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=400.;add_child(node)
	_pos.resize(COUNT);_vel.resize(COUNT);_life.resize(COUNT);_size.resize(COUNT)
	for i: int in COUNT:multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*.001),Vector3(0,-50,0)))

## Throws one puff from `at` with `velocity` (used by crests and by the boat's bow).
func burst(at: Vector3,velocity: Vector3,size: float) -> void:
	var i:=_next;_next=(_next+1)%COUNT
	_pos[i]=at;_vel[i]=velocity;_life[i]=1.;_size[i]=size

func active_count() -> int:
	var n:=0
	for i: int in COUNT:if _life[i]>0.:n+=1
	return n

func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames()%15==0 and _mat!=null:
		var game:=get_tree().get_first_node_in_group("game")
		var day: float=1.
		var overcast: float=0.
		if game!=null and game.get("world")!=null:
			day=float(game.world.ocean.daylight);overcast=clampf(float(game.world.ocean.weather.cloud),0.,1.)
		# Unshaded, so it follows the light by hand: dimmer at night and under a grey sky.
		_mat.set_shader_parameter("light",lerpf(.09,1.,clampf(day,0.,1.))*lerpf(1.,.62,overcast))
	var camera:=get_viewport().get_camera_3d()
	var wind: float=Waves.wind
	var dir:=Vector3(Waves.direction.x,0.,Waves.direction.y)
	if camera!=null and wind>.5:
		_spawn_clock+=delta*smoothstep(.5,1.,wind)*26.
		var centre:=camera.global_position;centre.y=0.
		while _spawn_clock>=1.:
			_spawn_clock-=1.
			# Look for a crest in a ring around the camera; only the tops shed spray.
			for attempt: int in 4:
				var p:=centre+Vector3(_rng.randf_range(-70.,70.),0.,_rng.randf_range(-70.,70.))
				if Waves.exposure(Vector2(p.x,p.z))<.4:continue
				var h: float=Waves.height_at(p)
				if h<.45+Waves.energy*.9:continue
				p.y=h+.15
				burst(p,dir*(4.+wind*9.)+Vector3(0,1.6+wind*2.4,0),.9+wind*1.6)
				break
	var gravity:=Vector3(0,-5.5,0)
	for i: int in COUNT:
		if _life[i]<=0.:continue
		_life[i]-=delta*.7
		_vel[i]+=gravity*delta;_vel[i]*=1.-delta*.6
		_pos[i]+=_vel[i]*delta
		var t:=clampf(_life[i],0.,1.)
		var s: float=_size[i]*(1.6-t*.6)
		if _life[i]<=0. or _pos[i].y<Waves.height_at(_pos[i])-.3:
			_life[i]=0.;multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*.001),Vector3(0,-50,0)));continue
		multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(s,s*.7,s)),_pos[i]))
		multimesh.set_instance_color(i,Color(.92,.95,.96,t*.85))
