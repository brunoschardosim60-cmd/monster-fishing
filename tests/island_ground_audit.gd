extends "res://tests/archipelago_contract.gd"
## Ground audit of the main island (Fase A): how well everything that should stand on the ground does.
##   · the exact ground sampler (Layout.ground) against the terrain collision;
##   · buildings: visible gaps under their base (floating) and terrain above their floor (buried);
##   · CC0 props: their base against the surface under them (terrain, pier or paving);
##   · trees and plants: their root against the ground;
##   · people: their feet against the surface under them while they walk their routes.
## Prints the worst cases. Run with --headless --fixed-fps 60 --script res://tests/island_ground_audit.gd
## (with "-- strict" it fails on any problem above the tolerances, for the contract).
const FLOAT_TOL: float=.12
const BURY_TOL: float=.35
var space: PhysicsDirectSpaceState3D
var report: Array[String]=[]

## Highest solid surface under a point (two rays a hand apart, as walkers use: deck planks have gaps).
func _support(p: Vector3,from_above: float=1.5,exclude: Array[RID]=[],spread: float=.12) -> float:
	var best:=-INF
	for dx: float in [-spread,spread]:
		var q:=PhysicsRayQueryParameters3D.create(p+Vector3(dx,from_above,0),p+Vector3(dx,-60.,0),1)
		q.exclude=exclude
		var hit:=space.intersect_ray(q)
		if not hit.is_empty():best=maxf(best,float(hit.position.y))
	return best

func _local_aabb(root: Node3D) -> AABB:
	var first:=true;var box:=AABB()
	for n: Node in root.find_children("*","MeshInstance3D",true,false):
		var mi:=n as MeshInstance3D
		if mi.mesh==null or String(mi.name).to_lower().contains("collider"):continue
		var rel: Transform3D=root.global_transform.affine_inverse()*mi.global_transform
		var b: AABB=rel*mi.get_aabb()
		box=b if first else box.merge(b);first=false
	return box

func _on_main_island(p: Vector3) -> bool:
	return p.x>-480. and p.x<400. and p.z>-80. and p.z<1120. and Layout.coast(Vector2(p.x,p.z)).x<2.

## Worst floating gap and worst burial over a grid under the building's own footprint.
func _building(root: Node3D,label: String,out: Array) -> void:
	var box:=_local_aabb(root)
	if box.size.x<1.5 or box.size.z<1.5:return
	var worst_gap:=0.;var worst_bury:=0.
	for i: int in 7:
		for k: int in 7:
			var lx: float=lerpf(box.position.x+box.size.x*.06,box.end.x-box.size.x*.06,float(i)/6.)
			var lz: float=lerpf(box.position.z+box.size.z*.06,box.end.z-box.size.z*.06,float(k)/6.)
			var w: Vector3=root.global_transform*Vector3(lx,box.position.y,lz)
			var g: float=Layout.ground(Vector2(w.x,w.z))
			if Layout.coast(Vector2(w.x,w.z)).x>-1.:continue
			worst_gap=maxf(worst_gap,w.y-g)
			var floor_w: Vector3=root.global_transform*Vector3(lx,0.,lz)
			worst_bury=maxf(worst_bury,g-floor_w.y)
	out.append([label,worst_gap,worst_bury,root.global_position])

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(40)
	space=game.get_world_3d().direct_space_state
	var strict: bool="strict" in OS.get_cmdline_user_args()
	var w=game.world;var v=w.village
	# 1) Sampler vs collision, away from buildings.
	var worst_sampler:=0.;var rng:=RandomNumberGenerator.new();rng.seed=5
	var n_s:=0
	while n_s<300:
		var p:=Vector2(rng.randf_range(-400,320),rng.randf_range(60,1000))
		if Layout.coast(p).x>-3.:continue
		var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,Layout.height(p)+40.,p.y),Vector3(p.x,-60.,p.y),1)
		var r:=space.intersect_ray(q)
		if r.is_empty() or not String(r.collider.get_parent().name).begins_with("Terrain_"):continue   # something built there
		var shape_owner: CollisionShape3D=(r.collider as Node).get_child(0) as CollisionShape3D
		if shape_owner==null or not shape_owner.shape is ConcavePolygonShape3D:continue   # a tree trunk
		var hit: float=r.position.y
		var g: float=Layout.ground(p)
		worst_sampler=maxf(worst_sampler,absf(hit-g));n_s+=1
	var worst_height:=0.
	for k: int in 300:
		var p:=Vector2(rng.randf_range(-400,320),rng.randf_range(60,1000))
		if Layout.coast(p).x>-3.:continue
		worst_height=maxf(worst_height,absf(Layout.height(p)-Layout.ground(p)))
	print("SAMPLER ground vs collision max %.3f m · old height() vs real ground max %.2f m"%[worst_sampler,worst_height])
	check(worst_sampler<.05,"Layout.ground matches the terrain collision (%.3f m)"%worst_sampler)
	# 2) Buildings.
	var blds: Array=[]
	for b: Node3D in v.buildings:_building(b,"vila:"+str(b.get("title")),blds)
	for b: Node3D in v.town.houses:_building(b,"cidade:"+String(b.name),blds)
	blds.sort_custom(func(a: Array,b: Array) -> bool:return maxf(float(a[1]),float(a[2]))>maxf(float(b[1]),float(b[2])))
	var bad_b:=0
	for b: Array in blds:
		if float(b[1])>FLOAT_TOL or float(b[2])>BURY_TOL:
			bad_b+=1
			if bad_b<=25:print("  BUILDING %s floating %.2f m · buried %.2f m at %s"%[b[0],b[1],b[2],str(Vector3(b[3]).snapped(Vector3.ONE))])
	print("BUILDINGS %d checked · %d with problems"%[blds.size(),bad_b])
	if strict:check(bad_b==0,"every building sits on the ground (%d with gaps or buried floors)"%bad_b)
	# 3) CC0 props on the main island.
	var props: Array=[]
	var holders: Array[Node3D]=[]
	for n: Node in w.find_children("CC0_*","Node3D",true,false):holders.append(n as Node3D)
	for h: Node3D in holders:
		if not _on_main_island(h.global_position):continue
		# Part of a building (a model that is the building on its plinth): judged with the buildings.
		if h.get_parent()!=null and h.get_parent().has_meta("style"):continue
		# Stacked on another prop (a log pile): it rests on the one below.
		var stacked:=false
		for o: Node3D in holders:
			if o!=h and o.global_position.y<h.global_position.y-.1 and Vector2(o.global_position.x-h.global_position.x,o.global_position.z-h.global_position.z).length()<.9:stacked=true;break
		if stacked:continue
		var ex: Array[RID]=[]
		for body: Node in h.find_children("*","CollisionObject3D",true,false):ex.append((body as CollisionObject3D).get_rid())
		var s: float=_support(h.global_position,.25,ex)
		var g: float=Layout.ground(Vector2(h.global_position.x,h.global_position.z))
		var gap: float=h.global_position.y-s
		var bury: float=g-h.global_position.y
		# Boulders and rocks are meant to be half in the ground.
		# Boulders are meant to be half in the ground; fence posts go into it on a slope.
		if String(h.name).contains("Rock") or String(h.name).contains("Fence"):bury-=.6;gap=minf(gap,0.) if s==-INF else gap
		props.append([String(h.name),gap,bury,h.global_position])
	var bad_p:=0
	props.sort_custom(func(a: Array,b: Array) -> bool:return maxf(float(a[1]),float(a[2]))>maxf(float(b[1]),float(b[2])))
	for p: Array in props:
		if float(p[1])>FLOAT_TOL or float(p[2])>BURY_TOL:
			bad_p+=1
			if bad_p<=25:print("  PROP %s floating %.2f · buried %.2f at %s"%[p[0],p[1],p[2],str(Vector3(p[3]).snapped(Vector3.ONE))])
	print("PROPS %d checked · %d with problems"%[props.size(),bad_p])
	if strict:check(bad_p==0,"every prop stands on what is under it (%d off)"%bad_p)
	# 4) Trees and plants (MultiMesh instances and single trees) on the main island. The headless
	#    renderer keeps no instance data, so this part needs a real one (xvfb-run, gl_compatibility).
	var headless: bool=DisplayServer.get_name()=="headless"
	var plants:=0;var bad_t:=0;var worst_t:=0.;var worst_at:=Vector3.ZERO
	for n: Node in ([] if headless else w.find_children("*","MultiMeshInstance3D",true,false)):
		var mmi:=n as MultiMeshInstance3D
		if mmi.multimesh==null or mmi.is_in_group("aves") or String(mmi.name).begins_with("aves") or String(mmi.name).contains("fauna"):continue
		if mmi.material_override!=null and mmi.material_override is ShaderMaterial and str((mmi.material_override as ShaderMaterial).shader.resource_path).contains("fish"):continue
		var mm:=mmi.multimesh
		if mm.transform_format!=MultiMesh.TRANSFORM_3D:continue
		# Main-island vegetation only: the island's own chunks, its meadows and the village.
		var owner_ok:=false;var walker: Node=mmi
		while walker!=null:
			if String(walker.name) in ["AuroraIsland","CamposDaAurora","VilaDaAurora"]:owner_ok=true;break
			walker=walker.get_parent()
		if not owner_ok or mmi.is_in_group("nature_shadow_proxy") or mmi.is_in_group("nature_far"):continue
		for i: int in mm.instance_count:
			var local_t: Transform3D=mm.get_instance_transform(i)
			if local_t.basis.determinant()<1e-6:continue
			var t: Transform3D=mmi.global_transform*local_t
			if not _on_main_island(t.origin) or t.origin.y<0.:continue
			var g: float=Layout.ground(Vector2(t.origin.x,t.origin.z))
			if absf(t.origin.y-g)>30.:continue   # birds, clouds…
			plants+=1
			var d: float=t.origin.y-g
			if d>FLOAT_TOL or d< -1.2:
				bad_t+=1
				if absf(d)>absf(worst_t):worst_t=d;worst_at=t.origin
	print("PLANTS %d instances · %d off the ground (worst %.2f m at %s)"%[plants,bad_t,worst_t,str(worst_at.snapped(Vector3.ONE))])
	if strict and not headless:check(bad_t==0,"trees and plants grow from the ground (%d off)"%bad_t)
	# 4b) Streets: nothing solid standing in the lane at knee height, and no grade a person cannot walk.
	var blocked:=0;var steep:=0;var sphere:=SphereShape3D.new();sphere.radius=.25
	for st: Array in v.town._streets:
		var a: Vector2=st[0];var b: Vector2=st[1];var width: float=st[2]
		var length: float=a.distance_to(b);var dir:=(b-a)/maxf(length,.01);var side:=Vector2(-dir.y,dir.x)
		var n: int=int(length/.75)
		var prev:=INF
		for i: int in n+1:
			var c: Vector2=a+dir*float(i)*.75
			if Layout.coast(c).x>-.5:prev=INF;continue
			var g: float=Layout.ground(c)
			if prev!=INF and absf(g-prev)/.75>.7:steep+=1
			prev=g
			var at_fountain:=false
			for sq: Array in v.town._plazas:
				if c.distance_to(sq[0])<3.4:at_fountain=true
			if at_fountain:continue
			for o: float in [0.,-.3,.3]:
				var q:=c+side*o*width
				var params:=PhysicsShapeQueryParameters3D.new();params.shape=sphere;params.collision_mask=1
				params.transform=Transform3D(Basis.IDENTITY,Vector3(q.x,Layout.ground(q)+.9,q.y))
				var hits:=space.intersect_shape(params,4)
				var hit_name:=""
				for h: Dictionary in hits:
					var body: Node=h.collider
					if body.get_parent()!=null and String(body.get_parent().name).begins_with("Terrain_") and body.get_child_count()>0 and (body.get_child(0) as CollisionShape3D).shape is ConcavePolygonShape3D:continue
					if body.get_parent()!=null and (String(body.get_parent().name).begins_with("Degrau") or String(body.get_parent().name)=="Rampa"):continue   # steps or a ramp up to a door
					hit_name=String(body.get_parent().name)+"<"+String(body.get_parent().get_parent().name)
					break
				if hit_name!="":
					blocked+=1
					if blocked<=15:print("  STREET blocked at %s by %s"%[str(Vector3(q.x,g,q.y).snapped(Vector3.ONE)),hit_name])
					break
	print("STREETS %d segments · %d blocked spots · %d too steep"%[v.town._streets.size(),blocked,steep])
	if strict:check(blocked==0 and steep==0,"streets are clear and walkable (%d blocked, %d too steep)"%[blocked,steep])
	if "plants_only" in OS.get_cmdline_user_args():
		print("ISLAND_GROUND %d checks / %d failures"%[checks,failures]);quit(1 if failures>0 else 0);return
	# 5) People walking their routes.
	var people: Array[Node3D]=[]
	people.append_array(v.residents);people.append_array(v.porters);people.append_array(v.town.residents);people.append_array(v.town.workers)
	var walkers=w.get_node_or_null("Caminhantes")
	if walkers!=null:
		for c: Node in walkers.get_children():
			if c is Node3D:people.append(c)
	var worst_people: Dictionary={}
	for f: int in 900:
		await physics_frame
		if f%6!=0:continue
		for p: Node3D in people:
			if not is_instance_valid(p) or not p.is_inside_tree() or not p.visible:continue
			var s: float=_support(p.global_position,1.2,[],.3)
			if s==-INF:continue
			var d: float=p.global_position.y-s
			var key: String=String(p.name)
			# A step taken between two ground checks is not a fault; staying off the ground is.
			var streak: int=int(p.get_meta("audit_off",0))
			streak=streak+1 if absf(d)>.3 else 0
			p.set_meta("audit_off",streak)
			if streak<3:d=minf(absf(d),.3)*signf(d)
			if absf(d)>absf(float(worst_people.get(key,[0.])[0])):
				var q:=PhysicsRayQueryParameters3D.create(p.global_position+Vector3.UP*1.2,p.global_position-Vector3.UP*60.,1)
				var hit:=space.intersect_ray(q)
				var what: String=str(hit.collider.get_parent().name if hit.collider!=null and hit.collider.get_parent()!=null else "") if not hit.is_empty() else ""
				worst_people[key]=[d,p.global_position,"%s/%s ft=%s"%[p.get_parent().name,what,str(p.get("follow_terrain"))]]
	var bad_n:=0
	for key: String in worst_people:
		var d: float=worst_people[key][0]
		if absf(d)>.3:
			bad_n+=1;print("  PERSON %s off the ground by %.2f m at %s (%s)"%[key,d,str((worst_people[key][1] as Vector3).snapped(Vector3(.1,.1,.1))),worst_people[key][2]])
	print("PEOPLE %d walking · %d leave the ground"%[people.size(),bad_n])
	# Nobody walks on the sea.
	var wet:=0
	for p: Node3D in people:
		if not is_instance_valid(p):continue
		var r: Array=p.get("route") if p.get("route")!=null else []
		for k: int in r.size():
			var a: Vector3=r[k];var b: Vector3=r[(k+1)%r.size()]
			for t: float in [0.,.25,.5,.75]:
				var q: Vector3=a.lerp(b,t)
				if Layout.coast(Vector2(q.x,q.z)).x>.5 and _support(Vector3(q.x,maxf(q.y,0.),q.z),4.,[],.3)<0.:
					wet+=1;print("  WATER WALK %s route leg %d at %s"%[p.name,k,str(q.snapped(Vector3.ONE))]);break
	print("ROUTES %d legs over open water"%wet)
	if strict:check(wet==0,"no walking route crosses open water (%d)"%wet)
	# Front doors reach the ground: where the floor stands above the street a flight of steps goes down.
	var hanging:=0
	for b: Node3D in v.town.houses:
		if str(b.get_meta("style",""))=="palafita" or bool(b.get_meta("over_water",false)):continue
		var size: Vector2=b.get_meta("size",Vector2(7,6))
		var out: Vector3=b.global_transform*Vector3(0.,0.,-size.y*.5-.6)
		var drop: float=b.global_position.y-Layout.ground(Vector2(out.x,out.z))
		if drop>.3 and int(b.get_meta("steps",0))==0:hanging+=1;print("  DOOR %s %.2f m above the ground, no steps"%[b.name,drop])
	print("DOORS %d houses · %d doors left hanging"%[v.town.houses.size(),hanging])
	if strict:check(hanging==0,"every raised front door has steps down to the ground (%d without)"%hanging)
	if strict:check(bad_n==0,"people walk on the ground, not above or under it (%d off)"%bad_n)
	print("ISLAND_GROUND %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
