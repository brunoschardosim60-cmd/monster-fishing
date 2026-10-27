extends Node3D
## Rod holders on the player's boat (positions per hull class, hull_classes.gd "holders"). With a line in
## the water the angler walks to a free holder and presses E: the rod goes in the holder and keeps fishing
## by itself while the angler does something else. A set line has its own chance of a bite (same conditions
## as hand fishing, see main._fishing_conditions). When a fish takes it the rod tip bends and shakes, the
## line goes tight and, with the bell fitted, the bell rings. The angler must reach the holder and press E
## to take the rod and fight the fish; left alone, the fish throws the hook after a while and the bait is gone.
## Nothing is caught automatically.
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
signal strike(holder: int)
## Seconds a hooked fish stays on an unattended rod before it shakes free (bigger fish sooner).
const HOOKED_FOR: float=16.
const REACH: float=1.6
var game: Node3D
var boat: CharacterBody3D
## One record per holder: {"node","rod_tip","joints","line","float","state" (empty|set|biting|spent),
## "water" (float point), "clock", "species", "weight", "region", "school"}
var holders: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
var _clock: float=0.

func _ready() -> void:
	_rng.randomize()

## Builds holders for the current hull (called when the boat changes class). Lines in the water are lost.
func rebuild() -> void:
	for h: Dictionary in holders:
		if is_instance_valid(h.node):h.node.queue_free()
		if is_instance_valid(h.line):h.line.queue_free()
		if is_instance_valid(h.bob):h.bob.queue_free()
	holders.clear()
	for spec: Dictionary in boat.hull_spec.get("holders",[]):
		holders.append(_build(spec))

func _build(spec: Dictionary) -> Dictionary:
	var steel:=G.material(Color("b9c2c4"),.25);steel.metallic=.8
	var carbon:=G.material(Color("2a3a40"),.35);var cork:=G.material(Color("bb9661"))
	var root:=Node3D.new();root.name="SuporteDeVara";root.position=spec.at;root.rotation.y=float(spec.yaw);boat._hull.add_child(root)
	# Tube clamped to the rail, leaning outboard and up.
	var lean:=Node3D.new();lean.rotation.x=-.75;root.add_child(lean)
	G.cylinder(lean,Vector3(0,.12,0),.035,.3,steel,.035,12)
	G.box(root,Vector3(0,-.02,.05),Vector3(.09,.05,.14),steel)
	# The rod itself, a chain of joints so it can bend when a fish pulls.
	var rod:=Node3D.new();rod.name="Vara";rod.visible=false;lean.add_child(rod)
	G.beam(rod,Vector3(0,-.05,0),Vector3(0,.4,0),.02,cork)
	G.cylinder(rod,Vector3(.04,.2,0),.045,.06,steel,.045,14).rotation.z=PI*.5
	var joints: Array[Node3D]=[];var joint:=Node3D.new();joint.position=Vector3(0,.4,0);rod.add_child(joint)
	for i: int in 6:
		G.beam(joint,Vector3.ZERO,Vector3(0,.3,0),lerpf(.012,.005,float(i)/5.),carbon)
		joints.append(joint);var next:=Node3D.new();next.position=Vector3(0,.3,0);joint.add_child(next);joint=next
	var tip:=Marker3D.new();joint.add_child(tip)
	var line_mesh:=ImmediateMesh.new();var line:=MeshInstance3D.new();line.mesh=line_mesh;line.top_level=true
	var lm:=StandardMaterial3D.new();lm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;lm.albedo_color=Color(.92,.92,.77);line.material_override=lm
	line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(line)
	var bobber:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.07;sphere.height=.22;bobber.mesh=sphere
	var red:=StandardMaterial3D.new();red.albedo_color=Color("ed8057");bobber.material_override=red;bobber.top_level=true;bobber.visible=false;add_child(bobber)
	return {"node":root,"rod":rod,"tip":tip,"joints":joints,"line":line,"line_mesh":line_mesh,"bob":bobber,"state":"empty","water":Vector3.ZERO,
		"clock":0.,"species":null,"weight":0.,"region":"coast","school":"","shake":0.}

## Index of the holder within reach of the player on deck (or -1).
func nearest(to: Vector3) -> int:
	var best:=-1;var dist:=REACH
	for i: int in holders.size():
		var d: float=(holders[i].node as Node3D).global_position.distance_to(to)
		if d<dist:dist=d;best=i
	return best

## Puts the rod the player is fishing with into holder `i`; the line stays where it is.
func set_rod(i: int,water: Vector3,region: String,school: String) -> bool:
	if i<0 or i>=holders.size() or holders[i].state!="empty":return false
	var h: Dictionary=holders[i]
	h.state="set";h.water=water;h.clock=0.;h.region=region;h.school=school;h.species=null
	(h.rod as Node3D).visible=true;(h.bob as Node3D).visible=true;(h.line as Node3D).visible=true
	return true

## Takes the rod out of holder `i`. Returns the hooked fish (species, weight, water) if one was on, else {}.
func take_rod(i: int) -> Dictionary:
	if i<0 or i>=holders.size() or holders[i].state=="empty":return {}
	var h: Dictionary=holders[i];var out: Dictionary={}
	if h.state=="biting":out={"species":h.species,"weight":h.weight,"water":h.water,"region":h.region}
	h.state="empty";(h.rod as Node3D).visible=false;(h.bob as Node3D).visible=false;(h.line as Node3D).visible=false
	(h.line_mesh as ImmediateMesh).clear_surfaces()
	return out

func count(state: String) -> int:
	var n:=0
	for h: Dictionary in holders:
		if h.state==state:n+=1
	return n

func _process(delta: float) -> void:
	if game==null or boat==null:return
	_clock+=delta
	for i: int in holders.size():
		var h: Dictionary=holders[i]
		if h.state=="empty":continue
		h.clock=float(h.clock)+delta
		# The line drifts with the boat: it trails off the holder's side, never through the hull.
		var tip: Vector3=(h.tip as Marker3D).global_position
		var water: Vector3=h.water
		var out:=Vector3(water.x-boat.global_position.x,0,water.z-boat.global_position.z)
		var reach: float=float(boat.hull_spec.beam)*.5*boat.size_factor+4.
		if out.length()<reach:water=boat.global_position+out.normalized()*reach
		water.y=Waves.height_at(water)
		h.water=water
		var bend: float=0.;var shake: float=0.
		match str(h.state):
			"set":
				# Same odds as fishing by hand at that spot, a little lower while the boat is under way.
				var rate: float=Fishing.BASE_BITE_RATE*float(game._holder_rate(water))
				if h.clock>2. and _rng.randf()<1.-exp(-rate*delta):_bite(i)
				(h.bob as Node3D).global_position=water+Vector3(0,.08+sin(_clock*2.+float(i))*.03,0)
			"biting":
				var weight: float=float(h.weight)
				bend=clampf(.45+log(1.+weight)*.12,.45,1.)
				shake=sin(_clock*(13.+float(i)))*.18+sin(_clock*29.)*.08
				(h.bob as Node3D).global_position=water+Vector3(sin(_clock*7.)*.3,-.35,cos(_clock*5.)*.3)
				if h.clock>HOOKED_FOR/maxf(1.,sqrt(weight/5.)):
					# The fish throws the hook; the bait is gone and the rod waits empty.
					h.state="spent";game.hud.notify("O peixe soltou-se da vara no suporte. Recolha e lance de novo.")
			"spent":
				(h.bob as Node3D).global_position=water+Vector3(0,.08,0)
		var joints: Array=h.joints
		for k: int in joints.size():
			(joints[k] as Node3D).rotation.x=-(bend*.35+shake*.4)*pow(float(k+1)/float(joints.size()),1.5)
		var lm: ImmediateMesh=h.line_mesh
		lm.clear_surfaces();lm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		var sag: float=.6 if h.state!="biting" else .03
		var end: Vector3=(h.bob as Node3D).global_position
		for s: int in 13:
			var t:=float(s)/12.
			lm.surface_add_vertex(tip.lerp(end,t)-Vector3.UP*sin(t*PI)*sag)
		lm.surface_end()

func _bite(i: int) -> void:
	var h: Dictionary=holders[i]
	var fishing: Node=game.fishing
	var pool: Array[Resource]=fishing._available(str(h.region))
	if pool.is_empty():return
	# The same species choice as a hand-held line at that spot.
	var keep_region: String=fishing.region_current;var keep_school: String=fishing._school
	fishing.region_current=str(h.region);fishing._school=str(h.school)
	var species: Resource=fishing._pick_species()
	fishing.region_current=keep_region;fishing._school=keep_school
	h.species=species;h.weight=snappedf(_rng.randf_range(float(species.min_weight),float(species.max_weight)),.01)
	h.state="biting";h.clock=0.
	strike.emit(i)
