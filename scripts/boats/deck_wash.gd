extends Node3D
## The sea against the player's hull, felt and heard:
##   · slaps — when the water at the side rises fast against the hull a wave slaps it: a hollow thunk,
##     spray off the topsides and a small knock to the hull; stronger seas, louder slaps;
##   · green water — a sea coming over the rail pours in (fishing_boat._ship_water calls poured()): a
##     burst of white water falling inboard across the deck, with its roar;
##   · water on deck — a sheet that lies level and sloshes as the hull rolls, so it gathers on the low
##     side (the deck hides it where the planks are higher), stirred while water comes in;
##   · scuppers — streams running out of the ports on each side while there is water to drain, harder on
##     the low side.
const Waves=preload("res://scripts/world/wave_field.gd")
const Effects=preload("res://scripts/ocean/water_effects.gd")
var boat: CharacterBody3D
var sheet: MeshInstance3D
var sheet_mat: ShaderMaterial
var pour: CPUParticles3D
var scuppers: Array[CPUParticles3D]=[]
var slaps: int=0
var pours: int=0
var _model: String=""
var _prev_rel: PackedFloat32Array=PackedFloat32Array([0.,0.,0.,0.,0.,0.])
var _slap_cool: PackedFloat32Array=PackedFloat32Array([0.,0.,0.,0.,0.,0.])
var _slosh: Vector2=Vector2.ZERO
var _slosh_v: Vector2=Vector2.ZERO
var _stir: float=0.
var _prev_roll: float=0.
var _prev_pitch: float=0.

func _ready() -> void:
	sheet=MeshInstance3D.new();sheet.name="AguaNoConves";sheet.mesh=PlaneMesh.new()
	(sheet.mesh as PlaneMesh).subdivide_width=12;(sheet.mesh as PlaneMesh).subdivide_depth=16
	sheet_mat=ShaderMaterial.new();sheet_mat.shader=preload("res://assets/shaders/deck_water.gdshader")
	sheet.material_override=sheet_mat;sheet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.top_level=true;sheet.visible=false;add_child(sheet)
	pour=_drops(220,1.2,true,Vector2(.07,.2));pour.top_level=true;pour.name="AguaEntrando";add_child(pour)
	for i: int in 4:
		var f:=_drops(220,1.1,true,Vector2(.07,.2));f.top_level=true;f.name="Borrifo_%d"%i;add_child(f);_fans.append(f)
	land=_drops(120,.5,true,Vector2(.06,.11));land.top_level=true;land.name="RespingoNoConves";add_child(land)
	land.initial_velocity_min=.6;land.initial_velocity_max=1.8;land.spread=55.;land.gravity=Vector3(0,-9.8,0)

var _fans: Array[CPUParticles3D]=[]
var _fan_next: int=0
var land: CPUParticles3D
var _land_at:=Vector3.ZERO
var _land_in: float=-1.

## Water drops: thin streaks stretched along their flight, bright at first and fading as they fall;
## `mist` gives soft round puffs that drift and fade (the fine spray hanging after a hit).
func _drops(amount: int,life: float,one_shot: bool,size: Vector2,mist: bool=false) -> CPUParticles3D:
	var p:=CPUParticles3D.new();p.amount=amount;p.lifetime=life;p.one_shot=one_shot;p.emitting=false
	p.explosiveness=.85 if one_shot else 0.
	p.randomness=.4;p.lifetime_randomness=.45
	var quad:=QuadMesh.new();quad.size=size;quad.material=_spray_material(mist);p.mesh=quad
	p.particle_flag_align_y=not mist
	p.gravity=Vector3(0,-3.,0) if mist else Vector3(0,-9.8,0)
	p.damping_min=.5 if mist else 0.;p.damping_max=1.5 if mist else .2
	p.spread=28.;p.initial_velocity_min=1.5;p.initial_velocity_max=3.
	p.scale_amount_min=.5;p.scale_amount_max=1.4
	var curve:=Curve.new()
	if mist:curve.add_point(Vector2(0.,.4));curve.add_point(Vector2(1.,1.8))
	else:curve.add_point(Vector2(0.,1.));curve.add_point(Vector2(1.,.35))
	p.scale_amount_curve=curve
	var ramp:=Gradient.new()
	ramp.set_color(0,Color(1.,1.,1.,.95 if not mist else .38));ramp.set_color(1,Color(.82,.92,.95,0.))
	p.color_ramp=ramp
	return p

static var _spray_mats: Dictionary={}
## White water: soft-edged, unshaded but lit by the sky colour, facing the camera as particles do
## (stretched along their flight for drops, round for mist).
static func _spray_material(mist: bool) -> StandardMaterial3D:
	if _spray_mats.has(mist):return _spray_mats[mist]
	var mat:=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;mat.vertex_color_use_as_albedo=true
	mat.albedo_color=Color(.95,.98,1.,.9 if not mist else .5)
	var g:=Gradient.new();g.set_color(0,Color(1,1,1,1));g.set_color(1,Color(1,1,1,0))
	if not mist:g.add_point(.55,Color(1,1,1,.8))
	var tex:=GradientTexture2D.new();tex.width=32;tex.height=64 if not mist else 32
	tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(.5,0.) if not mist else Vector2(1.,.5)
	tex.gradient=g;mat.albedo_texture=tex
	mat.disable_receive_shadows=true
	_spray_mats[mist]=mat
	return mat

## A fan of spray thrown up at `at` along `out` (world): streaking droplets that rise and fall back, and
## a soft mist that hangs a moment and drifts with the wind.
func spray(at: Vector3,out: Vector3,power: float) -> void:
	var f: CPUParticles3D=_fans[_fan_next];_fan_next=(_fan_next+1)%_fans.size()
	var wind:=Vector3(Waves.direction.x,0.,Waves.direction.y)*Waves.wind
	f.global_position=at;f.direction=(out.normalized()*.55+Vector3.UP).normalized()
	f.spread=16.+power*12.
	f.initial_velocity_min=1.8+power*1.4;f.initial_velocity_max=3.+power*3.
	f.amount=int(clampf(60.+power*90.,60.,130.))
	f.gravity=Vector3(0,-9.8,0)+wind*2.
	f.restart();f.emitting=true
	# The fine spray hanging after the hit: soft puffs from the sea-spray system, carried by the wind.
	var puffs:=get_tree().get_first_node_in_group("wind_spray")
	if puffs!=null:
		for k: int in int(1.+power*3.):
			var v: Vector3=out.normalized()*randf_range(.5,1.5)+Vector3.UP*randf_range(1.5,3.)*(.6+power)+wind*2.+Vector3(randf_range(-.8,.8),0.,randf_range(-.8,.8))
			puffs.burst(at+Vector3.UP*.3+Vector3(randf_range(-.4,.4),0.,randf_range(-.4,.4)),v,.6+power*.8)

## Scupper ports along both sides of the deck (rebuilt when the hull changes).
func _build_scuppers() -> void:
	for s: CPUParticles3D in scuppers:s.queue_free()
	scuppers.clear()
	if not is_instance_valid(boat._hull) or str(boat.hull_spec.get("kind",""))=="canoa":return
	var deck: Dictionary=boat.hull_spec.deck
	for side: float in [-1.,1.]:
		for k: int in 3:
			var z: float=lerpf(float(deck.z0),float(deck.z1),.22+.28*float(k))
			var p:=_drops(40,.8,false,Vector2(.1,.42));p.name="Embornal"
			p.position=Vector3(side*(float(deck.x)+.25),float(deck.y)+.05,z)
			p.direction=Vector3(side,-.2,0.);p.initial_velocity_min=1.;p.initial_velocity_max=2.;p.spread=8.
			p.color_ramp.set_color(0,Color(.9,.96,1.,.75))
			p.set_meta("side",side)
			boat._hull.add_child(p);scuppers.append(p)

## A sea coming over the rail at `at` (world): a burst of white water shoots up off the rail, falls
## inboard and spatters across the deck, and the deck water is stirred.
func poured(at: Vector3,over: float) -> void:
	pours+=1
	var inward: Vector3=(boat.global_position-at);inward.y=0.;inward=inward.normalized()
	var power: float=clampf(.4+over,0.,1.5)
	spray(at+Vector3.UP*.15,-inward*.3+Vector3.UP*.2,power)
	pour.global_position=at+Vector3.UP*.25
	pour.direction=(inward+Vector3.UP*.7).normalized();pour.spread=22.
	pour.initial_velocity_min=1.6+over*1.2;pour.initial_velocity_max=2.8+over*2.2
	pour.amount=int(clampf(70.+over*110.,70.,150.))
	pour.restart();pour.emitting=true
	# Where it comes down on deck it spatters a moment later.
	_land_at=at+inward*clampf(1.4+over*1.5,1.,3.)
	_land_in=.38
	_stir=minf(1.,_stir+.5+over)
	if boat.water_effects!=null:boat.water_effects.splash(at,.9+over,true)
	var game:=get_tree().get_first_node_in_group("game")
	if game!=null:game.audio.cue_at("pour",at,clampf(over*8.-4.,-6.,4.))

func _process(delta: float) -> void:
	if Engine.get_process_frames()%15==0:
		for mist: bool in _spray_mats:preload("res://scripts/ocean/water_effects.gd").night_tint(_spray_mats[mist],Color(.95,.98,1.,.9 if not mist else .5),get_tree())
	if boat==null or not is_instance_valid(boat._hull) or boat.sinking:
		if sheet!=null:sheet.visible=false
		return
	if str(boat.hull_model)!=_model:_model=str(boat.hull_model);_build_scuppers()
	if _land_in>=0.:
		_land_in-=delta
		if _land_in<0.:
			var deck_y: float=boat._hull.to_global(Vector3(0.,float(boat.hull_spec.deck.y),0.)).y
			land.global_position=Vector3(_land_at.x,deck_y+.05,_land_at.z);land.direction=Vector3.UP
			land.restart();land.emitting=true
	_slaps(delta)
	_deck_water(delta)

## Water rising fast against the hull side: a slap.
func _slaps(delta: float) -> void:
	var hull: Node3D=boat._hull
	var spec: Dictionary=boat.hull_spec
	var sf: float=boat.size_factor
	var half_b: float=float(spec.beam)*.5*sf;var half_l: float=float(spec.length)*.5*sf
	var pts: Array[Vector3]=[Vector3(-half_b,0,-half_l*.45),Vector3(half_b,0,-half_l*.45),Vector3(-half_b,0,0),Vector3(half_b,0,0),Vector3(-half_b*.8,0,half_l*.45),Vector3(half_b*.8,0,half_l*.45)]
	var game:=get_tree().get_first_node_in_group("game")
	for i: int in pts.size():
		var side_world: Vector3=boat.global_position+boat.global_basis*pts[i]
		var water: float=Waves.height_at(side_world)
		# Where the hull's side is at the waterline right now (hull space y = draft at rest).
		var hull_y: float=hull.to_global(Vector3(pts[i].x/sf,float(boat.hydrodynamics.draft_offset),pts[i].z/sf)).y
		var rel: float=water-hull_y
		var speed: float=(rel-_prev_rel[i])/maxf(delta,.001)
		_prev_rel[i]=rel
		_slap_cool[i]=maxf(0.,_slap_cool[i]-delta)
		# Forward motion drives the bow into the waves too.
		var drive: float=speed+(maxf(0.,float(boat.speed))*.12 if i<2 else 0.)
		if drive>.55 and rel>-.35 and _slap_cool[i]<=0. and delta>0.:
			_slap_cool[i]=randf_range(.35,.6)
			slaps+=1
			# Spray and the knock come from hard slaps only (as hard as before the softer sea); the lighter
			# ones are heard, not seen, so a seaway does not wrap the boat in a cloud of spray.
			var hard: float=clampf((drive-.75)/2.5,0.,1.)
			if game!=null:
				var ear: float=game.player.global_position.distance_to(side_world)
				if ear<60.:game.audio.cue_at("slap",side_world,-8.+hard*10.)
			if hard>.08:
				# The slap throws a fan of spray up the topsides.
				var out: Vector3=boat.global_basis.x*signf(pts[i].x)
				spray(side_world+out*.1+Vector3.UP*maxf(rel,-.1),out,hard)
			# A hard slap knocks the hull a little.
			boat.roll_rate+=-signf(pts[i].x)*hard*.08
			if hard>.6 and boat.water_effects!=null:boat.water_effects.splash(side_world,.5+hard,true)

## The sheet of water on deck and the scuppers.
func _deck_water(delta: float) -> void:
	var wf: float=boat.water_fraction()
	var hull: Node3D=boat._hull
	# Slosh: the water lags the hull's roll and pitch and swings back (a damped spring).
	var roll: float=hull.rotation.z;var pitch: float=hull.rotation.x
	var accel:=Vector2(roll-_prev_roll,pitch-_prev_pitch)/maxf(delta,.001)
	_prev_roll=roll;_prev_pitch=pitch
	_slosh_v+=(-_slosh*9.-_slosh_v*2.2)*delta-accel*.6*delta*6.
	_slosh+=_slosh_v*delta
	_slosh=_slosh.limit_length(.25)
	_stir=maxf(0.,_stir-delta*.6)+minf(accel.length()*.02,.05)
	sheet.visible=wf>.008
	for s: CPUParticles3D in scuppers:
		# Harder on the low side; nothing once the deck is dry.
		var low: float=-signf(roll)*float(s.get_meta("side"))
		s.emitting=wf>.015 and (low>=0. or absf(roll)<.05 or wf>.25)
		s.speed_scale=.7+wf*1.5
	if not sheet.visible:return
	var deck: Dictionary=boat.hull_spec.deck
	var w: float=float(deck.x)*2.+.2;var l: float=float(deck.z1)-float(deck.z0)
	(sheet.mesh as PlaneMesh).size=Vector2(w,l)
	var sf: float=boat.size_factor
	var centre: Vector3=hull.to_global(Vector3(0.,float(deck.y),(float(deck.z0)+float(deck.z1))*.5))
	# Level with the horizon (yaw follows the boat), a little higher as more water comes aboard; the
	# lower side of the deck holds it, so on a heeled hull the sheet sits low and shows only there.
	var level: float=lerpf(.03,.42,clampf(wf,0.,1.))*sf
	var heel_drop: float=absf(sin(roll))*float(deck.x)*sf*(1.-clampf(wf*1.4,0.,.9))
	var yaw_basis:=Basis(Vector3.UP,boat.global_rotation.y)
	sheet.global_transform=Transform3D(yaw_basis*Basis(Vector3.RIGHT,_slosh.y)*Basis(Vector3.BACK,_slosh.x),centre+Vector3.UP*(level-heel_drop*.5))
	sheet.scale=Vector3.ONE*sf
	sheet_mat.set_shader_parameter("amount",wf)
	sheet_mat.set_shader_parameter("stir",_stir)
	# It runs off towards the low side (and aft when she is down by the stern), out of the scuppers.
	sheet_mat.set_shader_parameter("flow",Vector2(clampf(-sin(roll)*5.,-1.,1.),clampf(sin(pitch)*4.,-1.,1.))+Vector2(_slosh.x,_slosh.y)*2.)
