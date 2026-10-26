extends Node3D
const Layout=preload("res://scripts/world/archipelago_layout.gd")
## Distance at which two residents count as talking.
const TALK_RANGE: float=2.6
var route: Array[Vector3]=[]
var target_index: int=0
var speed: float=1.15
var follow_terrain: bool=true
var visual: Node3D
var wait: float=0.
var velocity:=Vector3.ZERO
var visits: int=0
var ground_sampler: Callable
## Index into NpcLook so every person looks different; -1 keeps the default survivalist.
var look_id: int=-1
## Conversation state: while talk_timer > 0 the resident stands still and faces talk_partner.
var talk_partner: Node3D
var talk_timer: float=0.
var talk_text: String=""
## Set by the village social director: walk over to this resident for a chat.
var meet_with: Node3D
var meet_timer: float=0.
var bubble: Label3D
## Workers and shopkeepers leave the survivalist backpack at home.
var hide_backpack: bool=false
## Animation choices (UAL clips): standing pose, work loop played while not walking (empty: none).
var idle_pose: String=""
var work_pose: String=""
## When set (not INF), the direction (yaw) the resident turns to whenever it stands still: a shopkeeper faces the door.
var rest_yaw: float=INF
func _ready() -> void:
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	if look_id>=0:visual.apply_look(preload("res://scripts/world/npc_look.gd").for_id(look_id))
	if hide_backpack and visual.get("backpack")!=null:visual.backpack.visible=false
	# Everyone stands a little differently; workers and shopkeepers get their own loop.
	visual.idle_clip=idle_pose if not idle_pose.is_empty() else ["ual/Idle","ual/IdleLook","ual/FoldArms","ual/Idle"][absi(look_id)%4]
	visual.work_clip=work_pose
	if not route.is_empty(): position=route[0]
func start_talk(partner: Node3D,text: String,duration: float) -> void:
	talk_partner=partner;talk_text=text;talk_timer=duration;meet_with=null;meet_timer=0.
func start_hold(seconds: float) -> void:
	talk_partner=null;talk_text="";talk_timer=seconds
func request_meet(other: Node3D,timeout: float) -> void:
	meet_with=other;meet_timer=timeout
func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var near_camera:=camera!=null and camera.global_position.distance_squared_to(global_position)<3600.
	visual.visible=near_camera
	if talk_timer>0.:
		talk_timer=maxf(0.,talk_timer-delta)
		visual.work_clip="ual/Talk" if talk_text!="" else work_pose
		velocity=velocity.move_toward(Vector3.ZERO,delta*2.5);position+=velocity*delta
		if talk_partner!=null and is_instance_valid(talk_partner):
			var face:=talk_partner.position-position;face.y=0.
			if face.length()>.1:rotation.y=lerp_angle(rotation.y,atan2(-face.x,-face.z),1.-exp(-delta*4.))
		if visual.visible:visual.update_animation(velocity.length(),false,delta)
		_settle(delta,0.,near_camera)
		return
	visual.work_clip=work_pose
	if route.size()<2:
		# A resident with no route simply stands (lighthouse keeper), still breathing in the idle clip.
		if visual.visible:visual.update_animation(0.,false,delta)
		visual._rod.visible=false
		_settle(delta,0.,near_camera)
		return
	wait=maxf(0.,wait-delta)
	var target:=route[target_index]
	var meeting:=meet_with!=null and is_instance_valid(meet_with)
	if meeting:
		meet_timer-=delta
		if meet_timer<=0.:meeting=false;meet_with=null
		else:target=meet_with.position
	var diff:=target-position;diff.y=0.
	var desired:=Vector3.ZERO
	if meeting:
		# A resting villager waits out the pause before walking over.
		if wait<=0. and diff.length()>TALK_RANGE*.6:desired=diff.normalized()*minf(speed,sqrt(2.*1.6*diff.length()))
	elif wait<=0. and diff.length()>.15:
		desired=diff.normalized()*minf(speed,sqrt(2.*1.6*diff.length()))
	elif wait<=0.:
		target_index=(target_index+1)%route.size();visits+=1
		# Pause only at a destination, instead of freezing at every bend.
		wait=1.2+fposmod(speed*3.7,1.5) if visits%route.size()==0 else 0.
	velocity=velocity.move_toward(desired,delta*1.6)
	position+=velocity*delta
	if velocity.length()>.08:rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),1.-exp(-delta*3.2))
	elif rest_yaw!=INF:rotation.y=lerp_angle(rotation.y,rest_yaw,1.-exp(-delta*2.5))
	if visual.visible:visual.update_animation(velocity.length(),false,delta)
	visual._rod.visible=false
	_settle(delta,velocity.length(),near_camera)
## Ground height, and the speech bubble while talking (only when the camera is close enough to read it).
func _settle(_delta: float,_moving: float,near_camera: bool) -> void:
	position.y=Layout.height(Vector2(position.x,position.z))+.08 if follow_terrain else route[0].y if route.size()>0 else position.y
	if ground_sampler.is_valid():position.y=ground_sampler.call(position)
	if talk_text!="" and talk_timer>0. and near_camera:
		if bubble==null:
			bubble=Label3D.new();bubble.billboard=BaseMaterial3D.BILLBOARD_ENABLED;bubble.no_depth_test=true
			bubble.pixel_size=.0055;bubble.font_size=44;bubble.outline_size=12;bubble.outline_modulate=Color(0.,0.,0.,.85)
			bubble.position=Vector3(0.,2.05,0.);add_child(bubble)
		if bubble.text!=talk_text:bubble.text=talk_text
		bubble.visible=true
	elif bubble!=null:bubble.visible=false
