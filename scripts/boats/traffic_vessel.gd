extends CharacterBody3D
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
var route: Array[Vector3]=[]
var waypoint: int=0
var length_m: float=12.
var cruise_speed: float=4.
var asset_path: String="res://assets/boats/fishing_boat.glb"
var player_boat: Node3D
var speed: float=0.
var hull: Node3D
var trail: MeshInstance3D
var waiting_for_player: bool=false
var yield_side: float=1.
func _ready() -> void:
	collision_layer=1;collision_mask=3;motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(length_m*.28,2.,length_m*.9);collision.shape=box;collision.position.y=.2;add_child(collision)
	hull=Node3D.new();add_child(hull)
	var model:=preload("res://scripts/assets/external_model.gd").new();model.asset_path=asset_path;model.length_m=length_m;model.waterline_m=length_m*.08;model.material_family="boat";hull.add_child(model)
	for side: float in [-1.,1.]:
		var color:=Color("ef553e") if side<0. else Color("5ee5a5")
		var material:=G.material(color);material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=2.
		G.sphere(hull,Vector3(side*length_m*.13,length_m*.20,-length_m*.1),Vector3.ONE*.10,material,12)
	var lamp:=OmniLight3D.new();lamp.position=Vector3(0,length_m*.2,0);lamp.omni_range=length_m*.45;lamp.light_energy=1.8;lamp.light_color=Color("ffd8a0");hull.add_child(lamp)
	trail=preload("res://scripts/ocean/wake_trail.gd").new();trail.stern_offset=length_m*.46;trail.half_width=length_m*.16;add_child(trail)
	if route.size()>1:
		position=route[waypoint];waypoint=(waypoint+1)%route.size();look_at(Vector3(route[waypoint].x,position.y,route[waypoint].z))
func _physics_process(delta: float) -> void:
	if route.size()<2:return
	var to: Vector3=route[waypoint]-position;to.y=0.
	if to.length()<maxf(25.,length_m):waypoint=(waypoint+1)%route.size();to=route[waypoint]-position;to.y=0.
	var desired:=to.normalized();var was_yielding:=waiting_for_player;waiting_for_player=false
	var clearance_velocity:=Vector3.ZERO;var yield_speed:=0.
	if is_instance_valid(player_boat):
		var separation:=position-player_boat.position;separation.y=0.
		if separation.length()<length_m+85.:
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
	if coast.x<length_m:desired=Vector3(coast.y,0,coast.z)
	rotation.y=lerp_angle(rotation.y,atan2(-desired.x,-desired.z),delta*.35)
	var safe:=Layout.coast(Vector2(position.x,position.z)).x>length_m*.5
	var target_speed:=yield_speed if waiting_for_player else cruise_speed*(.7 if Waves.wind>.75 else 1.)
	speed=move_toward(speed,target_speed if safe else 0.,delta*1.8)
	velocity=-basis.z*speed+clearance_velocity;velocity.y=0.;move_and_slide();position.y=0.
	if get_slide_collision_count()>0:speed=0.
	var front:=Waves.height_at(position-basis.z*length_m*.35);var rear:=Waves.height_at(position+basis.z*length_m*.35)
	var left:=Waves.height_at(position-basis.x*length_m*.14);var right:=Waves.height_at(position+basis.x*length_m*.14)
	hull.position.y=lerpf(hull.position.y,(front+rear+left+right)*.25,1.-exp(-delta*2.))
	hull.rotation.x=lerpf(hull.rotation.x,atan((front-rear)/(length_m*.7)),delta*2.)
	hull.rotation.z=lerpf(hull.rotation.z,atan((right-left)/(length_m*.28)),delta*2.)
	var camera:=get_viewport().get_camera_3d()
	if camera!=null and camera.global_position.distance_squared_to(position)<490000.:trail.advance(position,basis,speed,delta)
	else:trail.clear_trail()
