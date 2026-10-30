extends Node3D
const Waves = preload("res://scripts/world/wave_field.gd")
var line_mesh: ImmediateMesh
var bobber: MeshInstance3D
var ripple: MeshInstance3D
var target: Vector3 = Vector3.ZERO
var elapsed: float = 0
var cast_start:=Vector3.ZERO
var cast_elapsed: float=0.
## The fish on the line (hooked_fish.gd) and the line's tension (0 slack … 1 about to break), set by main.
var hooked: Node3D
var tension: float=0.
## Cast timing: the float stays at the rod tip while the rod comes forward, then flies for the rest.
const RELEASE_AT: float=.22
var cast_time: float=.85
## A nibble: the float bobs under for a moment and a small ring spreads.
var _nibble: float=0.
func nibble(strength: float) -> void:
	_nibble=maxf(_nibble,strength)
var _landed: bool=false
var _bite_clock: float=0.
var _bite_dir:=Vector3.FORWARD
func _splash(at: Vector3,strength: float) -> void:
	var game:=get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	if game!=null and game.get("world")!=null and game.world.ocean.effects!=null:game.world.ocean.effects.splash(at,strength,false)

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
	# The float: a classic two-colour bulb (red top, white belly) on a thin stem with a bright tip,
	# riding with half its bulb under water.
	bobber = MeshInstance3D.new()
	var bulb:=SphereMesh.new();bulb.radius=.07;bulb.height=.17;bulb.radial_segments=14;bulb.rings=8
	bobber.mesh=bulb
	var red := StandardMaterial3D.new();red.albedo_color = Color("e2432f");red.roughness=.35
	bobber.material_override = red
	add_child(bobber)
	var white:=StandardMaterial3D.new();white.albedo_color=Color("f4f1e8");white.roughness=.4
	var belly:=MeshInstance3D.new();var b2:=SphereMesh.new();b2.radius=.071;b2.height=.1;b2.is_hemisphere=true;b2.radial_segments=14;b2.rings=4
	belly.mesh=b2;belly.material_override=white;belly.rotation.x=PI;belly.position.y=-.005;bobber.add_child(belly)
	var stem:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=.009;c.bottom_radius=.013;c.height=.2;c.radial_segments=6
	stem.mesh=c;stem.material_override=white;stem.position.y=.16;bobber.add_child(stem)
	var tip_mat:=StandardMaterial3D.new();tip_mat.albedo_color=Color("ffd23a");tip_mat.emission_enabled=true;tip_mat.emission=Color("ffb000");tip_mat.emission_energy_multiplier=.6
	var tip:=MeshInstance3D.new();var c2:=CylinderMesh.new();c2.top_radius=.011;c2.bottom_radius=.011;c2.height=.05;c2.radial_segments=6
	tip.mesh=c2;tip.material_override=tip_mat;tip.position.y=.28;bobber.add_child(tip)
	var keel:=MeshInstance3D.new();var c3:=CylinderMesh.new();c3.top_radius=.008;c3.bottom_radius=.004;c3.height=.14;c3.radial_segments=5
	keel.mesh=c3;keel.material_override=white;keel.position.y=-.12;bobber.add_child(keel)
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
	var end := target + Vector3(sin(elapsed * 1.8) * 0.15, 0., 0)
	end.y = Waves.height_at(end) + .02
	if state==1:
		# The float leaves the tip as the rod comes over, then flies a real arc (rising fast, dropping
		# slower) to the water; the line pays out behind it from the tip.
		cast_elapsed+=delta
		var t:=clampf((cast_elapsed-RELEASE_AT)/maxf(cast_time-RELEASE_AT,.1),0.,1.)
		var apex: float=clampf(cast_start.distance_to(target)*.22,1.5,9.)
		var landing:=end
		end=origin.lerp(landing,t)+Vector3.UP*(4.*t*(1.-t))*apex if cast_elapsed>=RELEASE_AT else origin
	# The moment it lands: a splash and rings.
	if state==1 and cast_elapsed<RELEASE_AT:_landed=false
	if state==1 and cast_elapsed>=cast_time and not _landed:
		_landed=true;_splash(end,.35)
	if state!=1:_landed=state>=2
	_nibble=maxf(0.,_nibble-delta*2.2)
	var tilt:=Vector3(sin(elapsed*1.3)*.08,0.,sin(elapsed*1.7)*.08)
	if state == 2 and _nibble>0.:
		# A nibble: quick little dips and a twitch of the stem.
		end.y -= absf(sin(elapsed*22.))*.07*_nibble
		tilt+=Vector3(sin(elapsed*31.)*.25,0.,cos(elapsed*27.)*.2)*_nibble
	if state == 2:_bite_clock=0.
	if state == 3:
		# The take: the float is pulled under and drawn off sideways, fast at first, then held down.
		if _bite_clock==0.:_splash(end,.22);_bite_dir=Vector3(randf_range(-1.,1.),0.,randf_range(-1.,1.)).normalized()
		_bite_clock+=delta
		var pull: float=smoothstep(0.,.25,_bite_clock)
		end.y-=pull*(.32+sin(elapsed*9.)*.05)
		end+=_bite_dir*pull*minf(_bite_clock*.6,.5)
		tilt+=Vector3(_bite_dir.z,0.,-_bite_dir.x)*pull*.9
	var fighting: bool=state==4 and hooked!=null and hooked.visible and hooked.mode=="fight"
	if fighting:
		# The float is dragged along above the fish and pulled under when it dives.
		var above: Vector3=hooked.global_position
		var surface: float=Waves.height_at(above)
		end=Vector3(above.x,surface+.1-clampf((surface-above.y)*.45,0.,.6),above.z)
	bobber.global_position = end
	bobber.rotation=tilt
	ripple.global_position = Vector3(end.x, 0, end.z)
	ripple.visible=state!=1
	Waves.bind(ripple.material_override)
	ripple.material_override.set_shader_parameter("age",fmod(elapsed,2.5))
	ripple.material_override.set_shader_parameter("strength",(.4+_nibble*.5) if state!=3 else .9)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	# A slack line sags; a tight one runs straight and hums (small fast vibration) near breaking point.
	var sag: float=0.5 if state!=4 else lerpf(.45,.02,clampf(tension*1.3,0.,1.))
	var hum: float=maxf(0.,tension-.75)*.12
	for i in 17:
		var t := float(i) / 16.0
		var p := origin.lerp(end, t)
		p.y -= sin(t * PI) * sag
		p.y += sin(t*PI)*sin(elapsed*60.+t*9.)*hum
		line_mesh.surface_add_vertex(p)
	line_mesh.surface_end()
	if fighting:
		line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		line_mesh.surface_add_vertex(end);line_mesh.surface_add_vertex(hooked.mouth)
		line_mesh.surface_end()
