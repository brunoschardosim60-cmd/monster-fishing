class_name FishingBoat
extends CharacterBody3D
const Sculpt = preload("res://scripts/visuals/sculpt.gd")
const Materials = preload("res://scripts/visuals/materials.gd")
const Waves = preload("res://scripts/world/wave_field.gd")
const G = preload("res://scripts/world/geometry.gd")
## Horizontal collision controller plus a damped, four-point waterline sampler.
@export var hydrodynamics: Resource=preload("res://data/boats/coastal_launch.tres")
var water_effects: Node3D
var imported_model: Node3D
var bucket: Marker3D
var integrity: float=1.
## Sea water that has come aboard (kg): over the rail when a wave rises past it, or with a breaking sea.
## It weighs the hull down (she floats deeper and lower, rolls heavier and is slower), drains through the
## scuppers and the bilge pump, can be bailed out (E on deck), and too much of it swamps the boat.
var water_aboard: float=0.
## Waves against the hull, green water, water on deck and the scuppers (deck_wash.gd).
var deck_wash: Node3D
## The room below (cabin_interior.gd), on hulls that have one; null otherwise.
var cabin_node: Node3D
var _water_note: int=0
## Boost (SHIFT at the helm): a few seconds of extra power to outrun a monster, then the engine cools.
var boost: float=0.
var boost_cooldown: float=0.
const BOOST_TIME: float=6.
const BOOST_COOLDOWN: float=25.
## When the hull gives way (integrity 0) the boat goes down; main.gd rescues the player when `sank` fires.
var sinking: bool=false
var sink_clock: float=0.
signal sank
## Extra roll from a blow (monster strike, rogue wave); decays back to the wave-driven attitude.
var kick_roll: float=0.
var trail: MeshInstance3D
var heave_velocity: float=0.
## Hull motion state (visual hull in boat space): pitch and roll rates, and how fast the bow is being
## driven into the water (for spray when it slams into a sea).
var pitch_rate: float=0.
var roll_rate: float=0.
var _bow_slam: float=0.
var _bow_prev: float=0.
var impact_cooldown: float=0.
var lights_enabled: bool=true
var searchlight_upgraded: bool=false
var hull_protection: float=1.
var deck_lights: Array[Light3D]=[]
var lamp_materials: Array[StandardMaterial3D]=[]
var searchlight: SpotLight3D
## Searchlight aim relative to the bow, in radians. U/O swing it, I/K tilt it while you are at the helm.
var light_yaw: float=0.
var light_pitch: float=0.

## Anchor (Z): while it is out the engine is locked; once it bites the boat swings on its chain.
var anchor
## Hold and net size factor of the current hull (boatyard boats differ).
var capacity: float=1.
var livery_hull: Color=Color("e2d2ad")
var occupied: bool = false
var controls_enabled: bool = true
var speed: float = 0.0
var max_speed: float = 11.0
var wake_strength: float = 0.0
var _clock: float = 0.0
## Helm and engine state. The rudder (-1 port … +1 starboard) follows the wheel at a limited rate and
## self-centres slowly; the hull's yaw rate builds up with inertia, so heavier hulls answer later and
## keep turning after the wheel is centred. The engine spools up and down instead of jumping to power.
var rudder: float=0.
var yaw_rate: float=0.
## A hired helmsman at the wheel while the skipper is elsewhere: {"throttle": -1..1, "heading": yaw in radians}.
## Holds that course and speed (crew_manager.gd sets it, and cuts the engine near land).
var autopilot: Dictionary={}
var engine_rpm: float=0.
## Per-class handling (set by harbor_economy.apply): wheel speed, turning power, acceleration,
## yaw inertia (seconds to answer the rudder) and astern speed.
var handling: Dictionary={"rudder_rate":2.2,"turn":1.,"accel":2.7,"inertia":.2,"reverse":3.2}
var helm_wheel: Node3D
## Hull class (hull_classes.gd): "tripo" is the imported launch, the others are built by vessel_models.
const HullClasses=preload("res://scripts/boats/hull_classes.gd")
const VesselModels=preload("res://scripts/boats/vessel_models.gd")
var _tripo_propeller: Node3D
signal warning(text: String)
## The hull class changed (new model, deck, holders…).
signal hull_changed
var hull_model: String="tripo"
var hull_spec: Dictionary=HullClasses.SPECS.tripo
var sail_rig: RefCounted
## Sail the skipper asked for (0 furled, .5 reefed, 1 full) and the push the sails give (m/s).
var sail_target: float=0.
var sail_speed: float=0.
var sail_heel: float=0.
var _overcanvas_clock: float=0.
var _alt_body: Node3D
## Sailors aboard the bigger player hulls (crew_member.gd), rebuilt with the hull.
var crew: Array[Node3D]=[]
var _tripo_parts: Array[Node3D]=[]
var _tripo_lights: Array[Light3D]=[]
var _tripo_lamps: Array[StandardMaterial3D]=[]
var _tripo_wheel: Node3D
var _tripo_bucket: Marker3D
var _tripo_hydro: Resource
var _collision_box: BoxShape3D
var _base_box: Vector3
var _hull: Node3D
var _propeller: Node3D
var _foam_left: MeshInstance3D
var _foam_right: MeshInstance3D
## Bow wave: white water peeling off both sides of the stem, growing with speed.
var _bow_left: MeshInstance3D
var _bow_right: MeshInstance3D
var _wake_material: ShaderMaterial
const DOCK_POSITION: Vector3 = Vector3(3.9, 0.0, -23.0)

func _ready() -> void:
	deck_wash=preload("res://scripts/boats/deck_wash.gd").new();deck_wash.name="MarNoCasco";deck_wash.boat=self;add_child(deck_wash)
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.65, 1.0, 8.1) if ResourceLoader.exists("res://assets/boats/fishing_boat.glb") else Vector3(2.05, 1.0, 4.8)
	shape.shape = box
	_collision_box=box;_base_box=box.size
	shape.position.y = 0.5
	add_child(shape)
	_build_visual()
	_build_bucket()
	_build_lights()
	for child: Node in _hull.get_children():
		if child!=_propeller and child!=searchlight and child is Node3D:_tripo_parts.append(child)
	_tripo_lights=deck_lights.duplicate();_tripo_lamps=lamp_materials.duplicate()
	_tripo_wheel=helm_wheel;_tripo_bucket=bucket;_tripo_propeller=_propeller;_tripo_hydro=hydrodynamics.duplicate()
	trail=preload("res://scripts/ocean/wake_trail.gd").new()
	add_child(trail)
	anchor=preload("res://scripts/boats/boat_anchor.gd").new();anchor.name="Ancora";anchor.boat=self
	anchor.roller=Vector3(0,1.05,-float(hydrodynamics.waterline_length)*.48);add_child(anchor)

func _physics_process(delta: float) -> void:
	_clock += delta
	var throttle: float = 0.0
	var steering: float = 0.0
	if occupied and controls_enabled:
		throttle = Input.get_axis("move_back", "move_forward")
		steering = Input.get_axis("move_left", "move_right")
	elif not autopilot.is_empty() and controls_enabled:
		throttle=float(autopilot.throttle)
		# Wheel against the heading error, eased off by the swing already under way.
		var err: float=angle_difference(rotation.y,float(autopilot.heading))
		steering=clampf(-err*2.4+yaw_rate*1.6,-1.,1.)
	if occupied and controls_enabled and searchlight_upgraded:
		var aim_step:=1.1*delta
		if Input.is_physical_key_pressed(KEY_U): light_yaw=clampf(light_yaw+aim_step,-1.2,1.2)
		if Input.is_physical_key_pressed(KEY_O): light_yaw=clampf(light_yaw-aim_step,-1.2,1.2)
		if Input.is_physical_key_pressed(KEY_I): light_pitch=clampf(light_pitch+aim_step*.7,-.9,.25)
		if Input.is_physical_key_pressed(KEY_K): light_pitch=clampf(light_pitch-aim_step*.7,-.9,.25)
	light_yaw=clampf(light_yaw,-1.2,1.2);light_pitch=clampf(light_pitch,-.9,.25)
	if searchlight!=null:
		searchlight.rotation=Vector3(-.16+light_pitch,light_yaw,0.)
	boost=maxf(0.,boost-delta);boost_cooldown=maxf(0.,boost_cooldown-delta)
	if occupied and controls_enabled and throttle>0. and boost_cooldown<=0. and Input.is_action_pressed("sprint") and not sinking:
		boost=BOOST_TIME;boost_cooldown=BOOST_COOLDOWN+BOOST_TIME
		var audio:=get_tree().get_first_node_in_group("audio")
		if audio!=null:audio.cue("boost")
	if sinking:
		_sink(delta);return
	var anchored: bool=anchor!=null and anchor.deployed()
	if anchored:
		throttle=0.;steering=0.
	# Wheel → rudder: limited rate, slower self-centring when the wheel is let go.
	var rudder_rate: float=float(handling.rudder_rate)*(.9 if absf(steering)<.01 else 1.)
	# Spinning the wheel across to the other side goes quicker than easing it further over.
	if absf(steering)>.01 and absf(rudder)>.05 and signf(steering)!=signf(rudder):rudder_rate*=2.2
	rudder=move_toward(rudder,steering,rudder_rate*delta)
	# Engine spools up gradually and drops faster than it rises; boost answers at once.
	# Shifting from ahead to astern (or back) goes through neutral quickly: that is how a skipper brakes.
	var reversing: bool=absf(throttle)>.01 and signf(throttle)!=signf(engine_rpm) and absf(engine_rpm)>.02
	engine_rpm=move_toward(engine_rpm,throttle,(4.5 if reversing else (1.5 if absf(throttle)>absf(engine_rpm) else 2.4))*delta)
	if boost>0. and throttle>0.:engine_rpm=1.
	var accel: float=float(handling.accel)
	_update_sails(delta)
	if anchored:
		speed=move_toward(speed,0.,(2.5 if anchor.holding() else 1.2)*delta)
	elif engine_rpm > 0.02 or sail_speed>.05:
		var exposure:=Waves.exposure(Vector2(global_position.x,global_position.z))
		var limit: float=max_speed*(.55+.45*integrity)*(1.-hydrodynamics.storm_drag*maxf(0.,Waves.wind-.45)*exposure)*(1.-.45*water_fraction())
		if boost>0.:limit*=1.45
		var rpm: float=maxf(engine_rpm,0.)
		var target: float=limit*rpm+sail_speed*(1.-.4*rpm)
		var push: float=maxf((5.5 if boost>0. else accel)*rpm,accel*.35*minf(sail_speed/3.,1.))/(1.+water_fraction()*1.5)
		speed = move_toward(speed, target, (push if speed<target else 0.85+.5*accel*(1.-rpm)) * delta)
	elif engine_rpm < -0.02:
		speed = move_toward(speed, -float(handling.reverse)*absf(engine_rpm), (accel*2. if speed > 0.2 else accel*.66) * delta)
	else:
		speed = move_toward(speed, 0.0, 0.85 * delta)
	# Water flowing past the rudder: the boat's own speed plus prop wash, so a boat in gear turns at low speed.
	var flow: float=absf(speed)+maxf(engine_rpm,0.)*1.6
	var direction_sign: float=signf(speed) if absf(speed)>.3 else (1. if engine_rpm>=0. else -1.)
	var target_rate: float=0.
	if flow>.12:target_rate=-rudder*direction_sign*(0.3+minf(flow,9.)*0.065)*float(handling.turn)*minf(flow/1.2,1.)
	yaw_rate=lerpf(yaw_rate,target_rate,1.-exp(-delta/maxf(float(handling.inertia),.05)))
	rotation.y+=yaw_rate*delta
	# A hard-over rudder costs speed.
	speed-=speed*absf(rudder)*.05*delta
	if is_instance_valid(helm_wheel):helm_wheel.rotation.y=-rudder*PI*float(hull_spec.wheel[3])
	velocity = -global_transform.basis.z * speed
	# Wind pushes the hull sideways (strongest in the open and in storms); the anchor holds against it.
	var here:=Vector2(global_position.x,global_position.z)
	var push:=Vector3(Waves.direction.x,0.,Waves.direction.y)*pow(Waves.wind,2.)*2.4*Waves.exposure(here)/maxf(hydrodynamics.mass_kg/3500.,.6)/pow(size_factor,3.)
	if occupied and not (anchored and anchor.holding()):velocity+=push
	_wave_hits(delta,here)
	if anchored and anchor.holding():velocity+=anchor.restrain(delta)
	velocity.y = 0.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		if absf(speed)>2.: integrity=maxf(.15,integrity-absf(speed)*delta*.003*hull_protection)
		speed = move_toward(speed, 0.0, 9.0 * delta)
	position.y = 0.0
	var wrapped:=preload("res://scripts/world/archipelago_layout.gd").wrapped(global_position)
	if wrapped.distance_to(global_position)>100.:
		global_position=wrapped;trail.clear_trail()
	wake_strength = clampf(absf(speed) / max_speed, 0.0, 1.0)
	trail.advance(global_position,global_basis,speed,delta)
	impact_cooldown=maxf(0.,impact_cooldown-delta)
	if is_instance_valid(_hull):
		_simulate_hull(delta)
		_publish_hull()
		if water_effects!=null and impact_cooldown<=0. and _bow_slam>1.1 and absf(speed)>1.5:
			water_effects.splash(global_position-global_basis.z*float(hull_spec.length)*.45*size_factor,.4+minf(_bow_slam*.3,1.2)+wake_strength*Waves.energy,true)
			var spray:=get_tree().get_first_node_in_group("wind_spray")
			if spray!=null:
				var bow:=_hull.to_global(Vector3(0,float(hull_spec.deck.y)*.6,-float(hull_spec.length)*.46))
				var wind:=Vector3(Waves.direction.x,0.,Waves.direction.y)*(2.+Waves.wind*7.)
				for k: int in 3:spray.burst(bow+global_basis.x*(k-1)*.6,wind+global_basis.z*absf(speed)*.35+Vector3(0,3.+wake_strength*3.,0)+global_basis.x*(k-1)*1.2,.7+wake_strength)
			impact_cooldown=.65
		_propeller.rotation.z += delta * speed * 8.0
		_foam_left.visible = wake_strength > 0.08
		_foam_right.visible = wake_strength > 0.08
		_foam_left.scale.z = 0.5 + wake_strength * 2.3
		_foam_right.scale.z = 0.5 + wake_strength * 2.3
		if _bow_left!=null:
			var bow: float=clampf((absf(speed)-1.5)/7.,0.,1.)
			_bow_left.visible=bow>.02 and speed>0.;_bow_right.visible=_bow_left.visible
			_bow_left.scale=Vector3(.6+bow*.8,1.,.4+bow*1.6)*sqrt(size_factor*float(hull_spec.beam)/3.65);_bow_right.scale=_bow_left.scale
		Waves.bind(_wake_material)
		_wake_material.set_shader_parameter("strength", wake_strength)

## In heavy seas green water breaks over the bow now and then: a small blow to the hull, a lurch and spray.
var _wave_hit_clock: float=8.
## Crew lashing the deck in a storm takes the worst out of breaking seas (crew_manager.gd).
var wave_damage_scale: float=1.
func _wave_hits(delta: float,here: Vector2) -> void:
	var rough:=maxf(Waves.storm_factor(here),smoothstep(.68,1.,Waves.energy))*Waves.exposure(here)
	if rough<.25 or not occupied:return
	_wave_hit_clock-=delta*(1.+absf(speed)*.08)
	if _wave_hit_clock>0.:return
	_wave_hit_clock=randf_range(6.,13.)/rough
	take_hit((.01+.025*rough)/pow(size_factor,2.)*wave_damage_scale,(.22+.25*rough)/size_factor)
	# Green water: part of the breaking sea lands on deck.
	water_aboard+=float(hydrodynamics.mass_kg)*pow(size_factor,3.)*.035*rough*wave_damage_scale
	if deck_wash!=null:deck_wash.poured(global_position-global_basis.z*float(hull_spec.length)*.4*size_factor+Vector3.UP*(_hull.global_position.y+float(hull_spec.get("gunwale",1.))*size_factor),.4+rough*.6)
	if water_effects!=null:water_effects.splash(global_position-global_basis.z*2.+global_basis.x*randf_range(-1.,1.),1.2+rough,true)
	var game:=get_tree().get_first_node_in_group("game")
	if game!=null:
		game.audio.cue_at("slam",global_position-global_basis.z*3.,-9.)
		if not get_meta("wave_hint",false):set_meta("wave_hint",true);game.hud.notify("Uma onda quebra sobre a proa! Em mar grosso o casco sofre: reduza ou procure abrigo.")

## How full of water she is: 0 dry … 1 swamped.
func water_fraction() -> float:
	return clampf(water_aboard/water_capacity(),0.,1.2)

func water_capacity() -> float:
	return float(hydrodynamics.mass_kg)*pow(size_factor,3.)*.55

## Bailing by hand (E on deck): one bucket over the side.
func bail() -> float:
	var out: float=minf(water_aboard,45.*size_factor)
	water_aboard-=out
	return out

## Water over the rail: wherever the sea at the hull's edge stands above the rail, it pours in.
func _ship_water(delta: float,heights: Array[float],xs: Array[float],zs: Array[float],m: float) -> void:
	var gunwale: float=float(hull_spec.get("gunwale",float(hull_spec.deck.y)+.3))*size_factor
	var y: float=_hull.position.y;var pitch: float=_hull.rotation.x;var roll: float=_hull.rotation.z
	var inflow:=0.;var n:=0;var worst:=-1;var worst_over:=0.
	for z: float in zs:
		for x: float in xs:
			if not (x==0. and z==0.):
				var rail: float=y+(-z)*sin(pitch)+x*sin(roll)+gunwale
				var over: float=heights[n]-rail
				# The first few centimetres are spray off the rail; past that green water comes in.
				over-=.08
				if over>0.:
					inflow+=pow(over,1.5)*300.*size_factor*(.6 if x==0. else 1.)
					if over>worst_over:worst_over=over;worst=n
			n+=1
	if inflow>0.:
		# However hard it breaks, only so much gets in at once (the rail and the deckhouse shed the rest).
		water_aboard+=minf(inflow,m*.012)*delta
		# Water coming over the rail: a burst of white water on that side, and a lurch.
		if impact_cooldown<=0. and worst>=0:
			var at: Vector3=global_position+global_basis.x*xs[worst%3]*.9+global_basis.z*zs[worst/3]*.9
			at.y=_hull.global_position.y+gunwale
			if water_effects!=null:water_effects.splash(at,.6+minf(worst_over*1.5,1.5),true)
			roll_rate+=signf(xs[worst%3])*-minf(worst_over,.6)*.6;heave_velocity-=minf(worst_over,.5)*.6
			impact_cooldown=.5
			if deck_wash!=null:deck_wash.poured(at,worst_over)
	# Out it goes: scuppers on a decked hull (fast while there is a lot), the bilge pump with an engine.
	var decked: bool=str(hull_spec.get("kind",""))!="canoa"
	var drain: float=(water_aboard*.12 if decked else 0.)+(14.*size_factor if decked and engine_rpm>.05 else 0.)
	water_aboard=maxf(0.,water_aboard-drain*delta)
	if water_aboard>water_capacity() and not sinking:
		sinking=true;sink_clock=0.;speed=0.
		var audio:=get_tree().get_first_node_in_group("audio")
		if audio!=null:audio.cue("sink")
	_water_warnings()

func _water_warnings() -> void:
	var wf: float=water_fraction()
	var level: int=0 if wf<.3 else (1 if wf<.65 else 2)
	if level>_water_note and occupied:
		var game:=get_tree().get_first_node_in_group("game")
		if game!=null:
			game.hud.notify(["","Água no convés! O barco está mais pesado. Esgote com E no convés ou saia do mar grosso.","O barco está alagando! Esgote a água (E) ou ela afunda."][level])
	_water_note=level if level>_water_note or wf<.15 else _water_note

## Tells the sea shader where the hull is so it is not drawn inside it.
func _publish_hull() -> void:
	if not is_instance_valid(_hull):return
	var deck: Dictionary=hull_spec.deck
	# The cut follows the deck's footprint (just inside the topsides), never wider than the hull itself,
	# or the sea would show a hole beside or behind the boat.
	Waves.hull_inv=_hull.global_transform.affine_inverse()
	Waves.hull_box=Vector4(float(deck.x)+.1,float(deck.z0)-.15,float(deck.z1)+.05,float(hull_spec.get("gunwale",float(deck.y)+.3)))
	Waves.hull_keel=float(hydrodynamics.draft_offset)-float(hull_spec.get("immersion",.35))*1.6-.3

## A heavy blow to the hull: damage scaled by the boat's protection, a roll and a jolt upward.
func take_hit(damage: float,kick: float) -> void:
	if sinking:return
	integrity=maxf(0.,integrity-damage*hull_protection)
	kick_roll=clampf(kick_roll+absf(kick),0.,.55)
	# The blow is felt as a jolt: the hull is thrown up and rolled, then the water settles it.
	heave_velocity+=absf(kick)*2.5
	roll_rate+=absf(kick)*(1.6 if randf()<.5 else -1.6);pitch_rate+=absf(kick)*.8
	if integrity<=.001:
		sinking=true;sink_clock=0.;speed=0.
		var audio:=get_tree().get_first_node_in_group("audio")
		if audio!=null:audio.cue("sink")

## Going down: the stern floods first, the hull lists and slips under in about seven seconds.
func _sink(delta: float) -> void:
	sink_clock+=delta;speed=0.;velocity=Vector3.ZERO
	if is_instance_valid(_hull):
		_hull.position.y-=delta*(.25+sink_clock*.12)
		_hull.rotation.x=lerpf(_hull.rotation.x,-.32,delta*.4);_hull.rotation.z=lerpf(_hull.rotation.z,.45,delta*.3)
	if water_effects!=null and fmod(sink_clock,1.2)<delta:water_effects.splash(global_position+global_basis.z*2.,.8,true)
	if sink_clock>7.:
		sinking=false;sank.emit()

func set_occupied(value: bool) -> void:
	occupied = value

func toggle_lights() -> void:
	lights_enabled=not lights_enabled
	update_lights()

func update_lights() -> void:
	for light: Light3D in deck_lights:light.visible=lights_enabled
	for material: StandardMaterial3D in lamp_materials:material.emission_enabled=lights_enabled
	if searchlight!=null:searchlight.visible=lights_enabled and searchlight_upgraded

func _build_lights() -> void:
	var steel:=Materials.surface("paint",Color("283b40"),3.,false)
	for side: float in [-1.,1.]:
		var color:=Color("ee473d") if side<0. else Color("5be8a2")
		var glow:=G.material(color);glow.emission_enabled=true;glow.emission=color;glow.emission_energy_multiplier=2.
		lamp_materials.append(glow)
		G.box(_hull,Vector3(side*1.15,2.4,-.5),Vector3(.22,.16,.28),steel)
		G.sphere(_hull,Vector3(side*1.18,2.42,-.64),Vector3(.08,.07,.09),glow,12)
		var nav:=OmniLight3D.new();nav.position=Vector3(side*1.18,2.42,-.65);nav.light_color=color;nav.light_energy=.45;nav.omni_range=2.4;_hull.add_child(nav);deck_lights.append(nav)
	for at: Vector3 in [Vector3(0,3.,.85),Vector3(0,2.9,-1.5)]:
		G.box(_hull,at,Vector3(.48,.15,.23),steel)
		var lens:=G.material(Color("fff0c8"));lens.emission_enabled=true;lens.emission=Color("ffd29a");lens.emission_energy_multiplier=1.6
		lamp_materials.append(lens)
		G.box(_hull,at+Vector3(0,-.09,0),Vector3(.36,.035,.17),lens)
		var lamp:=OmniLight3D.new();lamp.position=at-Vector3.UP*.2;lamp.light_color=Color("ffd69c");lamp.light_energy=2.1;lamp.omni_range=6.;lamp.shadow_enabled=false;_hull.add_child(lamp);deck_lights.append(lamp)
	searchlight=SpotLight3D.new();searchlight.name="UpgradeableBowSearchlight";searchlight.position=Vector3(0,3.2,-1.2);searchlight.rotation.x=-.16;searchlight.spot_range=65.;searchlight.spot_angle=24.;searchlight.spot_attenuation=1.2;searchlight.light_energy=5.;searchlight.light_color=Color("e9f3e9");searchlight.shadow_enabled=true;_hull.add_child(searchlight)
	update_lights()

func seat_position() -> Vector3:
	if hull_model!="tripo" and is_instance_valid(_hull):return _hull.to_global(hull_spec.helm)
	if imported_model!=null: return imported_model.get_node("Helm").global_position
	return _hull.to_global(Vector3(0.0, 0.95, 0.5)) if is_instance_valid(_hull) else to_global(Vector3(0.0,0.95,0.5))

func reset_to_dock() -> void:
	sinking=false;sink_clock=0.;boost=0.;water_aboard=0.
	if is_instance_valid(_hull):_hull.rotation=Vector3.ZERO
	global_position = DOCK_POSITION
	rotation = Vector3.ZERO
	speed = 0.0
	velocity = Vector3.ZERO
	heave_velocity=0.; _hull.position.y=Waves.height_at(global_position)
	if trail!=null: trail.clear_trail()

func _build_visual() -> void:
	if ResourceLoader.exists("res://assets/boats/fishing_boat.glb"):
		_build_external_visual(); return
	_hull = Node3D.new()
	_hull.name = "HandcraftedLaunch"
	add_child(_hull)
	var cream := Materials.surface("paint",Color("d4d9d1"),1.7,false)
	var teal := Materials.surface("paint",Color("21434c"),1.6,false)
	cream.cull_mode = BaseMaterial3D.CULL_DISABLED
	teal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim := _material(Color("d9a15b"))
	var wood := Materials.surface("teak",Color.WHITE,2.0,false)
	var dark := _material(Color("233d42"))
	var metal := _material(Color("9ca9a3"), 0.65)
	var points := PackedVector2Array([
		Vector2(0.0, -2.85), Vector2(-0.72, -2.25), Vector2(-1.10, -1.1),
		Vector2(-1.16, 0.9), Vector2(-1.02, 2.1), Vector2(1.02, 2.1),
		Vector2(1.16, 0.9), Vector2(1.10, -1.1), Vector2(0.72, -2.25)])
	points = _smooth_outline(points)
	_ring_hull(points, 0.78, 0.12, 1.0, 0.83, cream)
	_ring_hull(points, 0.12, -0.33, .83, .40, teal)
	_ring_hull(points, 0.92, 0.72, 1.025, 1.0, teal)
	_ring_hull(points, 0.98, 0.91, 1.04, 1.025, trim)
	_ring_hull(points, 0.90, 0.46, .92, .80, cream)
	_polygon_deck(points, 0.45, 0.84, wood)
	for z_index in range(12):
		var z: float = -1.7 + float(z_index) * 0.31
		_box(_hull, Vector3(1.72, 0.025, 0.018), Vector3(0.0, 0.47, z), dark)
	for bench_z in [-1.35, 0.65, 1.58]:
		_box(_hull, Vector3(1.88, 0.12, 0.33), Vector3(0.0, 0.80, bench_z), trim)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(-0.70, 0.62, bench_z), teal)
		_box(_hull, Vector3(0.10, 0.33, 0.28), Vector3(0.70, 0.62, bench_z), teal)
	var canvas := Materials.surface("fabric",Color("b6c5be"),7.,false)
	_box(_hull,Vector3(.72,.11,.38),Vector3(0,.91,.65),canvas)
	_box(_hull,Vector3(.70,.32,.09),Vector3(0,1.12,.88),canvas)
	# Open bow rails, cleats and ribs follow the hull rather than a rectangular frame.
	for side: float in [-1.,1.]:
		var rail := [Vector3(side*.98,1.06,-.9),Vector3(side*.73,1.16,-1.8),Vector3(side*.27,1.19,-2.5)]
		for i: int in range(rail.size()-1):
			G.beam(_hull,rail[i],rail[i+1],.022,metal)
		for p: Vector3 in rail:
			G.beam(_hull,p-Vector3(0,.23,0),p,.018,metal)
		for z: float in [-.6,.45,1.55]:
			G.beam(_hull,Vector3(side*.84,.48,z),Vector3(side*1.02,.88,z),.035,cream)
		for z: float in [-1.3,1.8]:
			_box(_hull,Vector3(.06,.05,.21),Vector3(side*1.03,1.015,z),metal)
			G.cylinder(_hull,Vector3(side*1.03,.99,z),.025,.08,metal,.025,12)
	# Forward console and windscreen frame, leaving a clear central seat.
	_box(_hull, Vector3(0.75, 0.58, 0.40), Vector3(0.0, 0.76, -0.50), teal)
	_box(_hull, Vector3(0.86, 0.08, 0.54), Vector3(0.0, 1.08, -0.50), wood)
	var windscreen := _material(Color(0.35, 0.66, 0.69, 0.42))
	windscreen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(_hull, Vector3(0.76, 0.33, 0.035), Vector3(0.0, 1.28, -0.72), windscreen)
	for x: float in [-0.42, 0.42]:
		_box(_hull, Vector3(0.045, 0.37, 0.045), Vector3(x, 1.27, -0.72), cream)
	_box(_hull, Vector3(0.90, 0.045, 0.045), Vector3(0.0, 1.46, -0.72), cream)
	helm_wheel=_build_helm_wheel(_hull,Vector3(0.0, 1.16, -0.22),.17,PI*.5)
	for x: float in [-.23,.23]:
		var dial:=G.cylinder(_hull,Vector3(x,1.075,-.275),.063,.02,metal,.063,24)
		dial.rotation.x=PI*.5
		var face:=G.cylinder(_hull,Vector3(x,1.075,-.26),.049,.022,dark,.049,24)
		face.rotation.x=PI*.5
		_box(_hull,Vector3(.005,.036,.005),Vector3(x+.01,1.08,-.24),cream).rotation.z=-.4
	G.beam(_hull,Vector3(.40,.94,-.35),Vector3(.40,1.13,-.22),.012,metal)
	Sculpt.ellipsoid(_hull,Vector3(.40,1.13,-.22),Vector3(.03,.04,.03),dark)
	# Stern motor, rudder and animated propeller.
	_box(_hull, Vector3(0.55, 0.58, 0.51), Vector3(0.0, 0.84, 2.27), dark)
	_box(_hull, Vector3(0.56, 0.12, 0.52), Vector3(0.0, 1.16, 2.27), cream)
	_box(_hull, Vector3(0.12, 0.84, 0.22), Vector3(0.0, 0.20, 2.30), metal)
	_propeller = Node3D.new()
	_propeller.position = Vector3(0.0, -0.10, 2.49)
	_hull.add_child(_propeller)
	_box(_propeller, Vector3(0.60, 0.07, 0.04), Vector3.ZERO, dark)
	_box(_propeller, Vector3(0.07, 0.60, 0.04), Vector3.ZERO, dark)
	# Rope coil, fishing crate and painted bow identifier.
	var coil := MeshInstance3D.new()
	var rope := TorusMesh.new()
	rope.inner_radius = 0.16
	rope.outer_radius = 0.23
	rope.rings = 20
	rope.ring_segments = 6
	coil.mesh = rope
	coil.material_override = trim
	coil.position = Vector3(0.38, 0.87, -1.35)
	_hull.add_child(coil)
	for i: int in range(1,4):
		var loop:=coil.duplicate() as MeshInstance3D
		loop.scale=Vector3.ONE*(1.-float(i)*.18)
		loop.position.y+=float(i)*.012
		_hull.add_child(loop)
	_box(_hull, Vector3(0.50, 0.37, 0.44), Vector3(-0.61, 0.66, 1.15), teal)
	_box(_hull, Vector3(0.54, 0.07, 0.48), Vector3(-0.61, 0.88, 1.15), cream)
	for side: float in [-1.0, 1.0]:
		_box(_hull, Vector3(0.15, 0.30, 0.20), Vector3(side * 1.16, 0.52, 0.15), dark)
		_box(_hull, Vector3(0.15, 0.30, 0.20), Vector3(side * 1.15, 0.52, 1.1), dark)
	var lamp_material := _material(Color("ffd28a"))
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("efb968")
	lamp_material.emission_energy_multiplier = 1.2
	_box(_hull, Vector3(0.11, 0.13, 0.11), Vector3(0.0, 1.12, -2.3), lamp_material)
	var bow_light := OmniLight3D.new()
	bow_light.position = Vector3(0.0, 1.25, -2.3)
	bow_light.light_color = Color("ffd296")
	bow_light.light_energy = 0.6
	bow_light.omni_range = 3.0
	_hull.add_child(bow_light)
	_wake_material=ShaderMaterial.new()
	_wake_material.shader=preload("res://assets/shaders/wake.gdshader")
	_wake_material.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	_foam_left = _make_wake(Vector3(-1.12,0,2.4))
	_foam_right = _make_wake(Vector3(1.12,0,2.4))
	_foam_left.rotation.y = -0.18
	_foam_right.rotation.y = 0.18
	_foam_left.visible = false
	_foam_right.visible = false
	# Fixed fittings share draws in hull space; the whole assembly still rocks.
	preload("res://scripts/world/static_batch.gd").build(_hull,[_propeller])

func _build_external_visual() -> void:
	hydrodynamics=preload("res://data/boats/tripo_fishing_boat.tres").duplicate()
	_hull=Node3D.new(); _hull.name="WaveFollowingHull"; add_child(_hull)
	imported_model=preload("res://scenes/models/fishing_boat_model.tscn").instantiate(); _hull.add_child(imported_model)
	var fittings:=preload("res://scripts/boats/boat_outfitting.gd").new();fittings.name="TeakAndDeckFittings";_hull.add_child(fittings)
	_propeller=Node3D.new(); _hull.add_child(_propeller)
	var metal:=Materials.surface("paint",Color("253e43"),3.,false)
	G.cylinder(_hull,Vector3(0,1.55,.85),.06,.85,metal)
	helm_wheel=_build_helm_wheel(_hull,Vector3(0,1.96,.85),.24,PI*.3)
	_wake_material=ShaderMaterial.new();_wake_material.shader=preload("res://assets/shaders/wake.gdshader")
	_wake_material.set_shader_parameter("foam_tex",load("res://assets/textures/foam_noise.png"))
	_foam_left=_make_wake(Vector3(-1.8,0,3.9));_foam_right=_make_wake(Vector3(1.8,0,3.9))
	_foam_left.rotation.y=-.18;_foam_right.rotation.y=.18
	_bow_left=_make_wake(Vector3(-.9,0,-3.4));_bow_right=_make_wake(Vector3(.9,0,-3.4))
	_bow_left.rotation.y=-.62;_bow_right.rotation.y=.62

func _make_wake(at: Vector3) -> MeshInstance3D:
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(.85,2.4)
	mesh.subdivide_width=4
	mesh.subdivide_depth=12
	var instance:=G.mesh_node(self,mesh,_wake_material,at)
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _build_bucket(parent: Node3D=null,where: Variant=null) -> void:
	if parent==null:parent=_hull
	var at:=Vector3(1.,1.12,2.55) if imported_model!=null else Vector3(-.65,.48,1.4)
	if where!=null:at=where
	var metal:=Materials.surface("paint",Color("9faea3"),2.,false)
	metal.metallic=.55;metal.roughness=.32;metal.cull_mode=BaseMaterial3D.CULL_DISABLED
	var shell:=CylinderMesh.new();shell.top_radius=.26;shell.bottom_radius=.21;shell.height=.43;shell.radial_segments=24;shell.cap_top=false
	G.mesh_node(parent,shell,metal,at+Vector3.UP*.215)
	G.cylinder(parent,at+Vector3.UP*.05,.2,.02,G.material(Color("213f43")),.2,24)
	var rim:=TorusMesh.new();rim.inner_radius=.245;rim.outer_radius=.27;rim.rings=24;rim.ring_segments=8
	G.mesh_node(parent,rim,metal,at+Vector3.UP*.43)
	for side: float in [-1.,1.]:G.beam(parent,at+Vector3(side*.255,.35,0),at+Vector3(side*.2,.7,0),.012,metal)
	G.beam(parent,at+Vector3(-.2,.7,0),at+Vector3(.2,.7,0),.014,metal)
	bucket=Marker3D.new();bucket.position=at+Vector3.UP*.24;parent.add_child(bucket)

func _smooth_outline(control: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var n:=control.size()
	for i: int in n:
		var a:=control[(i+n-1)%n]
		var b:=control[i]
		var c:=control[(i+1)%n]
		var d:=control[(i+2)%n]
		for j: int in range(5):
			var t:=float(j)/5.
			result.append(.5*((2.*b)+(-a+c)*t+(2.*a-5.*b+4.*c-d)*t*t+(-a+3.*b-3.*c+d)*t*t*t))
	return result

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.76
	result.metallic = metallic
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := Sculpt.rounded_box(size,.07)
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result

func _ring_hull(points: PackedVector2Array, upper_y: float, lower_y: float, upper_scale: float, lower_scale: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in range(points.size()):
		var j: int = (i + 1) % points.size()
		var a := Vector3(points[i].x * upper_scale, upper_y, points[i].y)
		var b := Vector3(points[j].x * upper_scale, upper_y, points[j].y)
		var c := Vector3(points[j].x * lower_scale, lower_y, points[j].y * 0.94)
		var d := Vector3(points[i].x * lower_scale, lower_y, points[i].y * 0.94)
		for vertex: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(vertex)
	st.index()
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	_hull.add_child(instance)

func _polygon_deck(points: PackedVector2Array, height: float, deck_scale: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		var j: int = (i + 1) % points.size()
		st.add_vertex(Vector3(0.0, height, 0.0))
		st.add_vertex(Vector3(points[i].x * deck_scale, height, points[i].y * deck_scale))
		st.add_vertex(Vector3(points[j].x * deck_scale, height, points[j].y * deck_scale))
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	_hull.add_child(instance)

## Repaints the hull (main colour and upper works) and resizes it, for the boats sold at the boatyard.
## Same height rule the imported model uses: antifouling stays dark, deck timber stays teak.
## Hull size relative to the Aurora: bigger hulls drift less in the wind, ship less water and roll slower.
var size_factor: float=1.
func set_livery(hull_color: Color,top_color: Color,scale_value: float) -> void:
	livery_hull=hull_color;size_factor=scale_value
	if is_instance_valid(_hull):_hull.scale=Vector3.ONE*scale_value
	# The physical hull grows with the visible one (docks, rocks and the camera meet the real size).
	if _collision_box!=null:_collision_box.size=Vector3(_base_box.x*scale_value,_base_box.y,_base_box.z*scale_value)
	if imported_model==null or not "meshes" in imported_model:return
	for part: MeshInstance3D in imported_model.meshes:
		var box:=part.get_aabb();var height:=box.get_center().y
		if height<.13:continue
		if box.size.y<.025 and height<.19:continue
		if box.size.y>.3 and height<=.36:continue
		var tint:=top_color if height>.36 else hull_color
		if part.name in ["tripo_part_8","tripo_part_11","tripo_part_13","tripo_part_17","tripo_part_18"]:tint=top_color.darkened(.55)
		part.material_override=Materials.surface("paint",tint,3.,false)

## A spoked ship's wheel: rim, hub, eight spokes running out to turned handles. The returned node spins
## about its local Y axis (the shaft) when the rudder moves: one and a half turns lock to lock.
func _build_helm_wheel(parent: Node3D,at: Vector3,radius: float,tilt: float) -> Node3D:
	var mount:=Node3D.new();mount.name="HelmMount";mount.position=at;mount.rotation.x=tilt;parent.add_child(mount)
	var spin:=Node3D.new();spin.name="HelmWheel";mount.add_child(spin)
	var wood:=Materials.surface("teak",Color("8a5a32"),2.)
	var brass:=G.material(Color("b8913f"),.3);brass.metallic=.85
	var rim:=TorusMesh.new();rim.inner_radius=radius-.022;rim.outer_radius=radius+.012;rim.rings=36;rim.ring_segments=8
	G.mesh_node(spin,rim,wood,Vector3.ZERO)
	G.cylinder(spin,Vector3.ZERO,.045,.07,brass,.045,16)
	for i: int in 8:
		var dir:=Vector3(cos(i*TAU/8.),0.,sin(i*TAU/8.))
		G.beam(spin,dir*.03,dir*(radius+.1),.011,wood)
		G.sphere(spin,dir*(radius+.11),Vector3(.022,.022,.022),wood,8)
	G.cylinder(mount,Vector3(0,-.07,0),.02,.1,brass,.02,10)
	return spin

## Swaps the hull class: physical size, mass, deck, helm, anchor roller, lights and visible model.
var _model_seed: int=11
func set_hull_model(model: String,seed_value: int=11) -> void:
	if not HullClasses.SPECS.has(model):model="tripo"
	if model==hull_model and (model=="tripo" or (is_instance_valid(_alt_body) and seed_value==_model_seed)):return
	hull_model=model;_model_seed=seed_value;hull_spec=HullClasses.spec(model)
	if is_instance_valid(_alt_body):_hull.remove_child(_alt_body);_alt_body.queue_free();_alt_body=null
	var tripo:=model=="tripo"
	for part: Node3D in _tripo_parts:part.visible=tripo
	for light: Light3D in _tripo_lights:light.visible=false
	sail_rig=null;sail_speed=0.;sail_heel=0.
	if tripo:
		cabin_node=null
		crew.clear()
		helm_wheel=_tripo_wheel;bucket=_tripo_bucket;_propeller=_tripo_propeller
		deck_lights=_tripo_lights.duplicate();lamp_materials=_tripo_lamps.duplicate()
		hydrodynamics=_tripo_hydro.duplicate()
	else:
		_propeller=_tripo_propeller
		var length: float=float(hull_spec.model_length)
		_alt_body=VesselModels.build(str(hull_spec.kind),length,_model_seed);_alt_body.name="CascoDoJogador";_hull.add_child(_alt_body)
		var wheel: Array=hull_spec.wheel
		if float(wheel[3])<0.:helm_wheel=_build_rabeta(_alt_body,wheel[0])
		else:
			var brass:=G.material(Color("8a6a3a"),.4)
			var deck_y: float=float(hull_spec.deck.y)
			G.cylinder(_alt_body,Vector3(wheel[0].x,(deck_y+wheel[0].y)*.5,wheel[0].z+.12),.07,wheel[0].y-deck_y,brass)
			helm_wheel=_build_helm_wheel(_alt_body,wheel[0],float(wheel[1]),float(wheel[2]))
		_build_bucket(_alt_body,hull_spec.bucket)
		for roof: Dictionary in hull_spec.deck.get("roofs",[]):_build_ladder(_alt_body,roof)
		cabin_node=null
		if hull_spec.has("cabin"):
			cabin_node=preload("res://scripts/boats/cabin_interior.gd").build(_alt_body,hull_spec.cabin,str(hull_spec.kind))
			_build_hatch(_alt_body,hull_spec.cabin.hatch)
		crew.clear()
		var crew_index: int=0
		for c: Dictionary in hull_spec.get("crew",[]):
			var person=preload("res://scripts/boats/crew_member.gd").new();person.look_id=60+crew_index*7;person.role=str(c.role)
			if c.has("a"):person.walk_a=c.a;person.walk_b=c.b;person.position=c.a
			else:person.position=c.at;person.facing=float(c.get("facing",0.))
			person.name="Tripulante_%d"%crew_index;_alt_body.add_child(person);crew.append(person);crew_index+=1
		deck_lights=[];lamp_materials=[]
		var lamp:=OmniLight3D.new();lamp.position=hull_spec.helm+Vector3(0,2.1,-.4);lamp.light_color=Color("ffd69c");lamp.light_energy=1.8;lamp.omni_range=6.;_alt_body.add_child(lamp);deck_lights.append(lamp)
		if float(hull_spec.sails)>0.:
			sail_rig=load("res://scripts/boats/sail_rig.gd").rig(_alt_body);sail_target=1.;sail_rig.hoist=1.
		var h: Resource=_tripo_hydro.duplicate()
		h.mass_kg=hull_spec.mass;h.waterline_length=hull_spec.length;h.beam=hull_spec.beam;h.draft_offset=hull_spec.draft
		h.heave_stiffness=hull_spec.heave;h.angular_response=hull_spec.angular;h.maximum_tilt=hull_spec.tilt
		hydrodynamics=h
	_base_box=Vector3(float(hull_spec.beam),1.,float(hull_spec.length))
	if _collision_box!=null:_collision_box.size=Vector3(_base_box.x*size_factor,_base_box.y,_base_box.z*size_factor)
	if anchor!=null:anchor.roller=Vector3(0,float(hull_spec.deck.y)-.07,-float(hull_spec.length)*.48)
	if searchlight!=null:searchlight.position=Vector3(0,float(hull_spec.deck.y)+(2.1 if tripo else 1.4),-float(hull_spec.length)*(.15 if tripo else .4))
	var half: float=float(hull_spec.beam)*.5;var stern: float=float(hull_spec.length)*.48
	_foam_left.position=Vector3(-half,0,stern);_foam_right.position=Vector3(half,0,stern)
	hull_changed.emit.call_deferred()
	if _bow_left!=null:
		var bow_z: float=-float(hull_spec.length)*.42*size_factor
		_bow_left.position=Vector3(-half*.5,0,bow_z);_bow_right.position=Vector3(half*.5,0,bow_z)
	update_lights()

## The companionway on deck: a raised teak frame round a dark opening with the top of the ladder.
func _build_hatch(parent: Node3D,at: Vector3) -> void:
	var teak:=Materials.surface("teak",Color("8a5a35"),1.2)
	var hole:=G.material(Color("1a120c"),.9)
	var hatch:=Node3D.new();hatch.name="Gaiuta";hatch.position=at;parent.add_child(hatch)
	G.box(hatch,Vector3(0,.012,0),Vector3(.68,.02,.62),hole)
	for side: float in [-1.,1.]:
		G.box(hatch,Vector3(side*.37,.09,0),Vector3(.07,.18,.72),teak)
		G.box(hatch,Vector3(0,.09,side*.34),Vector3(.8,.18,.07),teak)
	for side: float in [-.24,.24]:G.box(hatch,Vector3(side,.0,-.05),Vector3(.04,.04,.5),teak)

## Long-tail outboard ("rabeta") for the canoe: engine on a pivot over the transom, a long shaft
## trailing into the water. Steering swings the whole unit, so the returned pivot is the "wheel".
func _build_rabeta(parent: Node3D,at: Vector3) -> Node3D:
	var pivot:=Node3D.new();pivot.name="Rabeta";pivot.position=at;parent.add_child(pivot)
	var red:=G.material(Color("b23a2e"),.45);var steel:=G.material(Color("8f979b"),.35);steel.metallic=.7
	var black:=G.material(Color("1d2124"),.6)
	G.box(pivot,Vector3(0,.14,-.05),Vector3(.32,.26,.42),red)
	G.box(pivot,Vector3(0,.3,-.05),Vector3(.26,.06,.34),black)
	G.cylinder(pivot,Vector3(0,.0,0),.05,.16,steel)
	G.beam(pivot,Vector3(0,.05,.1),Vector3(0,-.8,1.75),.035,steel)
	G.beam(pivot,Vector3(0,.18,-.25),Vector3(0,.42,-.95),.028,black)
	_propeller=Node3D.new();_propeller.position=Vector3(0,-.84,1.8);pivot.add_child(_propeller)
	for i: int in 3:
		var blade:=G.box(_propeller,Vector3.ZERO,Vector3(.24,.035,.06),steel);blade.rotation.z=i*TAU/3.
	return pivot

func has_sails() -> bool:
	return sail_rig!=null

## Cycles furled → reefed → full sail. Returns the new setting for the HUD.
func cycle_sails() -> String:
	if sail_rig==null:return ""
	sail_target={0.:.5,.5:1.}.get(sail_target,0.)
	return {0.:"Velas recolhidas.",.5:"Velas rizadas (meia vela).",1.:"Velas cheias."}[sail_target]

func _update_sails(delta: float) -> void:
	if sail_rig==null:sail_speed=0.;sail_heel=0.;return
	var wind_world:=Vector3(Waves.direction.x,0.,Waves.direction.y)
	var local_wind:=global_basis.inverse()*wind_world
	var strength: float=Waves.wind
	var target: float=sail_target
	if anchor!=null and anchor.deployed():target=0.
	sail_rig.update(delta,local_wind,strength,target)
	var aw: Vector2=sail_rig.wind_angle(local_wind)
	var wind_ms: float=2.5+strength*13.
	var exposure: float=Waves.exposure(Vector2(global_position.x,global_position.z))
	var force: float=sail_rig.drive(aw.x)*sail_rig.hoist*(.6+.4*exposure)
	sail_speed=force*wind_ms*float(hull_spec.sails)
	# The wind on the cloth heels the hull to leeward; carrying full sail in a gale strains it.
	sail_heel=lerpf(sail_heel,aw.y*force*pow(strength,1.3)*.55,1.-exp(-delta*1.5))
	_overcanvas_clock=maxf(0.,_overcanvas_clock-delta)
	if strength>.72 and sail_rig.hoist>.6 and force>.3:
		integrity=maxf(.2,integrity-delta*.004)
		if _overcanvas_clock<=0.:warning.emit("Vento forte demais para vela cheia! P para rizar.");_overcanvas_clock=10.

func deck_layout() -> Dictionary:
	return hull_spec.deck

## Where a swimmer ends up when stepping off the side.
func exit_point() -> Vector3:
	return _hull.to_global(Vector3(-(float(hull_spec.beam)*.5+.9/size_factor),.2,float(hull_spec.length)*.2/size_factor))

func board_radius() -> float:
	return maxf(6.,float(hull_spec.length)*.5*size_factor)

## Point of sail for the HUD: how the boat lies to the wind right now.
func point_of_sail() -> String:
	if sail_rig==null:return ""
	if sail_target<=0.:return "recolhidas"
	var angle: float=rad_to_deg(sail_rig.wind_angle(global_basis.inverse()*Vector3(Waves.direction.x,0.,Waves.direction.y)).x)
	if angle<38.:return "panejando (contra o vento)"
	if angle<65.:return "bolina"
	if angle<115.:return "través"
	if angle<155.:return "largo"
	return "popa"

## Wooden ladder from the deck up the cabin side to its roof (hull_classes roofs).
func _build_ladder(parent: Node3D,roof: Dictionary) -> void:
	var wood:=Materials.surface("teak",Color("7a5532"),2.)
	var foot: Vector3=roof.ladder;var top: Vector3=roof.top
	# The ladder leans on the cabin face, between the foot and the roof edge.
	var edge:=Vector3(foot.x,float(roof.y)+.35,lerpf(foot.z,top.z,.35))
	for side: float in [-.2,.2]:G.beam(parent,foot+Vector3(side,0,0),edge+Vector3(side,0,0),.025,wood)
	var steps:=int((edge.y-foot.y)/.3)
	for i: int in range(1,steps+1):
		var t:=float(i)/float(steps+1)
		var at:=foot.lerp(edge,t)
		G.beam(parent,at+Vector3(-.2,0,0),at+Vector3(.2,0,0),.02,wood)

## Deck winch (bought at the shipyard for hulls that can carry one): a drum with cable that turns while
## traps or the set net are hauled.
var winch: Node3D
var _winch_drum: Node3D
var _winch_turning: bool=false
func set_winch(on: bool) -> void:
	if is_instance_valid(winch):winch.queue_free();winch=null
	if not on or not hull_spec.has("winch"):return
	var steel:=G.material(Color("2f5a6b"),.4);steel.metallic=.5;var cable:=G.material(Color("8a8f8f"),.5)
	winch=Node3D.new();winch.name="Guincho";winch.position=hull_spec.winch;_hull.add_child(winch)
	G.box(winch,Vector3(0,.12,0),Vector3(.7,.24,.5),steel)
	for x: float in [-.32,.32]:G.box(winch,Vector3(x,.42,0),Vector3(.06,.5,.4),steel)
	_winch_drum=Node3D.new();_winch_drum.position=Vector3(0,.5,0);winch.add_child(_winch_drum)
	G.cylinder(_winch_drum,Vector3.ZERO,.16,.56,cable,.16,16).rotation.z=PI*.5
	for x: float in [-.27,.27]:G.cylinder(_winch_drum,Vector3(x,0,0),.24,.04,steel,.24,16).rotation.z=PI*.5
	G.box(_winch_drum,Vector3(0,.17,0),Vector3(.5,.02,.04),steel)
func set_winch_turning(value: bool) -> void:
	_winch_turning=value
func _process(delta: float) -> void:
	if _winch_turning and is_instance_valid(_winch_drum):_winch_drum.rotation.x+=delta*6.

## Hull in the waves: the hull floats on buoyancy sampled at nine points over its waterline (bow, middle and
## stern; port, centreline and starboard), each pushing up in proportion to how deep that part of the hull is in the water,
## with nothing where it is clear of the water (so a hull can briefly leave a steep crest). The forces and
## their moments drive heave, pitch and roll with the hull's mass and inertia, plus damping and quadratic
## resistance. Wind on sails and turning add heeling moments. Small light hulls answer short waves sharply;
## long heavy ones average them out and move slowly. Several sub-steps per frame keep it stable.
func _simulate_hull(delta: float) -> void:
	var L: float=float(hydrodynamics.waterline_length)*size_factor
	var B: float=float(hydrodynamics.beam)*size_factor
	var m: float=float(hydrodynamics.mass_kg)*pow(size_factor,3.)
	var immersion: float=float(hull_spec.get("immersion",.35))*size_factor
	var draft: float=float(hydrodynamics.draft_offset)
	var g: float=9.8
	var k_total: float=m*g/immersion
	var k: float=k_total/9.
	var xs: Array[float]=[-B*.42,0.,B*.42];var zs: Array[float]=[-L*.45,0.,L*.45]
	var right: Vector3=global_basis.x;var back: Vector3=global_basis.z
	var heights: Array[float]=[]
	for z: float in zs:
		for x: float in xs:heights.append(Waves.height_at(global_position+right*x+back*z))
	var kp: float=k*6.*pow(L*.45,2.);var kr: float=k*6.*pow(B*.42,2.)
	# Natural periods grow with size (topsides, rig and cargo add inertia): a canoe snaps back in about a
	# second and a half, a schooner rolls over three and a half.
	var t_pitch: float=.9+L*.06;var t_roll: float=1.2+B*.45
	var ip: float=kp/pow(TAU/t_pitch,2.);var ir: float=kr/pow(TAU/t_roll,2.)
	var cp: float=2.*.5*sqrt(kp*ip);var cr: float=2.*.6*sqrt(kr*ir);var ch: float=2.*.42*sqrt(k_total*m)
	# Heeling moments: sail pressure, leaning out of a turn, trim by the stern at speed, the last blow.
	kick_roll=move_toward(kick_roll,0.,delta*.35)
	var heel: float=sail_heel-yaw_rate*wake_strength*.11
	var trim: float=wake_strength*.03
	# Chop: the local slope of the short waves right under the hull. A narrow light hull sits on it and is
	# knocked about by every wavelet; a broad heavy one spans it and hardly notices.
	var chop_gain: float=clampf(1.25-B*.32,.04,1.)
	var here: Vector3=global_position
	heel+=(Waves.height_at(here+right*.5)-Waves.height_at(here-right*.5))*chop_gain
	trim+=(Waves.height_at(here-back*.5)-Waves.height_at(here+back*.5))*chop_gain*.5
	var max_tilt: float=float(hydrodynamics.maximum_tilt)*1.5
	# Water aboard: extra weight, and it runs to the low side (free surface), so she rolls further.
	var m_eff: float=m+water_aboard
	heel+=water_fraction()*sin(_hull.rotation.z)*1.4
	var steps:=4;var dt: float=delta/float(steps)
	var bow_depth:=0.
	for step: int in steps:
		var y: float=_hull.position.y;var pitch: float=_hull.rotation.x;var roll: float=_hull.rotation.z
		var force:=0.;var tp:=0.;var tr:=0.
		var n:=0
		for z: float in zs:
			for x: float in xs:
				var hull_y: float=y+(-z)*sin(pitch)+x*sin(roll)
				var depth: float=heights[n]-hull_y-draft+immersion
				# Below the waterline buoyancy grows with depth; a part lifted clear still feels the water's
				# pull (added mass and the falling wave) for a little, then nothing: the hull can leave a crest.
				var f: float=k*clampf(depth,-immersion*.6,immersion*2.6)
				force+=f;tp+=f*(-z)*cos(pitch);tr+=f*x*cos(roll)
				if z<0. and x==0.:bow_depth=depth
				n+=1
		var drag: float=heave_velocity*absf(heave_velocity)*m_eff*.35
		heave_velocity+=(force-m_eff*g-ch*heave_velocity-drag)/m_eff*dt
		pitch_rate+=(tp+kp*trim-cp*pitch_rate)/ip*dt
		roll_rate+=(tr+kr*heel-cr*roll_rate)/ir*dt
		_hull.position.y+=heave_velocity*dt
		_hull.rotation.x+=pitch_rate*dt
		_hull.rotation.z+=roll_rate*dt
		# Hard limits for play: past them the motion is stopped, never flipped.
		if absf(_hull.rotation.x)>max_tilt:_hull.rotation.x=signf(_hull.rotation.x)*max_tilt;pitch_rate*=-.2
		if absf(_hull.rotation.z)>max_tilt:_hull.rotation.z=signf(_hull.rotation.z)*max_tilt;roll_rate*=-.2
	_ship_water(delta,heights,xs,zs,m)
	var mean: float=0.
	for h: float in heights:mean+=h
	mean/=9.
	_hull.position.y=clampf(_hull.position.y,mean-draft-2.5*immersion-1.,mean-draft+1.5)
	_bow_slam=maxf(0.,(bow_depth-_bow_prev)/maxf(delta,.001));_bow_prev=bow_depth
	# A beam sea and wind push the bow off: the helmsman has to keep correcting in rough weather.
	if occupied and not (anchor!=null and anchor.deployed()):
		var yaw_push: float=((heights[2]-heights[0])-(heights[8]-heights[6]))*.06/sqrt(maxf(m/4200.,.1))
		var local_wind: Vector3=global_basis.inverse()*Vector3(Waves.direction.x,0.,Waves.direction.y)
		yaw_push-=local_wind.x*pow(Waves.wind,2.)*.05/sqrt(maxf(m/4200.,.1))*Waves.exposure(Vector2(global_position.x,global_position.z))
		rotation.y+=yaw_push*delta
