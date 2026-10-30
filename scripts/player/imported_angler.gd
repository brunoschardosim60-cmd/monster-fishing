extends Node3D
## Survivalist character on a 17-bone rig. Body motion comes from Quaternius' Universal Animation Library (CC0),
## retargeted onto this rig by scripts/pipeline/bake_ual_animations.gd (library "ual/..."); the original hand-made clips
## remain for holding up a catch. NPCs choose their own idle, work and seated clips.
const G=preload("res://scripts/world/geometry.gd")
const UAL: AnimationLibrary=preload("res://assets/characters/animations/ual_humanoid.res")
## Ground speed (m/s) each UAL locomotion clip covers at 1x on this rig (measured from the root-motion versions).
const UAL_SPEED: Dictionary={"ual/Walk":.87,"ual/WalkCarry":.58,"ual/Jog":4.79,"ual/Sprint":7.38,"ual/Swim":1.94}
## Clip played when standing still (NPCs: "ual/Talk", "ual/Rail", "ual/Counter", "ual/FoldArms"...).
var idle_clip: String="ual/Idle"
## Walking clip ("ual/WalkCarry" while carrying a crate).
var walk_clip: String="ual/Walk"
## Clip while seated (helm, rowing bench, bench).
var seated_clip: String="ual/Drive"
## When set, played instead of the idle clip while not moving (chopping, hammering, fixing a hull).
var work_clip: String=""
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var seated: bool=false
var holding_fish: bool=false
var swimming: bool=false
var airborne: bool=false
var vertical_speed: float=0.
var fishing_state: int=0
var cast_power: float=0.
var locomotion_phase: float=0.
var _rod: Node3D
## Load on the rod, 0 straight … 1 bent hard (set by the game from line tension).
var rod_bend: float=0.
## Clip used while a caught fish is in the hands: one hand for small fish, both arms for big ones.
var hold_clip: String="ual/FishHold"
## A short one-shot action (kneel to release a fish, reach to stow it) that overrides the pose until done.
var action_clip: String=""
var action_time: float=0.
## Wind-up before a cast: -1 when not casting, else 0..1 charge. The rod is drawn back along the start of
## the cast clip (more charge, further back) and held there; releasing lets the clip run on into the throw.
var cast_hold: float=-1.
## Throwing something else (the cast net): the rod is put away for the throw.
var hide_rod: bool=false
const CAST_BACK_FROM: float=.12
const CAST_BACK_TO: float=.5
const ROD_JOINTS: int=7
var _rod_joints: Array[Node3D]=[]
var _bend_now: float=0.
var _tip: Marker3D
var current: String=""
var gait_speed: float=0.
## 0 idle, 1 walk, 2 jog, 3 sprint. Thresholds differ going up and down so the clip never flickers at a boundary.
var gait_state: int=0
## Hand holding the rod in the fishing clips, and the hand that presents a catch.
var rod_hand: int=-1
var left_hand: int=-1
var rod_grip_basis:=Basis.IDENTITY
var headwear: Node3D
var backpack: Node3D
## The stylised body (folk_body.gd) that replaces the survivalist mesh on NPCs, if any.
var folk: MeshInstance3D
var head_bone: int=-1
var _props: Array=[]
var chest_bone: int=-1
## Hand-over-hand hauling (a net, a trap line, the anchor rode): 0 off .. 1 full. Laid over the idle clip
## after it is sampled: the body leans out over the rail, the arms take turns reaching down and pulling in.
var haul: float=0.
var _haul_blend: float=0.
var _haul_t: float=0.
## Signs found against the rig (skeleton space, the body faces -Z): + pitch about X swings an arm forward,
## - pitch bends the spine forward.
const HAUL_REACH: float=1.
func _ready() -> void:
	model=preload("res://assets/characters/survivalist_rigged.glb").instantiate();add_child(model)
	# Body without the backpack modelled into it; the backpack is a separate accessory (see apply_look).
	var body_node: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	body_node.mesh=preload("res://assets/characters/survivalist_body_nopack.res")
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animation=model.find_children("*","AnimationPlayer",true,false)[0]
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: String in animation.get_animation_list():
		if not key.begins_with("ual/"):animation.get_animation(key).loop_mode=Animation.LOOP_NONE if key=="Cast" else Animation.LOOP_LINEAR
	animation.add_animation_library("ual",UAL)
	# The rig's "Left*" bones sit on +X: in the UAL fishing clips the rod is held by that hand.
	rod_hand=skeleton.find_bone("LeftHand");left_hand=skeleton.find_bone("LeftHand")
	# Calibrate the grip in the fishing pose, then let the hand carry rod rotation.
	animation.play("ual/FishIdle");animation.seek(0.,true);animation.advance(0.)
	rod_grip_basis=_bone_global(rod_hand).basis.inverse()
	head_bone=skeleton.find_bone("Head");chest_bone=skeleton.find_bone("Chest")
	headwear=preload("res://assets/characters/accessories/fisher_cap.glb").instantiate();add_child(headwear)
	backpack=preload("res://assets/characters/accessories/fisher_backpack.glb").instantiate();add_child(backpack)
	# No pack by default (the angler's catch goes in the boat's hold or a creel); NPC looks may add one.
	backpack.visible=false
	_rod=Node3D.new();add_child(_rod)
	var carbon:=G.material(Color("243d42"),.34);var cork:=G.material(Color("bb9661"));var steel:=G.material(Color("bdc3bb"),.2)
	G.beam(_rod,Vector3(0,-.12,.1),Vector3(0,.28,-.23),.026,cork)
	G.cylinder(_rod,Vector3(.05,.04,-.04),.055,.08,steel,.055,18).rotation.z=PI*.5
	G.beam(_rod,Vector3(.08,.04,-.04),Vector3(.14,.1,-.04),.012,steel)
	# The blank is a chain of joints from butt to tip, so it can bend under load (rod_bend), most at the tip.
	var butt:=Vector3(0,.28,-.23);var tip_rest:=Vector3(0,1.72,-1.8)
	var along:=(tip_rest-butt).normalized();var seg: float=butt.distance_to(tip_rest)/float(ROD_JOINTS)
	var joint:=Node3D.new();joint.position=butt
	joint.basis=Basis(Vector3.RIGHT,along,Vector3.RIGHT.cross(along)).orthonormalized()
	_rod.add_child(joint)
	_rod_joints.clear()
	for i: int in ROD_JOINTS:
		var radius: float=lerpf(.014,.005,float(i)/float(ROD_JOINTS-1))
		G.beam(joint,Vector3.ZERO,Vector3(0,seg,0),radius,carbon)
		if i%2==1:
			var ring:=TorusMesh.new();ring.inner_radius=.012;ring.outer_radius=.017;ring.rings=12;ring.ring_segments=6
			G.mesh_node(joint,ring,steel,Vector3(0,seg*.9,-.02))
		_rod_joints.append(joint)
		var next:=Node3D.new();next.position=Vector3(0,seg,0);joint.add_child(next);joint=next
	_tip=Marker3D.new();joint.add_child(_tip)
	update_animation(0.,false,.01)
## Cosmetic variation for NPCs. Keys: cloth_hue, cloth_sat_mul, cloth_sat_add, cloth_val_mul, skin (Vector3),
## hair (Vector3), headwear ("fisher", "beanie", "straw", "bandana", "none"), headwear_tint, backpack (bool), height, build.
func apply_look(look: Dictionary) -> void:
	var body: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	var original: StandardMaterial3D=body.get_active_material(0)
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/npc_skin.gdshader");mat.set_shader_parameter("albedo_tex",original.albedo_texture)
	mat.set_shader_parameter("cloth_hue",float(look.get("cloth_hue",0.)));mat.set_shader_parameter("cloth_sat_mul",float(look.get("cloth_sat_mul",1.)))
	mat.set_shader_parameter("cloth_sat_add",float(look.get("cloth_sat_add",0.)));mat.set_shader_parameter("cloth_val_mul",float(look.get("cloth_val_mul",1.)))
	mat.set_shader_parameter("skin_mul",look.get("skin",Vector3.ONE));mat.set_shader_parameter("hair_mul",look.get("hair",Vector3.ONE))
	if ResourceLoader.exists("res://assets/characters/skin_zone_mask.png"):mat.set_shader_parameter("zone_tex",load("res://assets/characters/skin_zone_mask.png"))
	body.set_surface_override_material(0,mat)
	if look.has("body"):
		# Stylised townsfolk (folk_body.gd): own clothes, hair and hat on the same rig and animations.
		body.visible=false
		if folk!=null:folk.queue_free()
		folk=preload("res://scripts/visuals/folk_body.gd").attach(skeleton,str(look.body))
		look=look.duplicate();look["headwear"]="none";look["backpack"]=false
	var kind: String=str(look.get("headwear","fisher"))
	if kind!="fisher":
		headwear.queue_free()
		headwear=preload("res://scripts/player/character_accessories.gd").headwear(kind,look.get("headwear_tint",Color("40566b"))) if kind!="none" else Node3D.new()
		add_child(headwear)
	backpack.visible=bool(look.get("backpack",false))
	scale=Vector3(float(look.get("build",1.)),float(look.get("height",1.)),float(look.get("build",1.)))
func update_animation(speed: float,fishing: bool,delta: float) -> void:
	gait_speed=lerpf(gait_speed,speed,1.-exp(-delta*9.))
	match gait_state:
		0: if gait_speed>.3: gait_state=1
		1:
			if gait_speed<.18: gait_state=0
			elif gait_speed>2.6: gait_state=2
		2:
			if gait_speed<2.2: gait_state=1
			elif gait_speed>5.9: gait_state=3
		_: if gait_speed<5.4: gait_state=2
	var still: String=work_clip if not work_clip.is_empty() else idle_clip
	var locomotion: String=[still,walk_clip,"ual/Jog","ual/Sprint"][gait_state]
	var fish_clip: String="ual/FishCast" if fishing_state==1 else ("ual/FishReel" if fishing_state==4 else "ual/FishIdle")
	var swim_clip: String="ual/Swim" if gait_speed>.3 else "ual/SwimIdle"
	action_time=maxf(0.,action_time-delta)
	var held: String=hold_clip if animation.has_animation(hold_clip) else "Hold"
	var next: String=held if holding_fish else (swim_clip if swimming else (fish_clip if fishing else (seated_clip if seated else locomotion)))
	if airborne and not swimming:next="ual/JumpStart" if vertical_speed>0. else "ual/JumpLoop"
	if action_time>0. and animation.has_animation(action_clip):next=action_clip
	if cast_hold>=0. and not holding_fish and not swimming:next="ual/FishCast"
	if next!=current:
		# Locomotion clips share a phase convention (left foot first), so keep the cycle position and the feet do not pop.
		var cycles: Array[String]=["ual/Walk","ual/WalkCarry","ual/Jog","ual/Sprint"]
		var keep_phase: bool=current in cycles and next in cycles
		var phase: float=animation.current_animation_position/maxf(animation.current_animation_length,.001) if keep_phase else 0.
		animation.play(next,.3 if next in cycles or next==still else .2);current=next
		if keep_phase:animation.seek(phase*animation.current_animation_length,false)
	if cast_hold>=0. and next=="ual/FishCast":
		# Hold the wind-up: ease the clip toward the pose for this much charge and freeze it there.
		var want: float=lerpf(CAST_BACK_FROM,CAST_BACK_TO,clampf(cast_hold,0.,1.))
		var at: float=move_toward(animation.current_animation_position,want,delta*1.2)
		animation.seek(at,true);animation.speed_scale=0.
	elif UAL_SPEED.has(next):animation.speed_scale=clampf(gait_speed/float(UAL_SPEED[next]),.6,1.9 if next.begins_with("ual/Walk") else 1.5)
	else:animation.speed_scale=1.
	animation.advance(delta)
	_haul_blend=move_toward(_haul_blend,haul,delta*3.)
	if _haul_blend>.01:_apply_haul(delta)
	headwear.global_transform=skeleton.global_transform*_bone_global(head_bone)*skeleton.get_bone_global_rest(head_bone).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0,0,-.11))
	backpack.global_transform=skeleton.global_transform*_bone_global(chest_bone)*skeleton.get_bone_global_rest(chest_bone).affine_inverse()
	# Fishing keeps its upper-body pose while the player can reposition on shore.
	locomotion_phase+=delta*speed*2.87
	if (fishing or holding_fish) and speed>.2 and not airborne and not swimming:
		for side: String in ["Left","Right"]:
			var sign_value:=1. if side=="Left" else -1.
			var index:=skeleton.find_bone(side+"UpperLeg")
			var rest:=skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(index,rest.inverse()*Quaternion(Vector3.RIGHT,sin(locomotion_phase)*sign_value*.38)*rest)
			index=skeleton.find_bone(side+"LowerLeg");rest=skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(index,rest.inverse()*Quaternion(Vector3.RIGHT,-maxf(0.,-sin(locomotion_phase)*sign_value)*.5)*rest)
	_place_props()
	_rod.visible=(fishing or cast_hold>=0.) and not holding_fish and not swimming and not hide_rod
	if _rod.visible:
		var hand: Transform3D=skeleton.global_transform*_bone_global(rod_hand)
		_rod.global_transform=Transform3D(hand.basis*rod_grip_basis,hand.origin)
		# Bend toward the line: each joint turns a little more than the one below it.
		_bend_now=lerpf(_bend_now,rod_bend,1.-exp(-delta*16.))
		for i: int in _rod_joints.size():
			_rod_joints[i].rotation.x=-_bend_now*.32*pow(float(i+1)/float(ROD_JOINTS),1.6) if i>0 else _rod_joints[i].rotation.x
func _apply_haul(delta: float) -> void:
	_haul_t+=delta*TAU*.75
	var k: float=_haul_blend
	_turn_bone(skeleton.find_bone("Spine"),Vector3.RIGHT,-k*(.3+.06*sin(_haul_t*2.)))
	_turn_bone(chest_bone,Vector3.RIGHT,-k*.12)
	for side: Array in [["Left",0.],["Right",PI]]:
		var s: float=sin(_haul_t+float(side[1]))          # +1 reaching out and down to the line, -1 pulled in to the chest
		_turn_bone(skeleton.find_bone(str(side[0])+"UpperArm"),Vector3.RIGHT,k*HAUL_REACH*(.4+.8*s))
		_turn_bone(skeleton.find_bone(str(side[0])+"ForeArm"),Vector3.RIGHT,k*HAUL_REACH*(.75-.75*s))
## Turns a bone about a skeleton-space axis through its own joint (children follow).
func _turn_bone(i: int,axis: Vector3,angle: float) -> void:
	if i<0:return
	var g:=_bone_global(i);var p: int=skeleton.get_bone_parent(i)
	var turned:=Transform3D(Basis(axis,angle)*g.basis,g.origin)
	var local:=(_bone_global(p).affine_inverse() if p>=0 else Transform3D.IDENTITY)*turned
	skeleton.set_bone_pose_rotation(i,local.basis.get_rotation_quaternion())
## Bone pose in skeleton space, composed from the local poses so it is always current after a manual advance.
func _bone_global(i: int) -> Transform3D:
	var t:=skeleton.get_bone_pose(i);var p:=skeleton.get_bone_parent(i)
	while p>=0:
		t=skeleton.get_bone_pose(p)*t;p=skeleton.get_bone_parent(p)
	return t
## Puts a tool (axe, hammer) in the working hand; it follows the hand bone. `grip` orients it in the hand's space.
func hold_prop(prop: Node3D,grip: Transform3D=Transform3D.IDENTITY) -> void:
	_props.append([prop,grip]);add_child(prop)
func _place_props() -> void:
	if _props.is_empty():return
	var hand: Transform3D=skeleton.global_transform*_bone_global(rod_hand)
	for entry: Array in _props:(entry[0] as Node3D).global_transform=hand*(entry[1] as Transform3D)
func rod_tip() -> Vector3:return _tip.global_position
## Between both hands, a little low: where a big fish is held across the body.
func two_hand_point() -> Vector3:
	var right:=skeleton.find_bone("RightHand")
	var a:=(skeleton.global_transform*_bone_global(left_hand)).origin
	var b:=(skeleton.global_transform*_bone_global(right)).origin if right>=0 else a
	return (a+b)*.5+Vector3(0,-.12,0)
func catch_hand_transform() -> Transform3D:return skeleton.global_transform*_bone_global(left_hand)

## Plays a one-shot clip (e.g. "ual/PickUp" to kneel and put a fish back) for `seconds`.
func play_action(clip: String,seconds: float) -> void:
	action_clip=clip;action_time=seconds

## First person: hide the body, hat and backpack but keep the rod (and what the hands hold) in view.
func set_body_visible(value: bool) -> void:
	if model.visible==value:return
	model.visible=value
	if headwear!=null:headwear.visible=value
	if backpack!=null:
		if not value:backpack.set_meta("shown",backpack.visible);backpack.visible=false
		else:backpack.visible=bool(backpack.get_meta("shown",false))
