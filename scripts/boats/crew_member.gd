extends Node3D
## One person aboard a vessel, parented to the moving hull so they ride the waves with it.
## Roles: helm (seated at the wheel), deckhand (walks the deck and stops to work), fisher (rod over the
## rail), passenger (looks out to sea, turns now and then), rower (seated, pulls the oars).
## Only animated while the camera is close; far away the person is hidden and costs nothing.
const RANGE: float=150.
var role: String="passenger"
var look_id: int=0
## Deck walkway endpoints (hull space) for deckhands.
var walk_a: Vector3=Vector3.ZERO
var walk_b: Vector3=Vector3.ZERO
var facing: float=0.
## Set by the vessel: true while it is stopped on a fishing ground (deckhands then haul nets).
var vessel_fishing: bool=false
var visual: Node3D
var _target: Vector3
var _wait: float=0.
var _turn_clock: float=0.
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=look_id*7919+int(absf(position.z)*13.)
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	visual.apply_look(preload("res://scripts/world/npc_look.gd").for_id(look_id))
	visual.seated=role in ["helm","rower"] or has_meta("on_seat")
	# Passengers lean on the rail; deckhands haul when the boat is fishing; helm and rower sit at the wheel or oars.
	visual.idle_clip=["ual/Rail","ual/IdleLook","ual/FoldArms"][look_id%3] if role=="passenger" else "ual/Idle"
	visual.seated_clip={"helm":"ual/Drive","rower":"ual/Row"}.get(role,"ual/Sit")
	# Sailors do not carry the survivalist backpack.
	if visual.backpack!=null:visual.backpack.visible=false
	rotation.y=facing;_target=walk_b;_wait=_rng.randf_range(0.,3.)

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var near:=camera!=null and camera.global_position.distance_squared_to(global_position)<RANGE*RANGE
	visual.visible=near
	if not near:return
	var moving:=0.
	match role:
		"deckhand":
			_wait=maxf(0.,_wait-delta)
			if _wait<=0.:
				var to:=_target-position;to.y=0.
				if to.length()<.2:
					_target=walk_a if _target.distance_to(walk_b)<.01 else walk_b
					_wait=_rng.randf_range(2.,6.)
				else:
					var step:=minf(1.05*delta,to.length())
					position+=to.normalized()*step;moving=1.05
					rotation.y=lerp_angle(rotation.y,atan2(-to.x,-to.z),1.-exp(-delta*6.))
		"passenger":
			_turn_clock-=delta
			if _turn_clock<=0.:_turn_clock=_rng.randf_range(4.,10.);_target=Vector3(0,_rng.randf_range(-1.2,1.2),0)
			rotation.y=lerp_angle(rotation.y,facing+_target.y,1.-exp(-delta*1.2))
	visual.work_clip="ual/FishReel" if role=="deckhand" and vessel_fishing else ""
	visual.update_animation(moving,role=="fisher",delta)
