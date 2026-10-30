extends Node3D
## Bounded local activity: birds, chimney smoke and occasional wild fish breaches.
const G=preload("res://scripts/world/geometry.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var world: Node3D
var birds: Array[Dictionary]=[]
var smoke: Array[CPUParticles3D]=[]
var wild_fish: Node3D
var clock: float=0.
var jump_clock: float=12.
var chirp_clock: float=4.
var birdsong: AudioStreamPlayer3D
func _ready() -> void:
	# Harbour gulls wheeling over the bay and a flock of small dark birds over the meadows behind the
	# town: GPU flocks with real-size, flapping-and-gliding birds (island_life.make_birds).
	var Life=preload("res://scripts/world/island_life.gd")
	var rng:=RandomNumberGenerator.new();rng.seed=4417
	Life.make_birds(self,"gaivota",Vector3(0,17,-28),40.,9,rng)
	Life.make_birds(self,"corvo",Vector3(-20,maxf(0.,Layout.ground(Vector2(-20,105)))+9.,105),18.,7,rng)
	wild_fish=preload("res://scripts/fishing/surface_fish.gd").new();add_child(wild_fish);wild_fish.effects=world.ocean.effects
	for i: int in [0,2,5,8]:
		var b: Node3D=world.village.buildings[i];var p:=CPUParticles3D.new();p.amount=14;p.lifetime=5.;p.direction=Vector3.UP;p.spread=14.;p.initial_velocity_min=.35;p.initial_velocity_max=.65;p.gravity=Vector3(.1,.08,.03);p.scale_amount_min=.2;p.scale_amount_max=.5
		var ramp:=Gradient.new();ramp.set_color(0,Color(.55,.58,.59,.18));ramp.set_color(1,Color(.6,.64,.65,0));p.color_ramp=ramp
		var mesh:=QuadMesh.new();mesh.size=Vector2(1,1);var mat:=preload("res://scripts/ocean/water_effects.gd").drop_material().duplicate() as StandardMaterial3D;mat.albedo_color=Color(.5,.54,.57,.35);mesh.material=mat;p.mesh=mesh;p.material_override=mat
		p.position=b.position+Vector3(b.width*.5-.8,5.65,b.depth*.5-1);add_child(p);smoke.append(p)
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var samples:=PackedByteArray();samples.resize(22050)
	var phase:=0.
	for i: int in 11025:
		var t:=float(i)/22050.;phase+=TAU*(1600.+800.*sin(t*18.))/22050.
		var value:=sin(phase)*pow(maxf(0.,sin(t*TAU*5.)),3.)*sin(t*PI/.5)*.12
		samples.encode_s16(i*2,int(value*32767))
	stream.data=samples;birdsong=AudioStreamPlayer3D.new();birdsong.stream=stream;birdsong.volume_db=-18.;birdsong.max_distance=70.;birdsong.unit_size=7.;add_child(birdsong)
func _process(delta: float) -> void:
	clock+=delta;jump_clock-=delta;chirp_clock-=delta
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	# Island birds (GPU flocks, group "aves") roost at night and in heavy rain too.
	if int(clock*2.)!=int((clock-delta)*2.):
		var flying: bool=world.ocean.daylight>.2 and world.ocean.weather.rain<.55
		for flock: Node in get_tree().get_nodes_in_group("aves"):(flock as Node3D).visible=flying
	for p: CPUParticles3D in smoke:p.emitting=camera.global_position.distance_squared_to(p.global_position)<22500.
	if jump_clock<=0.:
		jump_clock=17.+fposmod(clock*3.,13.)
		var p:=camera.global_position+camera.global_basis*Vector3(sin(clock)*12.,0,-22.)
		if not world.is_land(p) and camera.global_position.y<20.:
			wild_fish.breach(p,preload("res://data/fish/mackerel.tres"))
	if chirp_clock<=0. and world.ocean.daylight>.3 and world.ocean.weather.rain<.3:
		chirp_clock=8.+fposmod(clock,7.);birdsong.position=Vector3(-20,12,80);birdsong.play()
