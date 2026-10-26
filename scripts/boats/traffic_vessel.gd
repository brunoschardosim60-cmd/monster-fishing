extends CharacterBody3D
## A vessel with somewhere to go. It follows its route (trade lane, coastal loop or far ocean lane),
## varies the route a little every lap, stops on fishing grounds while its crew fishes, runs for
## shelter when a storm builds (small boats) or slows down (big ships), reefs its sails in strong wind,
## gives way to the player and heaves to when hailed. The hull rides the waves (heave, pitch, roll),
## leaves a wake, and its crew lives aboard. Far from the camera the expensive parts sleep.
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Models=preload("res://scripts/boats/vessel_models.gd")
const Crew=preload("res://scripts/boats/crew_member.gd")
const SMALL: Array[String]=["canoa","bote_remo","bote","veleiro"]
const SAILS: Array[String]=["veleiro","escuna"]
const NAMES: Dictionary={"canoa":"Canoa","bote_remo":"Bote a remo","bote":"Bote de pesca","pesqueiro":"Pesqueiro","veleiro":"Veleiro",
	"escuna":"Escuna","rebocador":"Rebocador","apoio":"Navio de apoio","cargueiro":"Cargueiro","petroleiro":"Petroleiro","gigante":"Porta-contêineres"}
var route: Array[Vector3]=[]
var base_route: Array[Vector3]=[]
var waypoint: int=0
var length_m: float=12.
var beam_m: float=0.
var cruise_speed: float=4.
var kind: String="bote"
var turn_rate: float=.35
var seed_value: int=1
## Name painted on the hull, shown when the player hails.
var ship_name: String=""
## Waypoints (indices) where this vessel stops to fish.
var fishing_stops: Array[int]=[]
## Where small boats run to when a storm builds.
var shelter: Vector3=Vector3.INF
var player_boat: Node3D
var speed: float=0.
var hull: Node3D
var model: Node3D
var trail: MeshInstance3D
var crew: Array=[]
var waiting_for_player: bool=false
var yield_side: float=1.
## navegando · pescando · abrigando · abrigado · saudado
var activity: String="navegando"
var activity_clock: float=0.
var lap: int=0
var night: float=0.
var _rng:=RandomNumberGenerator.new()
var _bob_clock: float=0.
var _phase: float=0.

func _ready() -> void:
	_rng.seed=seed_value
	if beam_m<=0.:beam_m=Models.beam_of(kind,length_m)
	if ship_name.is_empty():ship_name=NAMES.get(kind,"Barco")
	collision_layer=1;collision_mask=3;motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(beam_m*.9,2.,length_m*.9);collision.shape=box;collision.position.y=.2;add_child(collision)
	hull=Node3D.new();hull.name="Flutuacao";add_child(hull)
	model=Models.build(kind,length_m,seed_value);hull.add_child(model)
	if length_m>=12.:
		var lamp:=OmniLight3D.new();lamp.position=Vector3(0,float(model.get_meta("deck",1.))+2.,0);lamp.omni_range=length_m*.4;lamp.light_energy=0.;lamp.light_color=Color("ffd8a0");lamp.name="Luz";hull.add_child(lamp)
	trail=preload("res://scripts/ocean/wake_trail.gd").new();trail.stern_offset=length_m*.46;trail.half_width=beam_m*.5;add_child(trail)
	_make_crew()
	base_route=route.duplicate()
	if route.size()>1:
		position=route[waypoint];waypoint=(waypoint+1)%route.size();look_at(Vector3(route[waypoint].x,position.y,route[waypoint].z))

func _make_crew() -> void:
	var size: int=int(model.get_meta("crew",1))
	var seats: Array=model.get_meta("seats",[])
	var rails: Array=model.get_meta("rails",[])
	var walk: Array=model.get_meta("walk",[])
	for i: int in size:
		var person:=Crew.new();person.look_id=seed_value*3+i*5
		if not seats.is_empty():
			var seat: Array=seats[i%seats.size()]
			person.role="rower" if kind=="bote_remo" and i==0 else ("helm" if i==0 else "passenger")
			person.position=seat[0];person.facing=seat[1]
		elif i==0:
			person.role="helm";person.position=model.get_meta("helm",Vector3(0,1,0));person.facing=0.
		elif i==1 and walk.size()==2:
			person.role="deckhand";person.walk_a=walk[0];person.walk_b=walk[1];person.position=walk[0]
		elif not rails.is_empty():
			var rail: Array=rails[(i-1)%rails.size()]
			person.role="fisher" if kind in ["bote","pesqueiro"] or _rng.randf()<.35 else "passenger"
			person.position=rail[0];person.facing=rail[1]
		else:
			person.role="passenger";person.position=model.get_meta("helm",Vector3(0,1,0))+Vector3(.8,0,.8)
		person.name="Tripulante_%d"%i;hull.add_child(person);crew.append(person)

## Ask the vessel to heave to beside the player for a while (used when the player hails it).
func hail() -> void:
	if activity in ["abrigando","abrigado"]:return
	activity="saudado";activity_clock=25.

func is_small() -> bool:return kind in SMALL

func _physics_process(delta: float) -> void:
	if route.size()<2:return
	activity_clock=maxf(0.,activity_clock-delta)
	_update_activity()
	var target_point:=route[waypoint]
	if activity in ["abrigando","abrigado"] and shelter!=Vector3.INF:target_point=shelter
	var to: Vector3=target_point-position;to.y=0.
	if activity=="navegando" and to.length()<maxf(25.,length_m):
		if waypoint in fishing_stops:activity="pescando";activity_clock=_rng.randf_range(35.,70.)
		waypoint=(waypoint+1)%route.size()
		if waypoint==0:_vary_route()
		to=route[waypoint]-position;to.y=0.
	if activity=="abrigando" and to.length()<maxf(20.,length_m):activity="abrigado"
	var desired:=to.normalized();var was_yielding:=waiting_for_player;waiting_for_player=false
	var clearance_velocity:=Vector3.ZERO;var yield_speed:=0.
	if is_instance_valid(player_boat):
		var separation:=position-player_boat.position;separation.y=0.
		if separation.length()<length_m+85. and activity!="saudado":
			waiting_for_player=true
			var lateral:=separation.dot(player_boat.basis.x)
			if not was_yielding:yield_side=1. if lateral>=0. else -1.
			var aside: Vector3=player_boat.basis.x*yield_side
			if Layout.coast(Vector2(position.x+aside.x*25.,position.z+aside.z*25.)).x<length_m:aside=-aside;yield_side=-yield_side
			var separation_needed:=length_m*.14+9.
			if absf(lateral)<separation_needed:
				desired=(desired*.2+aside).normalized()
				# Close-quarters thruster manoeuvre prevents a stopped NPC becoming
				# a permanent obstacle when the player approaches its hull.
				clearance_velocity=aside*1.4
			yield_speed=0. if separation.length()<length_m+20. else cruise_speed*.45
	var ahead:=position+desired*maxf(28.,length_m)
	var coast:=Layout.coast(Vector2(ahead.x,ahead.z))
	if coast.x<length_m and activity!="abrigando":desired=Vector3(coast.y,0,coast.z)
	rotation.y=lerp_angle(rotation.y,atan2(-desired.x,-desired.z),delta*turn_rate)
	var safe:=Layout.coast(Vector2(position.x,position.z)).x>length_m*.5 or (activity=="abrigando" and Layout.coast(Vector2(position.x,position.z)).x>3.)
	speed=move_toward(speed,_target_speed(yield_speed) if safe else 0.,delta*(1.8 if length_m<40. else .6))
	velocity=-basis.z*speed+clearance_velocity;velocity.y=0.;move_and_slide();position.y=0.
	if get_slide_collision_count()>0:speed=0.
	_ride_waves(delta)
	var camera:=get_viewport().get_camera_3d()
	var near:=camera!=null and camera.global_position.distance_squared_to(position)<490000.
	if near:
		trail.advance(position,basis,speed,delta)
		_animate(delta)
	else:trail.clear_trail()

func _update_activity() -> void:
	var storm:=Waves.wind>.72
	match activity:
		"navegando":
			if storm and is_small() and shelter!=Vector3.INF:activity="abrigando"
		"pescando":
			if storm and is_small() and shelter!=Vector3.INF:activity="abrigando"
			elif activity_clock<=0.:activity="navegando"
		"abrigando","abrigado":
			if Waves.wind<.55:activity="navegando"
		"saudado":
			if activity_clock<=0.:activity="navegando"
	for person in crew:person.vessel_fishing=activity=="pescando"

func _target_speed(yield_speed: float) -> float:
	if waiting_for_player:return yield_speed
	match activity:
		"pescando","abrigado","saudado":return 0.
		"abrigando":return cruise_speed*1.15
	var base:=cruise_speed
	if kind in SAILS:base*=clampf(.55+Waves.wind*.9,.55,1.35)
	elif Waves.wind>.75:base*=.75 if length_m<40. else .85
	return base

## Each lap the vessel takes a slightly different line between its waypoints (never closer to land).
func _vary_route() -> void:
	lap+=1
	for i: int in route.size():
		var p:=base_route[i]+Vector3(_rng.randf_range(-14.,14.),0,_rng.randf_range(-14.,14.))
		route[i]=p if Layout.coast(Vector2(p.x,p.z)).x>=Layout.coast(Vector2(base_route[i].x,base_route[i].z)).x-4. else base_route[i]

func _ride_waves(delta: float) -> void:
	# Far vessels sample the sea less often; nobody can see the difference at that range.
	_bob_clock+=delta
	var camera:=get_viewport().get_camera_3d()
	var far:=camera!=null and camera.global_position.distance_squared_to(position)>1440000.
	if far and _bob_clock<.25:return
	var step:=_bob_clock;_bob_clock=0.
	var half_l:=length_m*.35;var half_b:=beam_m*.45
	var front:=Waves.height_at(position-basis.z*half_l);var rear:=Waves.height_at(position+basis.z*half_l)
	var left:=Waves.height_at(position-basis.x*half_b);var right:=Waves.height_at(position+basis.x*half_b)
	# Small hulls follow every wave; big ones average them out and barely move.
	var response:=clampf(30./length_m,.25,3.)
	var lean:=0.
	if kind in SAILS:lean=-clampf(Waves.wind*.18,0.,.16)
	hull.position.y=lerpf(hull.position.y,(front+rear+left+right)*.25,1.-exp(-step*2.*response))
	hull.rotation.x=lerpf(hull.rotation.x,atan((front-rear)/(length_m*.7)),1.-exp(-step*2.*response))
	hull.rotation.z=lerpf(hull.rotation.z,atan((right-left)/maxf(beam_m,.8))+lean,1.-exp(-step*2.*response))

func _animate(delta: float) -> void:
	_phase+=delta
	var underway:=speed>.3
	for oar: Node3D in model.get_meta("oars",[]):
		var stroke:=sin(_phase*(2.4 if underway else .6))
		oar.rotation=Vector3(0.,stroke*.55 if underway else 0.,stroke*.18 if underway else .05)
	var flag: Node3D=model.get_meta("flag") if model.has_meta("flag") else null
	if flag!=null:flag.rotation.y=sin(_phase*3.1)*.22*(.4+Waves.wind)+sin(_phase*7.3)*.06
	var reef:=1.-clampf((Waves.wind-.55)*2.2,0.,.45)
	for sail: Node3D in model.get_meta("sails",[]):sail.scale=Vector3(1.,lerpf(sail.scale.y,reef,1.-exp(-delta)),1.)

## 0 by day, 1 at night: windows and deck lamps glow.
func set_night(value: float) -> void:
	night=value
	var windows: StandardMaterial3D=model.get_meta("windows") if model.has_meta("windows") else null
	if windows!=null:windows.emission_energy_multiplier=value*2.2
	var lamp:=hull.get_node_or_null("Luz") as OmniLight3D
	if lamp!=null:lamp.light_energy=value*1.8
