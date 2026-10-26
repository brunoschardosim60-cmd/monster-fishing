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
var head_bone: int=-1
var _props: Array=[]
var chest_bone: int=-1
func _ready() -> void:
	model=preload("res://assets/characters/survivalist_rigged.glb").instantiate();add_child(model)
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
	_rod=Node3D.new();add_child(_rod)
	var carbon:=G.material(Color("243d42"),.34);var cork:=G.material(Color("bb9661"));var steel:=G.material(Color("bdc3bb"),.2)
	G.beam(_rod,Vector3(0,-.12,.1),Vector3(0,.28,-.23),.026,cork)
	G.beam(_rod,Vector3(0,.28,-.23),Vector3(0,1.35,-1.25),.013,carbon)
	G.beam(_rod,Vector3(0,1.35,-1.25),Vector3(0,1.72,-1.8),.006,carbon)
	G.cylinder(_rod,Vector3(.05,.04,-.04),.055,.08,steel,.055,18).rotation.z=PI*.5
	G.beam(_rod,Vector3(.08,.04,-.04),Vector3(.14,.1,-.04),.012,steel)
	for t: float in [.25,.48,.72,.92]:
		var ring:=TorusMesh.new();ring.inner_radius=.014;ring.outer_radius=.019;ring.rings=12;ring.ring_segments=6
		var guide:=G.mesh_node(_rod,ring,steel,Vector3(0,.28,-.23).lerp(Vector3(0,1.72,-1.8),t));guide.rotation.x=-.7
	_tip=Marker3D.new();_tip.position=Vector3(0,1.72,-1.8);_rod.add_child(_tip)
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
	var kind: String=str(look.get("headwear","fisher"))
	if kind!="fisher":
		headwear.queue_free()
		headwear=preload("res://scripts/player/character_accessories.gd").headwear(kind,look.get("headwear_tint",Color("40566b"))) if kind!="none" else Node3D.new()
		add_child(headwear)
	backpack.visible=bool(look.get("backpack",true))
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
	var next: String="Hold" if holding_fish else (swim_clip if swimming else (fish_clip if fishing else (seated_clip if seated else locomotion)))
	if airborne and not swimming:next="ual/JumpStart" if vertical_speed>0. else "ual/JumpLoop"
	if next!=current:
		# Locomotion clips share a phase convention (left foot first), so keep the cycle position and the feet do not pop.
		var cycles: Array[String]=["ual/Walk","ual/WalkCarry","ual/Jog","ual/Sprint"]
		var keep_phase: bool=current in cycles and next in cycles
		var phase: float=animation.current_animation_position/maxf(animation.current_animation_length,.001) if keep_phase else 0.
		animation.play(next,.3 if next in cycles or next==still else .2);current=next
		if keep_phase:animation.seek(phase*animation.current_animation_length,false)
	if UAL_SPEED.has(next):animation.speed_scale=clampf(gait_speed/float(UAL_SPEED[next]),.6,1.5)
	else:animation.speed_scale=1.
	animation.advance(delta)
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
	_rod.visible=fishing and not holding_fish and not swimming
	if _rod.visible:
		var hand: Transform3D=skeleton.global_transform*_bone_global(rod_hand)
		_rod.global_transform=Transform3D(hand.basis*rod_grip_basis,hand.origin)
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
func catch_hand_transform() -> Transform3D:return skeleton.global_transform*_bone_global(left_hand)
