extends Node3D
## Animals that live in the clear water around the islands and can be watched from the boat or the pier:
## sea turtles that cruise the shallows and come up to breathe, stingrays gliding over the sand, manta rays
## near the surface offshore, and drifting swarms of jellyfish that glow at night.
## Feed thrown in the water (see MarineEcosystem.throw_feed) also draws turtles over.
## Each animal is a few meshes animated in code; animals far from the player are hidden and not updated.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const RANGE: float=260.
var ecosystem: Node3D
var turtles: Array[Dictionary]=[]
var rays: Array[Dictionary]=[]
var jellies: Array[Dictionary]=[]
var elapsed: float=0.
var _rng:=RandomNumberGenerator.new()
var _jelly_glow: Array[StandardMaterial3D]=[]

## spots: shallow-water points [Vector3(x, floor_y, z)] near the islands.
func populate(shallow: Array[Vector3],open_points: Array[Vector3]) -> void:
	_rng.seed=8128
	for i: int in mini(7,shallow.size()):
		var home: Vector3=shallow[(i*3+1)%shallow.size()]
		_add_turtle(home+Vector3(_rng.randf_range(-8.,8.),0,_rng.randf_range(-8.,8.)),.9+_rng.randf()*.5)
	for i: int in mini(5,shallow.size()):
		var home: Vector3=shallow[(i*2)%shallow.size()]
		_add_ray(home,false)
	for p: Vector3 in open_points.slice(0,3):_add_ray(p,true)
	for i: int in mini(3,shallow.size()):_add_jellies(shallow[(i*4+2)%shallow.size()],9)
	for p: Vector3 in open_points.slice(3,6):_add_jellies(p,12)

# --- Builders ---------------------------------------------------------------------------------------

func _mat(color: Color,rough: float=.7) -> StandardMaterial3D:
	return G.material(color,rough)

func _add_turtle(home: Vector3,size: float) -> void:
	var root:=Node3D.new();root.name="Tartaruga_%d"%turtles.size();add_child(root)
	var shell_mat:=_mat(Color("5d5a2e").lerp(Color("7a5a32"),_rng.randf()),.55)
	var scute:=_mat(Color("3f3a1e"),.6);var skin:=_mat(Color("7f8a66"),.8);var belly:=_mat(Color("d9c98f"),.8)
	var body:=Node3D.new();body.scale=Vector3.ONE*size;root.add_child(body)
	G.sphere(body,Vector3(0,0,0),Vector3(.9,.32,1.15),shell_mat,18)
	G.sphere(body,Vector3(0,-.08,0),Vector3(.82,.14,1.05),belly,14)
	for k: int in 5:G.sphere(body,Vector3(0,.13,-.38+float(k)*.19),Vector3(.2,.06,.16),scute,8)
	for s: float in [-1.,1.]:
		for k: int in 3:G.sphere(body,Vector3(s*.24,.1,-.25+float(k)*.24),Vector3(.18,.05,.17),scute,8)
	var head:=G.sphere(body,Vector3(0,.02,-.68),Vector3(.24,.2,.3),skin,12)
	G.sphere(body,Vector3(0,.0,-.78),Vector3(.16,.14,.18),skin,10)
	var flippers: Array[Node3D]=[]
	for data: Array in [[-1.,-.32,.62,.5],[1.,-.32,.62,.5],[-1.,.4,.3,.24],[1.,.4,.3,.24]]:
		var pivot:=Node3D.new();pivot.position=Vector3(float(data[0])*.36,-.02,float(data[1]));body.add_child(pivot)
		var fin:=G.box(pivot,Vector3(float(data[0])*float(data[2])*.5,0,float(data[3])*.25),Vector3(float(data[2]),.04,float(data[3])),skin)
		fin.rotation.y=-float(data[0])*.5
		flippers.append(pivot)
	root.position=Vector3(home.x,home.y+1.,home.z)
	turtles.append({"node":root,"home":home,"flippers":flippers,"head":head,"heading":_rng.randf()*TAU,"phase":_rng.randf()*TAU,
		"breathe":_rng.randf_range(20.,45.),"surfacing":0.,"depth":0.,"size":size,"speed":.7+_rng.randf()*.3})

func _add_ray(home: Vector3,manta: bool) -> void:
	var root:=Node3D.new();root.name=("Manta_%d" if manta else "Arraia_%d")%rays.size();add_child(root)
	var span:=4.2 if manta else 1.5
	var top:=_mat(Color("2f3236") if manta else Color("8a7a5c"),.6);var under:=_mat(Color("e8e6dd"),.7)
	var spots:=_mat(Color("5e523c"),.7)
	G.sphere(root,Vector3.ZERO,Vector3(span*.34,span*.07,span*.5),top,16)
	G.sphere(root,Vector3(0,-span*.02,0),Vector3(span*.32,span*.04,span*.46),under,12)
	if not manta:
		for k: int in 6:G.sphere(root,Vector3(_rng.randf_range(-.25,.25)*span,span*.03,_rng.randf_range(-.25,.25)*span),Vector3(.08,.02,.08),spots,6)
	var wings: Array[Node3D]=[]
	for s: float in [-1.,1.]:
		var pivot:=Node3D.new();pivot.position=Vector3(s*span*.14,0,0);root.add_child(pivot)
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tip:=Vector3(s*span*.5,0,span*.05);var front:=Vector3(0,0,-span*.3);var back:=Vector3(0,0,span*.25)
		for v: Vector3 in [front,tip,back,front,back,tip]:st.add_vertex(v)
		st.generate_normals()
		var wing:=MeshInstance3D.new();wing.mesh=st.commit();var wm:=top.duplicate() as StandardMaterial3D;wm.cull_mode=BaseMaterial3D.CULL_DISABLED
		wing.material_override=wm;pivot.add_child(wing);wings.append(pivot)
	if manta:
		for s: float in [-1.,1.]:G.box(root,Vector3(s*span*.1,0,-span*.33),Vector3(.12,.05,.4),top)
	var tail:=G.beam(root,Vector3(0,0,span*.4),Vector3(0,0,span*(1.05 if not manta else .8)),.025*span,top)
	var floor_y: float=home.y
	var y:=-1.2-_rng.randf() if manta else floor_y+.25
	root.position=Vector3(home.x,y,home.z)
	rays.append({"node":root,"home":home,"wings":wings,"tail":tail,"manta":manta,"angle":_rng.randf()*TAU,"radius":(26. if manta else 9.)+_rng.randf()*8.,
		"speed":(.06 if manta else .1)*(1.+_rng.randf()*.3),"phase":_rng.randf()*TAU,"y":y,"floor":floor_y})

func _add_jellies(at: Vector3,count: int) -> void:
	var swarm:=Node3D.new();swarm.name="AguasVivas_%d"%jellies.size();add_child(swarm)
	var colours: Array[Color]=[Color("9be8ff"),Color("ff9ee0"),Color("d6b4ff"),Color("fff1c4")]
	var c: Color=colours[jellies.size()%colours.size()]
	var bell_mat:=StandardMaterial3D.new();bell_mat.albedo_color=Color(c.r,c.g,c.b,.55);bell_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	bell_mat.roughness=.15;bell_mat.emission_enabled=true;bell_mat.emission=c;bell_mat.emission_energy_multiplier=.25;bell_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_jelly_glow.append(bell_mat)
	var strand:=StandardMaterial3D.new();strand.albedo_color=Color(c.r,c.g,c.b,.35);strand.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;strand.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var dome:=SphereMesh.new();dome.radius=.32;dome.height=.32;dome.is_hemisphere=true;dome.radial_segments=16;dome.rings=6
	var members: Array[Node3D]=[]
	for i: int in count:
		var jelly:=Node3D.new();jelly.position=Vector3(_rng.randf_range(-5.,5.),-_rng.randf_range(.5,2.2),_rng.randf_range(-5.,5.))
		jelly.scale=Vector3.ONE*_rng.randf_range(.7,1.4);swarm.add_child(jelly)
		var bell:=MeshInstance3D.new();bell.mesh=dome;bell.material_override=bell_mat;bell.name="Sino";jelly.add_child(bell)
		for k: int in 5:
			var a:=float(k)*TAU/5.
			G.beam(jelly,Vector3(cos(a)*.18,0,sin(a)*.18),Vector3(cos(a)*.12,-.75-float(k%2)*.3,sin(a)*.12),.008,strand)
		members.append(jelly)
	swarm.position=Vector3(at.x,0,at.z)
	jellies.append({"node":swarm,"origin":Vector3(at.x,0,at.z),"members":members,"phase":_rng.randf()*TAU})

# --- Behaviour -----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ecosystem==null or ecosystem.game==null:return
	elapsed+=delta
	var game: Node3D=ecosystem.game
	var player: Vector3=game.player.global_position
	var boat: Vector3=game.boat.global_position
	var boat_fast: bool=absf(float(game.boat.speed))>4.
	var feed: Array=ecosystem.feed_targets()
	for t: Dictionary in turtles:_turtle(t,delta,player,boat,boat_fast,feed)
	for r: Dictionary in rays:_ray(r,delta,player,boat,boat_fast)
	var hour: float=float(game.world.ocean.hour)
	var glow:=.25+(1.8 if hour<6. or hour>19.5 else 0.)
	for m: StandardMaterial3D in _jelly_glow:m.emission_energy_multiplier=glow
	for j: Dictionary in jellies:_jelly(j,delta,player)

func _turtle(t: Dictionary,delta: float,player: Vector3,boat: Vector3,boat_fast: bool,feed: Array) -> void:
	var node: Node3D=t.node
	var near:=node.position.distance_to(player)<RANGE
	node.visible=near
	if not near:return
	var home: Vector3=t.home
	var p:=node.position
	# Wander around home; come to feed; dive away from a fast boat.
	var goal:=home+Vector3(cos(elapsed*.03+float(t.phase))*14.,0,sin(elapsed*.037+float(t.phase)*1.3)*12.)
	for f: Vector3 in feed:
		if Vector2(f.x-p.x,f.z-p.z).length()<60.:goal=f;break
	var scared:=boat_fast and Vector2(p.x-boat.x,p.z-boat.z).length()<16.
	if scared:goal=p+(p-boat).normalized()*12.
	var to:=goal-p;to.y=0.
	var want:=atan2(-to.x,-to.z) if to.length()>1. else float(t.heading)
	t.heading=lerp_angle(float(t.heading),want,1.-exp(-delta*.6))
	var speed: float=float(t.speed)*(2.2 if scared else 1.)
	var fwd:=Vector3(-sin(float(t.heading)),0,-cos(float(t.heading)))
	var next:=p+fwd*speed*delta
	if Layout.coast(Vector2(next.x,next.z)).x<2.:t.heading=float(t.heading)+PI*.5*delta;next=p
	# Breathing: every so often swim up until the head breaks the surface, then glide back down.
	t.breathe=float(t.breathe)-delta
	if float(t.breathe)<=0. and not scared:t.surfacing=6.;t.breathe=_rng.randf_range(30.,60.)
	t.surfacing=maxf(0.,float(t.surfacing)-delta)
	var surface:=Waves.height_at(next)
	var floor_y:=maxf(home.y,-Waves.depth_at(Vector2(next.x,next.z)))+.45*float(t.size)
	var cruise_y:=minf(surface-1.4,maxf(floor_y,surface-2.6))
	var target_y:=surface-.12 if float(t.surfacing)>0. else (floor_y if scared else cruise_y)
	next.y=lerpf(p.y,clampf(target_y,floor_y,surface-.08),1.-exp(-delta*(.9 if float(t.surfacing)>0. else .5)))
	node.position=next
	node.rotation.y=float(t.heading)
	node.rotation.x=clampf((next.y-p.y)/maxf(delta,.001)*.3,-.35,.35)
	t.depth=surface-next.y
	var beat:=elapsed*(3.2 if scared else 1.6)+float(t.phase)
	var fl: Array=t.flippers
	for i: int in fl.size():
		var side:=-1. if i%2==0 else 1.
		var amp:=.55 if i<2 else .25
		(fl[i] as Node3D).rotation.z=side*sin(beat+(0. if i<2 else 1.4))*amp
		(fl[i] as Node3D).rotation.x=cos(beat)*(.25 if i<2 else .1)

func _ray(r: Dictionary,delta: float,player: Vector3,boat: Vector3,boat_fast: bool) -> void:
	var node: Node3D=r.node
	var near:=node.position.distance_to(player)<RANGE*(1.4 if r.manta else 1.)
	node.visible=near
	if not near:return
	var spook:=1.
	if boat_fast and Vector2(node.position.x-boat.x,node.position.z-boat.z).length()<14.:spook=2.6
	r.angle=float(r.angle)+float(r.speed)*delta*spook
	var a: float=r.angle;var radius: float=r.radius;var home: Vector3=r.home
	var p:=Vector3(home.x+cos(a)*radius,0,home.z+sin(a*1.17)*radius*.8)
	if Layout.coast(Vector2(p.x,p.z)).x<2.:p=node.position
	if r.manta:p.y=Waves.height_at(p)+float(r.y)
	else:p.y=maxf(float(r.floor),-Waves.depth_at(Vector2(p.x,p.z)))+.22
	var dir:=p-node.position;dir.y=0.
	node.position=p
	if dir.length_squared()>1e-6:node.rotation.y=atan2(-dir.x,-dir.z)
	var flap:=sin(elapsed*(1.1 if r.manta else 1.9)*spook+float(r.phase))
	var wings: Array=r.wings
	(wings[0] as Node3D).rotation.z=-flap*(.35 if r.manta else .22)
	(wings[1] as Node3D).rotation.z=flap*(.35 if r.manta else .22)
	(r.tail as Node3D).rotation.y=sin(elapsed*1.3+float(r.phase))*.15

func _jelly(j: Dictionary,delta: float,player: Vector3) -> void:
	var node: Node3D=j.node
	var near:=node.position.distance_to(player)<RANGE
	node.visible=near
	if not near:return
	var o: Vector3=j.origin;var ph: float=j.phase
	var drift:=o+Vector3(sin(elapsed*.02+ph)*12.,0,cos(elapsed*.017+ph)*12.)
	if Layout.coast(Vector2(drift.x,drift.z)).x>3.:node.position=Vector3(drift.x,Waves.height_at(drift)-.15,drift.z)
	var members: Array=j.members
	for i: int in members.size():
		var jelly: Node3D=members[i]
		var pulse:=sin(elapsed*2.1+float(i)*.9+ph)
		var bell: Node3D=jelly.get_child(0)
		bell.scale=Vector3(1.+pulse*.14,1.-pulse*.2,1.+pulse*.14)
		jelly.position.y=clampf(jelly.position.y+(maxf(pulse,0.)*.12-.035)*delta,-2.6,-.35)

## Positions of the turtles, for tests and the map.
func turtle_positions() -> Array[Vector3]:
	var out: Array[Vector3]=[]
	for t: Dictionary in turtles:out.append((t.node as Node3D).position)
	return out
