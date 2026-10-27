extends CharacterBody3D

const Visual = preload("res://scripts/player/angler_visual.gd")
var visual: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var controls_enabled: bool = true
var movement_locked: bool = false
var flying: bool = false
var in_boat: bool = false
var first_person: bool = false
var yaw: float = 0.0
var pitch: float = -0.22
var walk_speed: float = 4.4
var animation_time: float = 0.0
var on_deck: bool=false
var deck_boat: CharacterBody3D
var deck_local:=Vector3(0,1.12,2.4)
var swimming: bool=false
var holding_fish: bool=false
var fishing_active: bool=false
var fishing_state: int=0
var cast_power: float=0.
var jump_buffer: float=0.
var coyote_time: float=0.
var deck_jump: float=0.
var deck_vertical_speed: float=0.
var airborne: bool=false
var is_sprinting: bool=false
var deck_velocity:=Vector3.ZERO
var deck_sway:=Vector3.ZERO
var prev_boat_speed: float=0.
var lean:=Vector2.ZERO
var previous_yaw: float=0.
var was_airborne: bool=false
## Holding Ctrl walks slowly (and dives while swimming).
var is_walking: bool=false
## After a hard landing the legs need a moment: speed is reduced until this runs out.
var land_recovery: float=0.
## Climbing a ledge (pier edge, boat side, wall up to chest height): start, top, end and clock.
var climbing: bool=false
var climb_from:=Vector3.ZERO
var climb_top:=Vector3.ZERO
var climb_to:=Vector3.ZERO
var climb_clock: float=0.
## Seconds spent under water while diving; past BREATH the swimmer is pulled back up.
var dive_time: float=0.
var diving: bool=false
## Seconds of air (set by diving.gd from the diving gear).
var breath: float=30.
const WALK_SPEED: float=1.9
const STEP_HEIGHT: float=.42
const CLIMB_TIME: float=.55
const JUMP_SPEED: float=7.2
## Ground control: linear ramps feel crisper than the old exponential tail. Metres per second squared.
const GROUND_ACCEL: float=28.
const SPRINT_ACCEL: float=24.
const GROUND_DECEL: float=26.
const WATER_ACCEL: float=12.
const WATER_DECEL: float=9.
const AIR_ACCEL: float=10.
## Rising keeps the authored 20 m/s2 (jump height is part of the contract); falling is firmer.
const RISE_GRAVITY: float=20.
const FALL_GRAVITY: float=30.
const TERMINAL_FALL: float=-32.
const BASE_FOV: float=68.0
signal fell_into_water

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	floor_constant_speed = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	visual = preload("res://scripts/player/imported_angler.gd").new() if ResourceLoader.exists("res://assets/characters/survivalist_rigged.glb") else Visual.new()
	add_child(visual)
	pivot = Node3D.new()
	pivot.position.y = 1.65
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 6.8
	arm.margin = 0.2
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 2200.0
	arm.add_child(camera)
	camera.current = true
	_update_camera(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0023, -1.15, 0.45)
	if event.is_action_pressed("camera_toggle"):
		first_person = not first_person
	if event.is_action_pressed("jump") and not movement_locked:
		jump_buffer=.16

func _physics_process(delta: float) -> void:
	jump_buffer=maxf(0.,jump_buffer-delta)
	is_sprinting=false
	if controls_enabled:
		yaw += Input.get_axis("look_right", "look_left") * delta * 1.5
	if flying:
		var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled and not movement_locked else Vector2.ZERO
		var vertical := Input.get_axis("fly_down", "jump") if controls_enabled and not movement_locked else 0.0
		var direction := Basis(Vector3.UP, yaw) * Vector3(axis.x, vertical, axis.y)
		var fly_speed := 90.0 if Input.is_action_pressed("sprint") else 24.0
		velocity = direction.limit_length() * fly_speed
		global_position += velocity * delta
		global_position.y = clampf(global_position.y, 1.0, 600.0)
		swimming = false; airborne = false; jump_buffer = 0.
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1.-exp(-delta*8.))
	elif on_deck and is_instance_valid(deck_boat):
		var axis:=Input.get_vector("move_left","move_right","move_forward","move_back") if controls_enabled and not movement_locked else Vector2.ZERO
		var direction:=Basis(Vector3.UP,yaw-deck_boat.rotation.y)*Vector3(axis.x,0,axis.y)
		is_sprinting=Input.is_action_pressed("sprint") and axis.length()>.1 and not fishing_active
		var deck_speed:=2.3*(1.7 if is_sprinting else 1.)
		deck_velocity=deck_velocity.lerp(direction*deck_speed,1.-exp(-delta*8.))
		deck_local+=deck_velocity*delta
		deck_local.x=clampf(deck_local.x,-1.4,1.4);deck_local.z=clampf(deck_local.z,-3.3,3.1);deck_local.y=1.12
		# The wheelhouse is a visible obstacle; side decks remain open around it.
		if absf(deck_local.x)<1.13 and deck_local.z> -1.65 and deck_local.z<.9:
			if deck_local.z>.45: deck_local.z=.9
			elif deck_local.z< -1.2: deck_local.z=-1.65
			else: deck_local.x=signf(deck_local.x if absf(deck_local.x)>.01 else direction.x)*1.13
		if jump_buffer>0. and deck_jump<=.001:
			deck_vertical_speed=JUMP_SPEED;jump_buffer=0.
		deck_vertical_speed-=20.*delta
		deck_jump=maxf(0.,deck_jump+deck_vertical_speed*delta)
		if deck_jump<=0.:deck_vertical_speed=0.
		airborne=deck_jump>.01
		# A small local sway sells the boat's acceleration without separating the player from the deck.
		var boat_speed: float=float(deck_boat.get("speed"))
		var boat_accel: float=(boat_speed-prev_boat_speed)/maxf(delta,.0001)
		prev_boat_speed=boat_speed
		deck_sway=deck_sway.lerp(Vector3(0.,0.,clampf(boat_accel*.07,-.25,.25)),1.-exp(-delta*4.))
		global_position=deck_boat._hull.to_global(deck_local+Vector3.UP*deck_jump+deck_sway)
		if axis.length()>.1: visual.rotation.y=lerp_angle(visual.rotation.y,yaw+atan2(-axis.x,-axis.y),1.-exp(-delta*8.))
		velocity=deck_velocity
	elif climbing:
		_climb(delta)
	elif not in_boat:
		deck_velocity=Vector3.ZERO
		deck_sway=Vector3.ZERO
		var axis := Vector2.ZERO
		if controls_enabled and not movement_locked:
			axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
		var water: float=preload("res://scripts/world/wave_field.gd").height_at(global_position)
		swimming=global_position.y<water-.35 and not is_on_floor()
		is_sprinting=Input.is_action_pressed("sprint") and axis.length()>.1 and not fishing_active
		is_walking=controls_enabled and Input.is_action_pressed("fly_down") and not swimming
		if is_walking:is_sprinting=false
		var speed_now := (2.2 if swimming else walk_speed) * (1.65 if is_sprinting else 1.0)
		if swimming and is_sprinting:speed_now=3.3
		if is_walking:speed_now=WALK_SPEED
		if fishing_active:speed_now=minf(speed_now,2.6)
		land_recovery=maxf(0.,land_recovery-delta)
		if land_recovery>0.:speed_now*=.35
		var wanted:=Vector3(direction.x,0.,direction.z)*speed_now
		var horizontal:=Vector3(velocity.x,0.,velocity.z)
		var rate:=AIR_ACCEL
		if is_on_floor() or swimming:
			if direction.length()>.01: rate=WATER_ACCEL if swimming else (SPRINT_ACCEL if is_sprinting else GROUND_ACCEL)
			else: rate=WATER_DECEL if swimming else GROUND_DECEL
		horizontal=horizontal.move_toward(wanted,rate*delta)
		velocity.x=horizontal.x
		velocity.z=horizontal.z
		coyote_time=.12 if is_on_floor() else maxf(0.,coyote_time-delta)
		if jump_buffer>0. and coyote_time>0. and not swimming and not movement_locked:
			velocity.y=JUMP_SPEED;jump_buffer=0.;coyote_time=0.
		elif swimming:
			# Ctrl dives, Space swims up; otherwise the swimmer floats back to the surface.
			var want_dive:=controls_enabled and Input.is_action_pressed("fly_down") and dive_time<breath
			var want_up:=controls_enabled and Input.is_action_pressed("jump")
			if want_dive:velocity.y=move_toward(velocity.y,-2.2,6.*delta)
			elif want_up or not diving or dive_time>=breath:velocity.y=clampf((water-.7-global_position.y)*5.,-3.,3. if not diving else 2.4)
			else:velocity.y=move_toward(velocity.y,.35,3.*delta)
			diving=global_position.y<water-1.6
			dive_time=dive_time+delta if diving else maxf(0.,dive_time-delta*4.)
		elif not is_on_floor():
			velocity.y=maxf(velocity.y-(FALL_GRAVITY if velocity.y<0. else RISE_GRAVITY)*delta,TERMINAL_FALL)
		else:
			velocity.y = -0.1
		var fall_speed:=velocity.y
		var before:=global_position
		move_and_slide()
		if not swimming:diving=false
		if direction.length()>.1 and not movement_locked:
			if is_on_floor() and is_on_wall():_step_up(before,wanted*delta)
			if (swimming or airborne or jump_buffer>0.) and is_on_wall():_try_climb(direction)
		airborne=not is_on_floor() and not swimming
		if was_airborne and not airborne and fall_speed<-4.5:
			camera.position.y=-clampf(-fall_speed*.022,.05,.24)
			if fall_speed<-13.:land_recovery=.35
		if direction.length() > 0.1:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.-exp(-delta*9.))
		if global_position.y < -25.0:
			fell_into_water.emit()
	visual.holding_fish=holding_fish
	if fishing_active and (not in_boat or on_deck):visual.rotation.y=lerp_angle(visual.rotation.y,yaw,minf(delta*9.,1.))
	if "swimming" in visual:visual.swimming=swimming
	if "airborne" in visual:
		visual.airborne=airborne;visual.vertical_speed=deck_vertical_speed if on_deck else velocity.y
		visual.fishing_state=fishing_state;visual.cast_power=cast_power
	visual.update_animation(Vector2(velocity.x, velocity.z).length() if (not in_boat or on_deck) and not flying else 0.0, fishing_active, delta)
	var planar_speed:=Vector2(velocity.x,velocity.z).length()
	var turn_rate:=angle_difference(previous_yaw,visual.rotation.y)/maxf(delta,.0001)
	previous_yaw=visual.rotation.y
	var lean_target:=Vector2.ZERO
	if not swimming and not airborne and not flying and (not in_boat or on_deck):
		lean_target=Vector2(clampf(planar_speed/7.,0.,1.)*.13,clampf(turn_rate*.03,-.14,.14)*clampf(planar_speed/3.,0.,1.))
	lean=lean.lerp(lean_target,1.-exp(-delta*7.))
	was_airborne=airborne
	if swimming:
		visual._rod.visible=false
		visual.rotation.x=-.55
		visual.rotation.z=0.
	else:
		visual.rotation.x=-lean.x
		visual.rotation.z=lean.y
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	camera.position.y=move_toward(camera.position.y,0.,delta*(.3+absf(camera.position.y)*7.))
	camera.fov=lerpf(camera.fov,BASE_FOV+(6. if is_sprinting and not first_person and not flying else 0.),minf(delta*5.,1.))
	# Orbit distance can otherwise push a third-person camera under the water.
	if not first_person:
		pitch = minf(pitch, 0.15)
	pivot.rotation = Vector3(pitch, yaw, 0)
	pivot.position.y = lerpf(pivot.position.y, 1.65 if not in_boat else 2.0, minf(delta * 8.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, 0.0 if first_person else (10.5 if in_boat else 6.8), minf(delta * 10.0, 1.0))
	# Over-the-shoulder framing on foot keeps the path ahead visible; centred in the boat and in first person.
	arm.position.x=lerpf(arm.position.x,.55 if not first_person and not in_boat and not flying else 0.,minf(delta*4.,1.))
	visual.visible = not first_person

## Small ledges (steps, curbs, a plank on the pier) are walked over instead of stopping the player.
func _step_up(before: Vector3,motion: Vector3) -> void:
	if motion.length()<.001:return
	var start:=Transform3D(global_basis,before)
	if test_move(start,Vector3.UP*STEP_HEIGHT):return
	var raised:=start.translated(Vector3.UP*STEP_HEIGHT)
	var ahead:=Vector3(motion.x,0,motion.z).normalized()*maxf(motion.length(),.12)
	if test_move(raised,ahead):return
	var moved:=raised.translated(ahead)
	var hit:=KinematicCollision3D.new()
	if test_move(moved,Vector3.DOWN*(STEP_HEIGHT+.05),hit) and hit.get_normal().y>.7:
		global_position=moved.origin+hit.get_travel()
		velocity.y=0.

## Climbs onto a ledge in front: pier and boat edges from the water, walls up to chest height on land.
func _try_climb(direction: Vector3) -> void:
	var forward:=Vector3(direction.x,0,direction.z).normalized()
	var reach:=2.1 if swimming else 1.7
	var space:=get_world_3d().direct_space_state
	for h: float in [.6,.9,1.2,1.5,1.8,2.1]:
		if h>reach:break
		var probe:=global_position+forward*.65+Vector3.UP*(h+.3)
		var q:=PhysicsRayQueryParameters3D.create(probe,probe+Vector3.DOWN*.6,collision_mask,[get_rid()])
		var hit:=space.intersect_ray(q)
		if hit.is_empty() or (hit.normal as Vector3).y<.75 or hit.collider is CharacterBody3D:continue
		var top: Vector3=hit.position
		if top.y-global_position.y<.45:return
		var stand:=Transform3D(global_basis,top+Vector3.UP*.05)
		if test_move(stand,Vector3.UP*.1):continue
		climbing=true;climb_clock=0.;climb_from=global_position
		climb_top=Vector3(global_position.x,top.y+.05,global_position.z);climb_to=top+Vector3.UP*.05
		velocity=Vector3.ZERO;swimming=false;diving=false;jump_buffer=0.
		visual.rotation.y=atan2(-forward.x,-forward.z)
		return

func _climb(delta: float) -> void:
	climb_clock+=delta
	var t:=clampf(climb_clock/CLIMB_TIME,0.,1.)
	# Up first, then over the edge.
	var up:=smoothstep(0.,.6,t);var over:=smoothstep(.45,1.,t)
	global_position=climb_from.lerp(climb_top,up).lerp(climb_to,over)
	airborne=true;velocity=Vector3.ZERO
	if t>=1.:climbing=false;airborne=false;land_recovery=.1

func set_flying(value: bool) -> void:
	flying = value
	collision_layer = 0 if value else 4
	collision_mask = 0 if value else 1
	arm.collision_mask = 0 if value else 1
	velocity = Vector3.ZERO
	is_sprinting=false
	deck_velocity=Vector3.ZERO
	deck_sway=Vector3.ZERO
	jump_buffer = 0.
	coyote_time = 0.

func set_boating(value: bool) -> void:
	in_boat = value
	deck_jump=0.;deck_vertical_speed=0.;airborne=false;jump_buffer=0.
	deck_velocity=Vector3.ZERO;deck_sway=Vector3.ZERO;prev_boat_speed=0.;lean=Vector2.ZERO;was_airborne=false
	on_deck=false;swimming=false
	collision_layer = 0 if value else 4
	collision_mask = 0 if value else 1
	velocity = Vector3.ZERO
	# Imported animation maps this legacy flag to standing at the helm.
	visual.set("seated",value)

func rod_tip() -> Vector3:
	if first_person:
		return camera.global_position + camera.global_basis * Vector3(0.35, -0.25, -1.0)
	return visual.rod_tip()

func keep_camera_above_water() -> void:
	if not in_boat: return
	var sea=preload("res://scripts/world/wave_field.gd")
	var water: float=sea.height_at(camera.global_position)
	var deficit:=water+.3-camera.global_position.y
	if deficit>0.: camera.global_position.y+=deficit
