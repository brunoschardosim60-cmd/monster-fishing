extends Node3D
## Gulls working a school: over the nearest shoals of small fish a flock wheels 8–16 m up, and now and then
## a bird folds its wings and plunges onto a fish near the surface, sits a moment on the water and climbs
## back. It is the sign a fisherman looks for from far off: birds diving = fish under them. Busiest at dawn
## and dusk, gone at night. One MultiMesh for every bird; positions are worked out here, the wing beat in
## the shader. Real size: about 1.3 m wingspan.
const Waves=preload("res://scripts/world/wave_field.gd")
const IslandLife=preload("res://scripts/world/island_life.gd")
const FLOCKS: int=3
const PER_FLOCK: int=7
const RANGE: float=320.
## Shoals of small fish that gulls hunt.
const PREY: Array[String]=["sardine","mackerel","manjuba","sargo","cirurgiao","seabass","donzela"]
const SIZE: float=.45
var marine: Node3D
var mm: MultiMesh
var mmi: MultiMeshInstance3D
## Per bird: {pos, vel, state ("circle","dive","sit","rise","leave"), angle, radius, height, timer, aim}
var birds: Array[Dictionary]=[]
## Per flock: the school it works (or null).
var flock_school: Array=[null,null,null]
var dives: int=0
var _pick_clock: float=0.

func _ready() -> void:
	mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	mm.mesh=IslandLife.creature_mesh("gaivota");mm.instance_count=FLOCKS*PER_FLOCK
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/gull_flap.gdshader")
	mmi=MultiMeshInstance3D.new();mmi.name="GaivotasCardume";mmi.multimesh=mm;mmi.material_override=mat
	mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mmi.top_level=true
	add_child(mmi)
	for i: int in FLOCKS*PER_FLOCK:
		birds.append({"pos":Vector3(0,-500,0),"vel":Vector3.ZERO,"state":"away","angle":randf()*TAU,"radius":randf_range(6.,14.),
			"height":randf_range(8.,16.),"timer":randf_range(2.,9.),"aim":Vector3.ZERO,"phase":randf()*TAU,"spin":(1. if i%3!=0 else -1.)*randf_range(.35,.6)})

## How eager the birds are now: dawn and dusk best, none in the dark.
func activity() -> float:
	if marine==null or marine.game==null:return 1.
	var ocean=marine.game.world.ocean
	if ocean.daylight<.25:return 0.
	var h: float=ocean.hour
	return 1.6 if (h>=5. and h<8.5) or (h>=16.5 and h<19.5) else 1.

func _eligible(school: Node3D,me: Vector3) -> bool:
	return is_instance_valid(school) and not school.predator and school.mmi.visible and str(school.species) in PREY \
		and Vector2(school.center.x-me.x,school.center.z-me.z).length()<RANGE

## The flocks go to the nearest schools of prey within range.
func _pick_schools() -> void:
	var me: Vector3=marine.game.player.global_position
	var found: Array=[]
	if activity()>0.:
		var list: Array=[]
		for s: Node3D in marine.fish_schools:
			if _eligible(s,me):list.append(s)
		list.sort_custom(func(a: Node3D,b: Node3D) -> bool: return a.center.distance_squared_to(me)<b.center.distance_squared_to(me))
		found=list.slice(0,FLOCKS)
	# Keep a flock on the school it already works; give free flocks the new ones.
	var next: Array=[null,null,null]
	for f: int in FLOCKS:
		if flock_school[f]!=null and flock_school[f] in found:next[f]=flock_school[f];found.erase(flock_school[f])
	for f: int in FLOCKS:
		if next[f]==null and not found.is_empty():next[f]=found.pop_front()
	flock_school=next

func _process(delta: float) -> void:
	if marine==null or marine.game==null:return
	_pick_clock-=delta
	if _pick_clock<=0.:_pick_clock=2.;_pick_schools()
	var eager: float=activity()
	for i: int in birds.size():
		var b: Dictionary=birds[i]
		var school: Node3D=flock_school[i/PER_FLOCK]
		if school!=null and not is_instance_valid(school):school=null
		_bird(b,school,eager,delta)
		_write(i,b)

func _bird(b: Dictionary,school: Node3D,eager: float,delta: float) -> void:
	var pos: Vector3=b.pos
	if school==null:
		# No work: climb away and vanish far off.
		if b.state=="away":return
		b.state="leave";b.vel=b.vel.move_toward(Vector3(b.vel.x,4.,b.vel.z).normalized()*12.,delta*6.)
		pos+=b.vel*delta;b.timer=float(b.timer)-delta
		if pos.distance_to(marine.game.player.global_position)>RANGE+60. or float(b.timer)<-20.:b.state="away";pos=Vector3(0,-500,0)
		b.pos=pos;return
	var centre: Vector3=school.center;centre.y=Waves.height_at(centre)
	if b.state=="away" or b.state=="leave":
		# Arrive from upwind, high.
		if b.state=="away":
			var from:=Vector2.from_angle(randf()*TAU)*randf_range(30.,50.)
			pos=centre+Vector3(from.x,18.,from.y);b.vel=(centre-pos).normalized()*11.
		b.state="circle";b.timer=randf_range(3.,10.)
	match str(b.state):
		"circle":
			b.angle=float(b.angle)+float(b.spin)*delta
			var goal: Vector3=centre+Vector3(cos(b.angle)*float(b.radius),float(b.height)+sin(float(b.angle)*2.3+float(b.phase))*1.5,sin(b.angle)*float(b.radius))
			b.vel=(b.vel as Vector3).move_toward((goal-pos).limit_length(1.)*11.,delta*14.)
			pos+=b.vel*delta
			b.timer=float(b.timer)-delta*eager
			if float(b.timer)<=0. and school.pos.size()>0:
				# Pick a fish and go for it.
				var fish: Vector3=school.pos[randi()%school.pos.size()]
				b.aim=Vector3(fish.x,Waves.height_at(fish),fish.z);b.state="dive"
		"dive":
			var to: Vector3=(b.aim as Vector3)-pos
			b.vel=(b.vel as Vector3).move_toward(to.normalized()*18.,delta*40.)
			pos+=b.vel*delta
			if pos.y<=(b.aim as Vector3).y+.15 or to.length()<.4:
				pos=b.aim;b.state="sit";b.timer=randf_range(1.,2.6);b.vel=Vector3.ZERO;dives+=1
				var fx=marine.game.world.ocean.effects
				if fx!=null and pos.distance_to(marine.game.player.global_position)<160.:fx.splash(pos,.35,false)
		"sit":
			pos.y=Waves.height_at(pos);b.timer=float(b.timer)-delta
			if float(b.timer)<=0.:b.state="rise";b.vel=Vector3(randf_range(-2.,2.),5.,randf_range(-2.,2.))
		"rise":
			b.vel=(b.vel as Vector3).move_toward(Vector3(b.vel.x,6.,b.vel.z),delta*5.)
			pos+=b.vel*delta
			if pos.y>centre.y+float(b.height)*.7:b.state="circle";b.timer=randf_range(4.,12.)
	b.pos=pos

func _write(i: int,b: Dictionary) -> void:
	if b.state=="away":
		mm.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),Vector3(0,-500,0)));return
	var v: Vector3=b.vel
	var yaw: float=atan2(-v.z,v.x) if Vector2(v.x,v.z).length()>.05 else float(b.get("yaw",0.))
	b.yaw=yaw
	var pitch: float=atan2(v.y,maxf(.1,Vector2(v.x,v.z).length()))
	if b.state=="sit":pitch=0.
	var bank: float=-float(b.spin)*.5 if b.state=="circle" else 0.
	var basis:=Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,pitch)*Basis(Vector3.RIGHT,bank)
	mm.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*SIZE),b.pos))
	# Wing beat: flapping when climbing or arriving, a glide when wheeling, folded in the plunge, tucked on the water.
	var flap: float={"circle":.25,"rise":1.,"leave":.8,"dive":0.,"sit":0.}.get(str(b.state),.3)
	var fold: float={"dive":1.,"sit":.8}.get(str(b.state),0.)
	mm.set_instance_custom_data(i,Color(flap,float(b.phase),fold,0.))
