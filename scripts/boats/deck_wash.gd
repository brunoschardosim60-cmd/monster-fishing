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
	pour=_particles(140,1.1,true);pour.top_level=true;pour.name="AguaEntrando";add_child(pour)

func _particles(amount: int,life: float,one_shot: bool) -> CPUParticles3D:
	var p:=CPUParticles3D.new();p.amount=amount;p.lifetime=life;p.one_shot=one_shot;p.emitting=false
	p.explosiveness=.75 if one_shot else 0.
	var quad:=QuadMesh.new();quad.size=Vector2(.16,.28);quad.material=Effects.drop_material();p.mesh=quad
	p.gravity=Vector3(0,-9.8,0);p.spread=18.;p.initial_velocity_min=1.5;p.initial_velocity_max=3.
	p.scale_amount_min=.7;p.scale_amount_max=1.6
	p.color=Color(.85,.93,.95,.8)
	return p

## Scupper ports along both sides of the deck (rebuilt when the hull changes).
func _build_scuppers() -> void:
	for s: CPUParticles3D in scuppers:s.queue_free()
	scuppers.clear()
	if not is_instance_valid(boat._hull) or str(boat.hull_spec.get("kind",""))=="canoa":return
	var deck: Dictionary=boat.hull_spec.deck
	for side: float in [-1.,1.]:
		for k: int in 3:
			var z: float=lerpf(float(deck.z0),float(deck.z1),.22+.28*float(k))
			var p:=_particles(26,.9,false);p.name="Embornal"
			p.position=Vector3(side*(float(deck.x)+.25),float(deck.y)+.05,z)
			p.direction=Vector3(side,-.35,0.);p.initial_velocity_min=.9;p.initial_velocity_max=1.8;p.spread=10.
			p.set_meta("side",side)
			boat._hull.add_child(p);scuppers.append(p)

## A sea coming over the rail at `at` (world): white water bursts in, falling across the deck.
func poured(at: Vector3,over: float) -> void:
	pours+=1
	var inward: Vector3=(boat.global_position-at);inward.y=0.;inward=inward.normalized()
	pour.global_position=at+Vector3.UP*.3
	pour.direction=inward*1.+Vector3.UP*.45
	pour.initial_velocity_min=2.+over*2.;pour.initial_velocity_max=3.5+over*4.
	pour.amount=int(clampf(70.+over*120.,70.,140.))
	pour.restart();pour.emitting=true
	_stir=minf(1.,_stir+.5+over)
	if boat.water_effects!=null:boat.water_effects.splash(at,.9+over,true)
	var spray:=get_tree().get_first_node_in_group("wind_spray")
	if spray!=null:
		for k: int in 4:spray.burst(at+Vector3.UP*.2,inward*(2.+over*2.)+Vector3.UP*(2.5+over*3.)+Vector3(randf_range(-1,1),0,randf_range(-1,1)),1.+over)
	var game:=get_tree().get_first_node_in_group("game")
	if game!=null:game.audio.cue_at("pour",at,clampf(over*8.-4.,-6.,4.))

func _process(delta: float) -> void:
	if boat==null or not is_instance_valid(boat._hull) or boat.sinking:
		if sheet!=null:sheet.visible=false
		return
	if str(boat.hull_model)!=_model:_model=str(boat.hull_model);_build_scuppers()
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
		if drive>.75 and rel>-.35 and _slap_cool[i]<=0. and delta>0.:
			_slap_cool[i]=randf_range(.35,.6)
			slaps+=1
			var hard: float=clampf((drive-.75)/2.5,0.,1.)
			if game!=null:
				var ear: float=game.player.global_position.distance_to(side_world)
				if ear<60.:game.audio.cue_at("slap",side_world,-8.+hard*10.)
			var spray:=get_tree().get_first_node_in_group("wind_spray")
			if spray!=null and hard>.15:
				var out: Vector3=boat.global_basis.x*signf(pts[i].x)
				spray.burst(side_world+Vector3.UP*(rel+.2),out*(1.+hard*2.)+Vector3.UP*(2.+hard*4.)+Vector3(Waves.direction.x,0,Waves.direction.y)*Waves.wind*3.,.5+hard)
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
