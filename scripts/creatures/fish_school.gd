extends Node3D
## One school (or one lone animal) of a procedural species, drawn as a single MultiMesh.
## Boids: cohesion + alignment + separation, a wandering goal around `home`, shore avoidance, per-fish depth layers,
## and panic when a boat or predator comes close. Simulated only while the player is near.
const Forms=preload("res://scripts/creatures/fish_forms.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const ACTIVE_RANGE: float=380.
## Schools are drawn larger than life so single fish read from the boat camera.
const SCHOOL_SCALE: float=1.7
var form_id: String=""
var species: String=""            # id used by the fishing system
var home: Vector3=Vector3.ZERO
var center: Vector3=Vector3.ZERO
var radius: float=40.
var depth_range: Vector2=Vector2(2.,10.)
var predator: bool=false          # scatters other schools within `scare_radius`
var scare_radius: float=34.
var mode: String="cardume"
## Distance from the shore inside which the school is pushed back out. Shallow-water schools use a few metres.
var shore_margin: float=18.
## Seconds this school has been gathered at a feed point (predators arrive after a while).
var feed_time: float=0.
## Highest seabed level around home (shallow schools), so fish never sink into a sandbank.
var floor_limit: float=-INF
## Coastline sample per fish (distance, normal), refreshed a few fish per frame: Layout.coast is costly.
var shore_cache: Array[Vector4]=[]
## Distance from the player inside which the school is simulated and drawn (shallow shoals are only seen up close).
var active_range: float=ACTIVE_RANGE
var _tick: int=0
var count: int=12
var pos: PackedVector3Array=PackedVector3Array()
var vel: PackedVector3Array=PackedVector3Array()
var phase: PackedFloat32Array=PackedFloat32Array()
var scale_of: PackedFloat32Array=PackedFloat32Array()
var pace: PackedFloat32Array=PackedFloat32Array()
var layer: PackedFloat32Array=PackedFloat32Array()
var body_length: float=1.
var cruise: float=1.5
var elapsed: float=0.
var seed_value: float=0.
var mmi: MultiMeshInstance3D
var multimesh: MultiMesh

func setup(form: String,fish_count: int,at: Vector3,spread: float,depths: Vector2,rng_seed: int) -> void:
	form_id=form;species=form;count=fish_count;home=at;center=at;radius=spread;depth_range=depths;seed_value=float(rng_seed)
	body_length=Forms.length_of(form);cruise=Forms.speed_of(form)
	var rng:=RandomNumberGenerator.new();rng.seed=rng_seed
	multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true
	multimesh.mesh=Forms.mesh(form);multimesh.instance_count=count
	mmi=MultiMeshInstance3D.new();mmi.multimesh=multimesh;mmi.material_override=Forms.material(form)
	mmi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mmi.custom_aabb=AABB(Vector3(-1500,-80,-1500),Vector3(3000,160,3000))
	add_child(mmi)
	var tail:=1.+float(Forms.FORMS[form].get("tail_len",.17))
	for i: int in count:
		var spawn:=at+Vector3(rng.randf_range(-1.,1.),0,rng.randf_range(-1.,1.))*minf(spread*.35,body_length*4.+3.)
		if Layout.coast(Vector2(spawn.x,spawn.z)).x<1.5:spawn=at+Vector3(rng.randf_range(-.5,.5),0,rng.randf_range(-.5,.5))
		pos.append(Vector3(spawn.x,-rng.randf_range(depths.x,depths.y),spawn.z))
		var heading:=rng.randf()*TAU
		vel.append(Vector3(cos(heading),0,sin(heading))*cruise*.6)
		phase.append(rng.randf()*TAU);scale_of.append(body_length*rng.randf_range(.82,1.18)/tail*SCHOOL_SCALE)
		pace.append(rng.randf_range(.88,1.14));layer.append(rng.randf())
		shore_cache.append(Layout.coast(Vector2(spawn.x,spawn.z)))
	_write(0.)

func _write(_delta: float) -> void:
	for i: int in count:
		var fwd:=vel[i];if fwd.length_squared()<.0004:fwd=Vector3(0,0,-1)
		fwd=fwd.normalized()
		var up:=Vector3.UP-fwd*fwd.y
		if up.length_squared()<.0001:up=Vector3.FORWARD
		up=up.normalized()
		var side:=fwd.cross(up)
		var basis:=Basis(fwd,up,side).scaled(Vector3.ONE*scale_of[i])
		multimesh.set_instance_transform(i,Transform3D(basis,pos[i]))
		multimesh.set_instance_custom_data(i,Color(phase[i],0,0,0))

## ctx: boat (Vector3), boat_speed, player (Vector3), line_target (Vector3), line_active (bool), threats (Array[Vector3])
func step(delta: float,ctx: Dictionary) -> void:
	var near:=Vector2(center.x-ctx.player.x,center.z-ctx.player.z).length()<active_range+radius
	mmi.visible=near
	if not near:return
	elapsed+=delta
	# Mood of the whole school.
	mode="cardume"
	var goal:=home+Vector3(cos(elapsed*.05+seed_value)*radius,0,sin(elapsed*.062+seed_value*1.7)*radius*.8)
	var panic:=1.
	if ctx.line_active and species!="" and center.distance_to(ctx.line_target)<42. and not predator:
		goal=ctx.line_target;mode="isca"
	# Feed thrown in the water draws small fish fast and up to the surface; a long frenzy attracts predators.
	var surface_pull:=0.
	var feed: Array=ctx.get("feed",[])
	var fed:=false
	for point: Vector3 in feed:
		var gap:=Vector2(center.x-point.x,center.z-point.z).length()
		if (not predator and gap<75.) or (predator and gap<140. and float(ctx.get("frenzy",0.))>12.):
			goal=point;mode="racao";panic=1.5 if gap>8. else 1.;surface_pull=1.;fed=true;break
	feed_time=feed_time+delta if fed else 0.
	var boat_gap:=Vector2(center.x-ctx.boat.x,center.z-ctx.boat.z).length()
	if absf(ctx.boat_speed)>4. and boat_gap<38.:
		goal=center+Vector3(center.x-ctx.boat.x,0,center.z-ctx.boat.z).normalized()*30.;mode="fuga";panic=2.1
	if not predator:
		for threat: Vector3 in ctx.threats:
			if Vector2(center.x-threat.x,center.z-threat.z).length()<scare_radius+radius*.25:
				goal=center+Vector3(center.x-threat.x,0,center.z-threat.z).normalized()*35.;mode="fuga";panic=maxf(panic,1.9)
	var mean_pos:=Vector3.ZERO;var mean_vel:=Vector3.ZERO
	for i: int in count:mean_pos+=pos[i];mean_vel+=vel[i]
	mean_pos/=float(count);mean_vel/=float(count)
	center=mean_pos
	var surface_at_center:=Waves.height_at(Vector3(center.x,0,center.z))
	var tight:=1.6 if mode=="fuga" else 1.
	_tick+=1
	for i: int in count:
		var p:=pos[i];var v:=vel[i]
		var steer:=Vector3.ZERO
		# Cohesion: pulls back inside the school, stronger the further away.
		var to_center:=mean_pos-p;to_center.y=0.
		steer+=to_center*(.35*tight)
		# Alignment with the school's average heading.
		steer+=(mean_vel-v)*.9
		# Separation from close neighbours.
		var clear:=body_length*.9
		# Separation from close neighbours (a sliding window of the school is enough and keeps it cheap).
		for k: int in mini(count-1,8):
			var j:=(i+1+k*maxi(1,count/9))%count
			if j==i:continue
			var off:=p-pos[j]
			var d2:=off.length_squared()
			if d2<clear*clear*2.2 and d2>.0001:steer+=off/d2*clear*2.4
		# Goal drift.
		var g:=goal-p;g.y=0.
		if g.length()>1.:steer+=g.normalized()*cruise*.75
		# Stay off the shore: push along the coast normal when close.
		if (i+_tick)%6==0:shore_cache[i]=Layout.coast(Vector2(p.x,p.z))
		var shore:=shore_cache[i]
		if shore.x<shore_margin:steer+=Vector3(shore.y,0,shore.z)*cruise*(shore_margin-shore.x)*.35
		# Depth layer: each fish has a preferred level that slowly breathes.
		var want:=-lerpf(depth_range.x,depth_range.y,.5+.5*sin(elapsed*.22+phase[i]*1.3)*(.4+layer[i]*.6))
		if surface_pull>0. and not predator:want=lerpf(want,-.35-layer[i]*.5,surface_pull)
		var floor_y:=-(maxf(0.,.8+shore.x*.65)-1.2)
		want=maxf(want,maxf(floor_y,floor_limit))
		steer.y+=(want-p.y)*1.4
		var limit:=cruise*pace[i]*panic
		v=v.move_toward(v+steer,delta*(2.6*panic)).limit_length(limit)
		var next:=p+v*delta
		# Distance to shore after the move, from the cached sample and the coast normal.
		if shore.x+Vector2(next.x-p.x,next.z-p.z).dot(Vector2(shore.y,shore.z))<minf(3.,shore_margin*.4):
			v=Vector3(shore.y,0,shore.z)*limit*.8;next=p+v*delta
		next.y=minf(next.y,surface_at_center-body_length*.25-.25)
		pos[i]=next;vel[i]=v
		phase[i]+=delta*(5.+v.length()*(8./maxf(body_length,.6)))*(1. if body_length<1.8 else .55)
	_write(delta)
	if predator:center=pos[0]

func is_near_surface() -> bool:
	return depth_range.x<body_length
