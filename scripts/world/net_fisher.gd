extends Node3D
## A fisher standing in the shallows up to the knees, throwing a cast net: the net opens in the air, lands
## as a ring on the water, sinks, and is hauled back, sometimes with a few silver fish. Placed along the
## home island's beaches by coastal_world.gd (see place_all).
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
var look_id: int=0
var visual: Node3D
var net: MeshInstance3D
var fish: MeshInstance3D
var clock: float=0.
var cycle: float=11.
var _rng:=RandomNumberGenerator.new()
const THROW: float=1.1     # net leaves the hands
const LAND: float=2.1      # net touches the water
const HAUL: float=5.5      # hauling starts
const BACK: float=8.        # net back in the hands

func _ready() -> void:
	_rng.seed=look_id*97+7
	clock=_rng.randf()*cycle
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	visual.apply_look(preload("res://scripts/world/npc_look.gd").for_id(look_id))
	if visual.backpack!=null:visual.backpack.visible=false
	visual.idle_clip="ual/Idle"
	var disc:=CylinderMesh.new();disc.top_radius=1.;disc.bottom_radius=1.;disc.height=.02;disc.radial_segments=24;disc.rings=1
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/cast_net.gdshader")
	net=MeshInstance3D.new();net.mesh=disc;net.material_override=mat;net.top_level=true;net.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(net)
	var body:=SphereMesh.new();body.radius=.05;body.height=.1
	var silver:=StandardMaterial3D.new();silver.albedo_color=Color("cfd8dc");silver.metallic=.7;silver.roughness=.25
	fish=MeshInstance3D.new();fish.mesh=body;fish.material_override=silver;fish.scale=Vector3(1,1,4);fish.top_level=true;add_child(fish)

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var near:=camera!=null and camera.global_position.distance_squared_to(global_position)<14400.
	visual.visible=near;net.visible=near;fish.visible=false
	if not near:return
	clock=fmod(clock+delta,cycle)
	var casting:=clock<THROW+.4 or (clock>HAUL and clock<BACK)
	visual.work_clip="ual/FishCast" if clock<THROW+.4 else ("ual/FishReel" if casting else "")
	visual.update_animation(0.,false,delta)
	if visual.get("_rod")!=null:visual._rod.visible=false
	var ahead:=-global_basis.z;var hands:=global_position+Vector3(0,1.3,0)+ahead*.4
	var spot:=global_position+ahead*6.5;spot.y=Waves.height_at(spot)+.03
	var r:=.25;var at:=hands
	if clock<THROW:at=hands;r=.25
	elif clock<LAND:
		var k:=(clock-THROW)/(LAND-THROW)
		at=hands.lerp(spot,k)+Vector3(0,sin(k*PI)*2.2,0);r=lerpf(.3,2.1,smoothstep(0.,.8,k))
	elif clock<HAUL:
		var k2:=(clock-LAND)/(HAUL-LAND)
		at=spot-Vector3(0,k2*.6,0);r=lerpf(2.1,1.6,k2)
	elif clock<BACK:
		var k3:=(clock-HAUL)/(BACK-HAUL)
		at=(spot-Vector3(0,.6,0)).lerp(hands,smoothstep(0.,1.,k3));r=lerpf(1.6,.3,k3)
		if _rng.randf()<.9 and k3>.5:fish.visible=true;fish.global_position=at+Vector3(0,-.2,0);fish.rotation.y=clock*3.
	net.global_position=at;net.scale=Vector3(r,1.,r)
	net.global_rotation=Vector3(0,clock*.5,0)

## Puts a few net fishers knee-deep along the home island's beaches, away from the harbour.
static func place_all(parent: Node3D,count: int) -> Array[Node3D]:
	var out: Array[Node3D]=[]
	var l: Vector4=Layout.LOBES[0]
	var centre:=Vector2(l.x,l.y)
	for a: int in 72:
		if out.size()>=count:break
		var dir:=Vector2.from_angle(float(a)*TAU/72.+.3)
		var p:=centre
		for step: int in 600:
			p+=dir*1.5
			if Layout.coast(p).x>-.2:break
		if Layout.coast(p).x<-.6 or Layout.coast(p).x>1.2:continue
		if p.distance_to(Vector2(0,-20))<140. or Layout.in_town(p):continue
		var too_close:=false
		for other: Node3D in out:
			if Vector2(other.position.x,other.position.z).distance_to(p)<60.:too_close=true
		if too_close:continue
		var depth:=Waves.depth_at(p)
		if depth>1.3:continue
		# Only on a gently shelving sand beach: low land behind, no cliff.
		if Layout.height(p-dir*8.)>2.2 or Layout.height(p-dir*20.)>5.:continue
		var rocky:=false
		var world=parent.get_parent()
		if world!=null and world.get("shore_rocks")!=null:
			for r: Vector3 in world.shore_rocks:
				if Vector2(r.x,r.z).distance_to(p)<18.:rocky=true;break
		# Nothing solid standing around (cliffs, boulders) within a few metres.
		var space:=parent.get_world_3d().direct_space_state
		for k: int in 10:
			var q:=p+Vector2.from_angle(float(k)*TAU/10.)*(5. if k%2==0 else 10.)
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(q.x,40.,q.y),Vector3(q.x,-5.,q.y));ray.collision_mask=1
			var hit:=space.intersect_ray(ray)
			if not hit.is_empty() and float(hit.position.y)>1.2:rocky=true;break
		if rocky:continue
		var f: Node3D=load("res://scripts/world/net_fisher.gd").new()
		f.set("look_id",40+out.size()*3);f.name="PescadorDeTarrafa_%d"%out.size()
		f.position=Vector3(p.x,-depth+.05,p.y);f.rotation.y=atan2(-dir.x,-dir.y)
		parent.add_child(f);out.append(f)
	return out
