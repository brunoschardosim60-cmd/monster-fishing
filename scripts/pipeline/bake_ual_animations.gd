extends SceneTree
## Bakes clips from Quaternius' Universal Animation Library (CC0) onto the game's 17-bone survivalist rig.
##   UAL_DIR=/path/to/quaternius godot --headless --path . --script res://scripts/pipeline/bake_ual_animations.gd
## UAL_DIR holds universal-animation-library/Unreal-Godot/UAL1.glb and universal-animation-library-2/Unreal-Godot/UAL2.glb
## (the versions without root motion). The source files stay outside the repository; only the baked library is kept:
## assets/characters/animations/ual_humanoid.res
##
## Retargeting works in world space, bone by bone. The UAL mannequin faces +Z in a T-pose; the survivalist faces -Z in
## an A-pose and its "Left*" bones sit on +X (the viewer's left), so the mannequin is turned 180° and each target bone takes
## the bone on the same side. For every pair, a reference pose of the source is aligned to the target rest by rotating
## each source bone onto the target bone's direction (shortest arc). Each frame the source's world rotation relative to
## that reference is applied to the target rest, and converted back to local poses down the target hierarchy.
const TARGET_SCENE: String="res://assets/characters/survivalist_rigged.glb"
const OUT: String="res://assets/characters/animations/ual_humanoid.res"
const FPS: float=30.
## target bone: [source bone, target child for direction, source child for direction] (empty child: inherit the parent's alignment)
const MAP: Dictionary={
	"Hips":["pelvis","Spine","spine_01"],"Spine":["spine_01","Chest","spine_03"],"Chest":["spine_03","Neck","neck_01"],
	"Neck":["neck_01","Head","Head"],"Head":["Head","",""],
	"RightUpperArm":["upperarm_l","RightForeArm","lowerarm_l"],"RightForeArm":["lowerarm_l","RightHand","hand_l"],"RightHand":["hand_l","",""],
	"LeftUpperArm":["upperarm_r","LeftForeArm","lowerarm_r"],"LeftForeArm":["lowerarm_r","LeftHand","hand_r"],"LeftHand":["hand_r","",""],
	"RightUpperLeg":["thigh_l","RightLowerLeg","calf_l"],"RightLowerLeg":["calf_l","RightFoot","foot_l"],"RightFoot":["foot_l","",""],
	"LeftUpperLeg":["thigh_r","LeftLowerLeg","calf_r"],"LeftLowerLeg":["calf_r","LeftFoot","foot_r"],"LeftFoot":["foot_r","",""]}
## Library name: [file 1 or 2, source clip, loops]
const CLIPS: Dictionary={"TPose":[1,"A_TPose",false],
	"Idle":[1,"Idle_Loop",true],"IdleLook":[1,"Idle_LookAround_Loop",true],"Talk":[1,"Idle_Talking_Loop",true],
	"Tired":[1,"Idle_Tired_Loop",true],"FoldArms":[2,"Idle_FoldArms_Loop",true],"Rail":[2,"Idle_Rail_Loop",true],
	"RailCall":[2,"Idle_Rail_Call",false],"Counter":[1,"Counter_Idle_Loop",true],"CounterGive":[1,"Counter_Give",false],
	"Lantern":[2,"Idle_Lantern_Loop",true],
	"Walk":[1,"Walk_Loop",true],"WalkCarry":[2,"Walk_Carry_Loop",true],"Jog":[1,"Jog_Fwd_Loop",true],"Sprint":[1,"Sprint_Loop",true],
	"JumpStart":[1,"Jump_Start",false],"JumpLoop":[1,"Jump_Loop",true],"JumpLand":[1,"Jump_Land",false],
	"Swim":[1,"Swim_Fwd_Loop",true],"SwimIdle":[1,"Swim_Idle_Loop",true],
	"Drive":[1,"Driving_Loop",true],"Sit":[1,"Sitting_Idle_Loop",true],"SitTalk":[1,"Sitting_Talking_Loop",true],
	"FishCast":[2,"Fish_Cast",false],"FishIdle":[2,"Fish_Cast_Idle_Loop",true],"FishReel":[2,"Fish_Reel",true],
	"FishHold":[2,"Fish_OH_Idle_Loop",true],
	"Chop":[2,"TreeChopping_Loop",true],"Hammer":[2,"Mining_Loop",true],"Fix":[1,"Fixing_Kneeling",true],
	"PickUp":[1,"PickUp_Kneeling",false],"Interact":[1,"Interact",false],"Celebrate":[1,"Celebration",false],
	"Yes":[2,"Yes",false],"Wave":[2,"Idle_Rail_Call",false],"Water":[2,"Farm_Watering",true]}

var target_skel: Skeleton3D
var target_root: Node3D
var track_prefix: String

func _initialize() -> void:
	var dir:=OS.get_environment("UAL_DIR")
	if dir.is_empty():dir="/home/claude/work/tilakverse-assets/quaternius"
	target_root=load(TARGET_SCENE).instantiate();root.add_child(target_root)
	target_skel=target_root.find_children("*","Skeleton3D",true,false)[0]
	track_prefix=str(target_root.get_path_to(target_skel))
	var sources: Dictionary={}
	for n: int in [1,2]:
		var path:="%s/universal-animation-library%s/Unreal-Godot/UAL%d.glb"%[dir,"" if n==1 else "-2",n]
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		if doc.append_from_file(path,state)!=OK:push_error("cannot read "+path);quit(1);return
		var scene: Node3D=doc.generate_scene(state);root.add_child(scene)
		sources[n]=scene
	var library:=AnimationLibrary.new()
	for clip_name: String in CLIPS:
		var spec: Array=CLIPS[clip_name]
		var scene: Node3D=sources[int(spec[0])]
		var anim:=_bake(scene,str(spec[1]),bool(spec[2]))
		if anim==null:push_error("missing clip "+str(spec[1]));continue
		library.add_animation(clip_name,anim)
		print("baked %s <- %s  %.2fs  ground %.2f m/s"%[clip_name,spec[1],anim.length,float(anim.get_meta("ground_speed",0.))])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err:=ResourceSaver.save(library,OUT,ResourceSaver.FLAG_COMPRESS)
	print("saved ",OUT," err ",err)
	quit(0 if err==OK else 1)

var _pose_cache: Dictionary={}
## Global pose composed from the local poses (the skeleton's own global cache is not refreshed while seeking offline).
func _global(sk: Skeleton3D,i: int) -> Transform3D:
	if _pose_cache.has(i):return _pose_cache[i]
	var parent:=sk.get_bone_parent(i)
	var t:=sk.get_bone_pose(i) if parent<0 else _global(sk,parent)*sk.get_bone_pose(i)
	_pose_cache[i]=t
	return t

func _skel_rot(sk: Skeleton3D,i: int,rest: bool) -> Quaternion:
	var t:=sk.get_bone_global_rest(i) if rest else _global(sk,i)
	return t.basis.orthonormalized().get_rotation_quaternion()

func _bake(scene: Node3D,clip: String,loops: bool) -> Animation:
	var sk: Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
	var ap: AnimationPlayer=scene.find_children("*","AnimationPlayer",true,false)[0]
	if not ap.has_animation(clip):return null
	var M:=Quaternion(Vector3.UP,PI)
	# Reference alignment per target bone, computed down the hierarchy so leaves inherit their parent's.
	var align: Dictionary={}
	var order: Array[String]=["Hips","Spine","Chest","Neck","Head","RightUpperArm","RightForeArm","RightHand","LeftUpperArm","LeftForeArm","LeftHand","RightUpperLeg","RightLowerLeg","RightFoot","LeftUpperLeg","LeftLowerLeg","LeftFoot"]
	for tb: String in order:
		var spec: Array=MAP[tb]
		var ti:=target_skel.find_bone(tb)
		if str(spec[1]).is_empty():
			align[tb]=align[target_skel.get_bone_name(target_skel.get_bone_parent(ti))]
			continue
		var si:=sk.find_bone(str(spec[0]))
		var tdir:=(target_skel.get_bone_global_rest(target_skel.find_bone(str(spec[1]))).origin-target_skel.get_bone_global_rest(ti).origin).normalized()
		var sdir:=(sk.get_bone_global_rest(sk.find_bone(str(spec[2]))).origin-sk.get_bone_global_rest(si).origin).normalized()
		sdir=M*sdir
		align[tb]=Quaternion(sdir,tdir) if sdir.dot(tdir)>-.999 else Quaternion(Vector3.UP,PI)
	var ref: Dictionary={}
	for tb: String in order:
		ref[tb]=(align[tb] as Quaternion)*M*_skel_rot(sk,sk.find_bone(str(MAP[tb][0])),true)
	var src_hips:=sk.find_bone("pelvis")
	var hips_rest_src:=sk.get_bone_global_rest(src_hips).origin
	var t_hips:=target_skel.find_bone("Hips")
	var hips_rest_tgt:=target_skel.get_bone_global_rest(t_hips).origin
	var ratio:=hips_rest_tgt.y/maxf(hips_rest_src.y,.01)
	var source_anim: Animation=ap.get_animation(clip)
	var length:=source_anim.length
	var out:=Animation.new();out.length=length;out.loop_mode=Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	var tracks: Dictionary={}
	for tb: String in order:
		var tr:=out.add_track(Animation.TYPE_ROTATION_3D);out.track_set_path(tr,"%s:%s"%[track_prefix,tb]);tracks[tb]=tr
	var pos_track:=out.add_track(Animation.TYPE_POSITION_3D);out.track_set_path(pos_track,"%s:Hips"%track_prefix)
	ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.play(clip)
	var frames:=maxi(2,int(round(length*FPS))+1)
	var foot_samples: Array=[]
	for f: int in frames:
		var time:=minf(float(f)/FPS,length)
		sk.reset_bone_poses();ap.seek(time,true);ap.advance(0.);_pose_cache.clear()
		var tg: Dictionary={}
		for tb: String in order:
			var s_rot:=M*_skel_rot(sk,sk.find_bone(str(MAP[tb][0])),false)
			tg[tb]=s_rot*(ref[tb] as Quaternion).inverse()*_skel_rot(target_skel,target_skel.find_bone(tb),true)
		for tb: String in order:
			var ti:=target_skel.find_bone(tb);var parent:=target_skel.get_bone_parent(ti)
			var local: Quaternion=tg[tb] if parent<0 else (tg[target_skel.get_bone_name(parent)] as Quaternion).inverse()*(tg[tb] as Quaternion)
			out.rotation_track_insert_key(tracks[tb],time,local.normalized())
		var hp:=_global(sk,src_hips).origin
		var delta:=M*(hp-hips_rest_src)*ratio
		out.position_track_insert_key(pos_track,time,hips_rest_tgt+delta)
		# Feet relative to the hips, for the ground speed of locomotion clips.
		var fl:=M*(_global(sk,sk.find_bone("foot_l")).origin-hp)*ratio
		var fr:=M*(_global(sk,sk.find_bone("foot_r")).origin-hp)*ratio
		foot_samples.append([time,fl,fr])
	out.set_meta("ground_speed",_ground_speed(foot_samples))
	out.set_meta("source","Quaternius Universal Animation Library (CC0): "+clip)
	return out

## Average backward speed of whichever foot is lower (the stance foot), relative to the hips.
func _ground_speed(samples: Array) -> float:
	var total:=0.;var n:=0
	for k: int in range(1,samples.size()):
		var a: Array=samples[k-1];var b: Array=samples[k]
		var dt: float=float(b[0])-float(a[0])
		if dt<=0.:continue
		var la: Vector3=a[1];var lb: Vector3=b[1];var ra: Vector3=a[2];var rb: Vector3=b[2]
		var stance_a: Vector3=la if la.y<ra.y else ra
		var stance_b: Vector3=lb if la.y<ra.y else rb
		total+=Vector2(stance_b.x-stance_a.x,stance_b.z-stance_a.z).length()/dt;n+=1
	return total/maxf(1.,float(n))
