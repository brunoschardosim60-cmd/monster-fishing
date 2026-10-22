extends Node3D
## Locally authored rig and seven clips. Original upload has no skeleton/actions.
const G=preload("res://scripts/world/geometry.gd")
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var seated: bool=false
var holding_fish: bool=false
var swimming: bool=false
var _rod: Node3D
var _tip: Marker3D
var current: String=""
var right_hand: int=-1
var left_hand: int=-1
func _ready() -> void:
	model=preload("res://assets/characters/survivalist_rigged.glb").instantiate();add_child(model)
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animation=model.find_children("*","AnimationPlayer",true,false)[0]
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: String in animation.get_animation_list():animation.get_animation(key).loop_mode=Animation.LOOP_LINEAR
	right_hand=skeleton.find_bone("RightHand");left_hand=skeleton.find_bone("LeftHand")
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
func update_animation(speed: float,fishing: bool,delta: float) -> void:
	var next: String="Hold" if holding_fish else ("Swim" if swimming else ("Fish" if fishing else ("Steer" if seated else ("Run" if speed>5. else ("Walk" if speed>.2 else "Idle")))))
	if next!=current:animation.play(next,.18);current=next
	animation.speed_scale=clampf(speed/2.6,.65,1.8) if next in ["Walk","Run"] else 1.
	animation.advance(delta)
	var hand: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(right_hand)
	_rod.global_transform=Transform3D(global_basis,hand.origin)
	_rod.visible=fishing and not holding_fish and not swimming
func rod_tip() -> Vector3:return _tip.global_position
func catch_hand_transform() -> Transform3D:return skeleton.global_transform*skeleton.get_bone_global_pose(left_hand)
