extends SceneTree
## Adds a rowing clip ("Row") to the baked UAL library. UAL has no rowing animation, so it is built from
## the seated driving pose: the torso swings from leaning forward (catch, arms reaching) to leaning back
## (finish, elbows pulled past the ribs) once per stroke. One stroke takes 2.618 s, the same period as the
## oars in traffic_vessel.gd (sin(phase*2.4)).
## godot --headless --path . --script res://scripts/pipeline/make_row_clip.gd
const LIB: String="res://assets/characters/animations/ual_humanoid.res"
const PERIOD: float=TAU/2.4
const FPS: float=30.

func _initialize() -> void:
	var lib: AnimationLibrary=load(LIB)
	var drive: Animation=lib.get_animation("Drive")
	var skel_scene: Node3D=load("res://assets/characters/survivalist_rigged.glb").instantiate();root.add_child(skel_scene)
	var sk: Skeleton3D=skel_scene.find_children("*","Skeleton3D",true,false)[0]
	var out:=Animation.new();out.length=PERIOD;out.loop_mode=Animation.LOOP_LINEAR
	var base: Dictionary={}
	var tracks: Dictionary={}
	for i: int in drive.get_track_count():
		var path:=str(drive.track_get_path(i))
		var tr:=out.add_track(drive.track_get_type(i));out.track_set_path(tr,drive.track_get_path(i))
		tracks[path+("#pos" if drive.track_get_type(i)==Animation.TYPE_POSITION_3D else "")]=tr
		if drive.track_get_type(i)==Animation.TYPE_ROTATION_3D:base[path.get_slice(":",1)]=drive.rotation_track_interpolate(i,0.)
		elif drive.track_get_type(i)==Animation.TYPE_POSITION_3D:base["#hips"]=drive.position_track_interpolate(i,0.)
	var prefix:=str(drive.track_get_path(0)).get_slice(":",0)
	var frames:=int(PERIOD*FPS)+1
	for f: int in frames:
		var t:=minf(float(f)/FPS,PERIOD)
		var s:=sin(t*2.4)            # +1 catch (reach forward) … -1 finish (pulled back)
		var lean:=-.32*s-.05         # torso pitch: negative leans forward
		var swing:=.75*s             # upper arms forward at the catch, back at the finish
		var bend:=.9*(1.-s)*.5+.15   # elbows bend at the finish
		var world: Dictionary={"Spine":Quaternion(Vector3.RIGHT,lean*.55),"Chest":Quaternion(Vector3.RIGHT,lean*.45),
			"RightUpperArm":Quaternion(Vector3.RIGHT,-swing),"LeftUpperArm":Quaternion(Vector3.RIGHT,-swing),
			"RightForeArm":Quaternion(Vector3.RIGHT,-bend),"LeftForeArm":Quaternion(Vector3.RIGHT,-bend),
			"Head":Quaternion(Vector3.RIGHT,-lean*.6)}
		# Compose globals down the chain and apply each world-space delta at its bone.
		var glob: Dictionary={}
		for i: int in sk.get_bone_count():
			var bn:=sk.get_bone_name(i);var parent:=sk.get_bone_parent(i)
			var local: Quaternion=base.get(bn,sk.get_bone_rest(i).basis.get_rotation_quaternion())
			var pg: Quaternion=Quaternion.IDENTITY if parent<0 else glob[sk.get_bone_name(parent)]
			var g:=pg*local
			if world.has(bn):g=(world[bn] as Quaternion)*g
			glob[bn]=g
			var path:="%s:%s"%[prefix,bn]
			if tracks.has(path):out.rotation_track_insert_key(tracks[path],t,(pg.inverse()*g).normalized())
		var hp: Vector3=base.get("#hips",Vector3.ZERO)
		out.position_track_insert_key(tracks["%s:Hips#pos"%prefix],t,hp+Vector3(0,0,.04*s))
	out.set_meta("source","Built from the UAL Driving_Loop pose (CC0) by make_row_clip.gd")
	if lib.has_animation("Row"):lib.remove_animation("Row")
	lib.add_animation("Row",out)
	print("Row clip ",ResourceSaver.save(lib,LIB,ResourceSaver.FLAG_COMPRESS))
	quit()
