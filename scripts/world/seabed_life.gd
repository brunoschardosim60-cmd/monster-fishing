extends Node3D
## Life on the sea floor. Dense reefs in shallow water around the islands (one close to the harbour),
## built from organic procedural meshes: noise-displaced rocks and brain corals, tapering branch corals,
## swaying kelp, starfish and urchins. Repeated pieces are drawn with MultiMesh. Crabs walk the sand
## and two sunken boats rest on the bottom. Everything is placed on the real terrain height.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
const VesselModels=preload("res://scripts/boats/vessel_models.gd")
const SEAWEED=preload("res://assets/shaders/seaweed.gdshader")
const REEFS: int=18
const CORAL: Array[Color]=[Color("ff6f91"),Color("ff9e5e"),Color("c77dff"),Color("ffd166"),Color("ef476f"),Color("f4a261"),Color("7bdff2"),Color("f7aef8")]
const ROCK: Array[Color]=[Color("6e6a5c"),Color("5d6458"),Color("7a7262"),Color("4f5a4c")]
const KELP: Array[Color]=[Color("3f6b2e"),Color("5c7d33"),Color("6b6a2a"),Color("2f5a3a")]
const CRAB_RANGE: float=70.
var rng:=RandomNumberGenerator.new()
var noise:=FastNoiseLite.new()
## Reef centres (on the seabed); the first one is the reef near the harbour.
var reefs: Array[Vector3]=[]
var wrecks: Array[Vector3]=[]
var first_coral: Vector3=Vector3.INF
var crabs: Array=[]
## Highest point of every kelp clump (y), kept for checks: all must be below the surface.
var kelp_tops: PackedFloat32Array=PackedFloat32Array()
## kind -> {"meshes": Array[Mesh], "material": Material, "items": Array of [variant, Transform3D, Color]}
var _batches: Dictionary={}
## Each reef or wreck is its own group so its MultiMeshes sit at its centre and cull by distance.
var _group: int=-1
var _group_centres: Array[Vector3]=[]
func _begin_group(centre: Vector3) -> void:
	_group_centres.append(centre);_group=_group_centres.size()-1

## Height of the bottom you actually see: the island terrain (via its collision) or, beyond it,
## the following seabed plane, whose shader sets y = -max(.85, .8 + coast*.65).
func floor_at(p: Vector2) -> float:
	var plane:=-maxf(.85,.8+Layout.coast(p).x*.65)
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,-.3,p.y),Vector3(p.x,-160.,p.y));query.collision_mask=1
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return plane
	return maxf(plane,(hit.position as Vector3).y)
func _ready() -> void:
	# Terrain collision must be registered before the ray queries in floor_at().
	await get_tree().physics_frame
	await get_tree().physics_frame
	rng.seed=2026;noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;noise.frequency=1.4
	_prepare_meshes()
	var home:=_spot_near(Vector2.ZERO,40.,170.,-2.5,-8.)
	if home!=Vector3.INF:_reef(home)
	var attempts:=0
	while reefs.size()<REEFS and attempts<5000:
		attempts+=1
		var centre:=_spot(10.,60.,-2.,-9.)
		if centre==Vector3.INF or _too_close(centre,reefs,70.):continue
		_reef(centre)
	if not reefs.is_empty():first_coral=reefs[0]
	var near_home:=_spot_near(Vector2.ZERO,90.,320.,-4.,-9.)
	if near_home!=Vector3.INF:_wreck(near_home,"pesqueiro",12.)
	attempts=0
	while wrecks.size()<2 and attempts<4000:
		attempts+=1
		var spot:=_spot(14.,60.,-4.,-9.)
		if spot==Vector3.INF or _too_close(spot,wrecks,300.):continue
		_wreck(spot,"bote",7.5)
	_flush_batches()

# ---------------------------------------------------------------- placement
func _too_close(p: Vector3,list: Array,distance: float) -> bool:
	for q: Vector3 in list:
		if Vector2(p.x-q.x,p.z-q.z).length()<distance:return true
	return false
## Random seabed point in shallow water off a random island (Vector3 on the bottom), or INF.
func _spot(min_coast: float,max_coast: float,min_h: float,max_h: float) -> Vector3:
	var l:=Layout.LOBES[rng.randi()%Layout.LOBES.size()]
	var angle:=rng.randf()*TAU;var dist:=rng.randf_range(18.,260.)
	return _check(Vector2(l.x,l.y)+Vector2(cos(angle),sin(angle))*dist,min_coast,max_coast,min_h,max_h)
func _spot_near(at: Vector2,near: float,far: float,min_h: float,max_h: float) -> Vector3:
	for i: int in 400:
		var angle:=rng.randf()*TAU;var dist:=rng.randf_range(near,far)
		var p:=_check(at+Vector2(cos(angle),sin(angle))*dist,6.,90.,min_h,max_h)
		if p!=Vector3.INF:return p
	return Vector3.INF
func _check(p: Vector2,min_coast: float,max_coast: float,min_h: float,max_h: float) -> Vector3:
	var c:=Layout.coast(p)
	if c.x<min_coast or c.x>max_coast:return Vector3.INF
	var h:=floor_at(p)
	if h>min_h or h<max_h:return Vector3.INF
	return Vector3(p.x,h,p.y)
## A point on the bottom within `radius` of centre, or INF when that point is not under water.
func _scatter(centre: Vector3,radius: float) -> Vector3:
	var a:=rng.randf()*TAU;var r:=radius*sqrt(rng.randf())
	var p:=Vector2(centre.x+cos(a)*r,centre.z+sin(a)*r)
	var h:=floor_at(p)
	if h>-1.:return Vector3.INF
	return Vector3(p.x,h,p.y)

## How many of each piece a reef gets in each sea: warm water grows coral gardens with fans and plate
## corals; cold water grows kelp forests with sponges and anemones; volcanic rock carries sponges.
## [rock, brain, branch, kelp, fan, table, sponge, anemone] as [min,max] counts.
const BIOME_MIX: Dictionary={
	"tropical":[[5,8],[12,18],[14,20],[0,2],[4,7],[3,6],[2,4],[4,7]],
	"harbor":[[7,11],[9,15],[10,16],[5,9],[1,3],[0,2],[2,4],[2,4]],
	"frost":[[9,13],[0,0],[0,0],[16,24],[0,0],[0,0],[3,6],[5,8]],
	"volcanic":[[11,15],[2,4],[3,5],[2,4],[0,2],[0,1],[5,8],[3,5]],
	"storm":[[10,14],[3,6],[3,6],[9,14],[0,1],[0,0],[3,5],[2,4]],
	"shadow":[[10,14],[2,4],[2,4],[8,12],[1,2],[0,0],[4,6],[2,3]],
	"desert":[[6,9],[8,12],[8,12],[2,4],[2,4],[2,4],[2,3],[2,4]]}
const SPONGE: Array[Color]=[Color("e9a23b"),Color("d9603b"),Color("b24a8c"),Color("e6cf5a"),Color("8e6bd1")]
const ANEMONE: Array[Color]=[Color("ff8fa3"),Color("f4e3c1"),Color("7ad3c9"),Color("ffb26b"),Color("c58cff")]
## Biome of each reef, in order (kept for checks).
var reef_biomes: Array[String]=[]

func _reef(centre: Vector3) -> void:
	reefs.append(centre);_begin_group(centre)
	var biome: String=str(Layout.region_at(Vector2(centre.x,centre.z)).get("biome","harbor"))
	if not BIOME_MIX.has(biome):biome="harbor"
	reef_biomes.append(biome)
	var mix: Array=BIOME_MIX[biome]
	var radius:=rng.randf_range(11.,17.)
	var palette:=[CORAL[rng.randi()%CORAL.size()],CORAL[rng.randi()%CORAL.size()],CORAL[rng.randi()%CORAL.size()]]
	var rock_tint: Color=Color("2b2a2c") if biome=="volcanic" else (Color("8a9aa3") if biome=="frost" else Color("3d5a3a"))
	for i: int in rng.randi_range(mix[0][0],mix[0][1]):_put("rock",centre,radius,rng.randf_range(.7,2.4),ROCK[rng.randi()%ROCK.size()].lerp(rock_tint,rng.randf()*.45),.25)
	for i: int in rng.randi_range(mix[1][0],mix[1][1]):_put("brain",centre,radius*.8,rng.randf_range(.35,.9),palette[rng.randi()%3],.05)
	for i: int in rng.randi_range(mix[2][0],mix[2][1]):_put("branch",centre,radius*.85,rng.randf_range(.6,1.35),palette[rng.randi()%3],0.)
	for i: int in rng.randi_range(mix[3][0],mix[3][1]):_put("kelp",centre,radius*1.15,rng.randf_range(.8,1.5)*(1.3 if biome=="frost" else 1.),KELP[rng.randi()%KELP.size()],0.)
	for i: int in rng.randi_range(mix[4][0],mix[4][1]):_put("fan",centre,radius*.9,rng.randf_range(.8,1.6),[Color("c74b8b"),Color("e8a33d"),Color("8d5cc4"),Color("d4573f")][rng.randi()%4],0.)
	for i: int in rng.randi_range(mix[5][0],mix[5][1]):_put("table",centre,radius*.8,rng.randf_range(.7,1.5),palette[rng.randi()%3].lerp(Color("c9b98a"),.4),0.)
	for i: int in rng.randi_range(mix[6][0],mix[6][1]):_put("sponge",centre,radius,rng.randf_range(.5,1.2),SPONGE[rng.randi()%SPONGE.size()],.03)
	for i: int in rng.randi_range(mix[7][0],mix[7][1]):_put("anemone",centre,radius*.9,rng.randf_range(.6,1.1),ANEMONE[rng.randi()%ANEMONE.size()],0.)
	for i: int in rng.randi_range(4,7):_put("star",centre,radius*1.2,rng.randf_range(.16,.28),[Color("ff7a3d"),Color("e8443a"),Color("ffb347"),Color("b05cff")][rng.randi()%4],-.02)
	for i: int in rng.randi_range(3,6):_put("urchin",centre,radius,rng.randf_range(.14,.24),Color("3a1f4a"),.05)
	for i: int in rng.randi_range(2,3):
		var spot:=_scatter(centre,radius)
		if spot!=Vector3.INF:_crab(spot)

func _put(kind: String,centre: Vector3,radius: float,size: float,color: Color,sink: float) -> void:
	var p:=_scatter(centre,radius)
	if p==Vector3.INF:return
	var batch: Dictionary=_batches[kind]
	var variant:=rng.randi()%(batch.meshes as Array).size()
	# Kelp (up to ~4.6 m tall at scale 1) must stay below the surface.
	if kind=="kelp":
		size=minf(size,-p.y*.8/4.6)
		kelp_tops.append(p.y+size*4.6)
	var basis:=Basis(Vector3.UP,rng.randf()*TAU)
	if kind in ["branch","brain","rock","sponge","table"]:basis=Basis(Vector3(rng.randf_range(-1.,1.),0,rng.randf_range(-1.,1.)).normalized(),rng.randf_range(0.,.18))*basis
	basis=basis.scaled(Vector3.ONE*size)
	(batch.items as Array).append([variant,Transform3D(basis,p-Vector3(0,sink*size,0)),color.lerp(Color.WHITE,rng.randf_range(0.,.12)),_group])

func _flush_batches() -> void:
	for kind: String in _batches:
		var batch: Dictionary=_batches[kind]
		var meshes: Array=batch.meshes
		for group: int in _group_centres.size():
			var centre: Vector3=_group_centres[group]
			for variant: int in meshes.size():
				var items: Array=[]
				for item: Array in batch.items:
					if item[0]==variant and item[3]==group:items.append(item)
				if items.is_empty():continue
				var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
				mm.mesh=meshes[variant];mm.instance_count=items.size()
				for i: int in items.size():
					var t: Transform3D=items[i][1]
					mm.set_instance_transform(i,Transform3D(t.basis,t.origin-centre));mm.set_instance_color(i,items[i][2])
				var node:=MultiMeshInstance3D.new();node.name="%s_%d_%d"%[kind,group,variant];node.multimesh=mm;node.position=centre
				node.material_override=batch.material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.visibility_range_end=240.
				add_child(node)
	_batches.clear()

# ---------------------------------------------------------------- meshes
func _prepare_meshes() -> void:
	var solid:=StandardMaterial3D.new();solid.vertex_color_use_as_albedo=true;solid.roughness=.75;solid.cull_mode=BaseMaterial3D.CULL_DISABLED
	var glossy:=StandardMaterial3D.new();glossy.vertex_color_use_as_albedo=true;glossy.roughness=.45;glossy.cull_mode=BaseMaterial3D.CULL_DISABLED
	var weed:=ShaderMaterial.new();weed.shader=SEAWEED
	_batches["rock"]={"meshes":[_blob(11,.38,.55,.45),_blob(23,.3,.7,.5),_blob(37,.45,.5,.35)],"material":solid,"items":[]}
	_batches["brain"]={"meshes":[_blob(51,.12,.7,.9,true),_blob(63,.16,.62,.8,true)],"material":glossy,"items":[]}
	_batches["branch"]={"meshes":[_branch_coral(71),_branch_coral(83),_branch_coral(97)],"material":glossy,"items":[]}
	_batches["kelp"]={"meshes":[_kelp(101),_kelp(113)],"material":weed,"items":[]}
	_batches["star"]={"meshes":[_starfish()],"material":solid,"items":[]}
	_batches["urchin"]={"meshes":[_urchin(131)],"material":glossy,"items":[]}
	var tentacles:=ShaderMaterial.new();tentacles.shader=SEAWEED;tentacles.set_shader_parameter("sway",.09);tentacles.set_shader_parameter("speed",1.9)
	_batches["fan"]={"meshes":[_fan(151),_fan(163)],"material":glossy,"items":[]}
	_batches["table"]={"meshes":[_table(171),_table(181)],"material":glossy,"items":[]}
	_batches["sponge"]={"meshes":[_sponge(191,false),_sponge(193,true),_sponge(197,false)],"material":solid,"items":[]}
	_batches["anemone"]={"meshes":[_anemone(211),_anemone(223)],"material":tentacles,"items":[]}

## Orders a triangle so its face points along `outward`, then adds it with smooth normals.
func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,na: Vector3,nb: Vector3,nc: Vector3,ca: Color,cb: Color,cc: Color,outward: Vector3) -> void:
	if (b-a).cross(c-a).dot(outward)>0.:
		var tv:=b;b=c;c=tv;var tn:=nb;nb=nc;nc=tn;var tc:=cb;cb=cc;cc=tc
	st.set_normal(na);st.set_color(ca);st.add_vertex(a)
	st.set_normal(nb);st.set_color(cb);st.add_vertex(b)
	st.set_normal(nc);st.set_color(cc);st.add_vertex(c)

## Noise-displaced sphere, flattened underneath. `grooves` darkens crevices (brain coral look).
func _blob(seed_value: int,rough: float,squash: float,flat: float,grooves: bool=false) -> ArrayMesh:
	noise.seed=seed_value
	var rings:=12;var segs:=20
	var pts: Array=[];var cols: Array=[]
	for r: int in rings+1:
		var row: Array[Vector3]=[];var crow: Array[Color]=[]
		var theta:=PI*float(r)/float(rings)
		for s: int in segs:
			var phi:=TAU*float(s)/float(segs)
			var dir:=Vector3(sin(theta)*cos(phi),cos(theta),sin(theta)*sin(phi))
			var n:=noise.get_noise_3dv(dir*1.3)
			var detail:=noise.get_noise_3dv(dir*5.5)
			var radius:=1.+n*rough+detail*rough*(.9 if grooves else .25)
			var p:=dir*radius;p.y*=squash
			p.y=maxf(p.y,-flat*squash*.4)
			row.append(p)
			var shade:=.62+.38*clampf(.5+detail*(1.6 if grooves else .7),0.,1.)
			crow.append(Color(shade,shade,shade))
		pts.append(row);cols.append(crow)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: int in rings:
		for s: int in segs:
			var s2:=(s+1)%segs
			var a: Vector3=pts[r][s];var b: Vector3=pts[r][s2];var c: Vector3=pts[r+1][s2];var d: Vector3=pts[r+1][s]
			var ca: Color=cols[r][s];var cb: Color=cols[r][s2];var cc: Color=cols[r+1][s2];var cd: Color=cols[r+1][s]
			var out:=(a+b+c+d)*.25
			_tri(st,a,b,c,a.normalized(),b.normalized(),c.normalized(),ca,cb,cc,out)
			_tri(st,a,c,d,a.normalized(),c.normalized(),d.normalized(),ca,cc,cd,out)
	return st.commit()

## Tapering tube branches that fork a few times; brighter towards the tips.
func _branch_coral(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for trunk: int in local.randi_range(3,5):
		var dir:=Vector3(local.randf_range(-.45,.45),1.,local.randf_range(-.45,.45)).normalized()
		_grow(st,local,Vector3(local.randf_range(-.15,.15),0,local.randf_range(-.15,.15)),dir,local.randf_range(.45,.65),.085,0)
	return st.commit()
func _grow(st: SurfaceTool,local: RandomNumberGenerator,start: Vector3,dir: Vector3,length: float,radius: float,depth: int) -> void:
	var finish:=start+dir*length
	var tip_radius:=radius*.68
	_tube(st,start,finish,radius,tip_radius,Color(.7,.7,.7).lerp(Color.WHITE,float(depth)/3.),Color(.7,.7,.7).lerp(Color.WHITE,float(depth+1)/3.))
	if depth>=3:
		_cap(st,finish,dir,tip_radius)
		return
	for i: int in local.randi_range(2,3):
		var bend:=Vector3(local.randf_range(-.7,.7),local.randf_range(.1,.5),local.randf_range(-.7,.7))
		var child:=(dir+bend).normalized()
		if child.y<.2:child=(child+Vector3.UP*.4).normalized()
		_grow(st,local,finish,child,length*local.randf_range(.62,.8),tip_radius,depth+1)
func _tube(st: SurfaceTool,a: Vector3,b: Vector3,ra: float,rb: float,ca: Color,cb: Color) -> void:
	var axis:=(b-a).normalized()
	var side:=axis.cross(Vector3.FORWARD if absf(axis.y)>.9 else Vector3.UP).normalized()
	var up:=side.cross(axis).normalized()
	var sides:=6
	for i: int in sides:
		var a0:=TAU*float(i)/float(sides);var a1:=TAU*float(i+1)/float(sides)
		var d0:=side*cos(a0)+up*sin(a0);var d1:=side*cos(a1)+up*sin(a1)
		var p0:=a+d0*ra;var p1:=a+d1*ra;var p2:=b+d1*rb;var p3:=b+d0*rb
		var out:=(d0+d1)*.5
		_tri(st,p0,p1,p2,d0,d1,d1,ca,ca,cb,out)
		_tri(st,p0,p2,p3,d0,d1,d0,ca,cb,cb,out)
func _cap(st: SurfaceTool,at: Vector3,dir: Vector3,radius: float) -> void:
	var side:=dir.cross(Vector3.FORWARD if absf(dir.y)>.9 else Vector3.UP).normalized()
	var up:=side.cross(dir).normalized()
	var top:=at+dir*radius*1.6
	for i: int in 6:
		var a0:=TAU*float(i)/6.;var a1:=TAU*float(i+1)/6.
		var d0:=side*cos(a0)+up*sin(a0);var d1:=side*cos(a1)+up*sin(a1)
		_tri(st,at+d0*radius,at+d1*radius,top,d0,d1,dir,Color.WHITE,Color.WHITE,Color.WHITE,(d0+d1)*.5+dir)

## A clump of 4-6 ribbon blades; UV.y goes 0 (base) to 1 (tip) for the sway shader.
func _kelp(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade: int in local.randi_range(4,6):
		var base:=Vector3(local.randf_range(-.5,.5),0,local.randf_range(-.5,.5))
		var height:=local.randf_range(2.2,4.6);var width:=local.randf_range(.12,.22)
		var heading:=local.randf()*TAU;var lean:=Vector3(local.randf_range(-.4,.4),0,local.randf_range(-.4,.4))
		var segments:=9
		for i: int in segments:
			var t0:=float(i)/float(segments);var t1:=float(i+1)/float(segments)
			var w0:=width*sin(PI*clampf(t0*1.05+.05,0.,1.));var w1:=width*sin(PI*clampf(t1*1.05+.05,0.,1.))
			var twist0:=heading+t0*1.6;var twist1:=heading+t1*1.6
			var c0:=base+Vector3(0,t0*height,0)+lean*t0*t0;var c1:=base+Vector3(0,t1*height,0)+lean*t1*t1
			var s0:=Vector3(cos(twist0),0,sin(twist0))*w0;var s1:=Vector3(cos(twist1),0,sin(twist1))*w1
			var n0:=Vector3(-sin(twist0),0,cos(twist0));var n1:=Vector3(-sin(twist1),0,cos(twist1))
			for v: Array in [[c0-s0,n0,t0],[c0+s0,n0,t0],[c1+s1,n1,t1],[c0-s0,n0,t0],[c1+s1,n1,t1],[c1-s1,n1,t1]]:
				st.set_normal(v[1]);st.set_uv(Vector2(0,v[2]));st.set_color(Color.WHITE);st.add_vertex(v[0])
	return st.commit()

func _starfish() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3]=[]
	for i: int in 10:
		var a:=TAU*float(i)/10.;var r:=1. if i%2==0 else .4
		rim.append(Vector3(cos(a)*r,.05 if i%2==0 else .14,sin(a)*r))
	var top:=Vector3(0,.32,0);var bottom:=Vector3(0,0,0)
	for i: int in 10:
		var a: Vector3=rim[i];var b: Vector3=rim[(i+1)%10]
		var shade_a:=Color(1,1,1) if i%2==1 else Color(.8,.8,.8);var shade_b:=Color(1,1,1) if (i+1)%2==1 else Color(.8,.8,.8)
		_tri(st,top,a,b,Vector3.UP,(a+Vector3.UP).normalized(),(b+Vector3.UP).normalized(),Color.WHITE,shade_a,shade_b,Vector3.UP+(a+b)*.2)
		_tri(st,bottom,a,b,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Color(.6,.6,.6),Color(.6,.6,.6),Color(.6,.6,.6),Vector3.DOWN)
	return st.commit()

func _urchin(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body:=_blob(seed_value,.08,.75,.6)
	st.append_from(body,0,Transform3D.IDENTITY)
	for i: int in 70:
		var dir:=Vector3(local.randf_range(-1.,1.),local.randf_range(-.1,1.),local.randf_range(-1.,1.)).normalized()
		var base:=dir*.8;var tip:=dir*local.randf_range(1.9,2.6)
		var side:=dir.cross(Vector3.UP if absf(dir.y)<.9 else Vector3.RIGHT).normalized()*.045
		var up:=side.cross(dir).normalized()*.045
		_tri(st,base-side,base+side,tip,-side,side,dir,Color(.5,.4,.6),Color(.5,.4,.6),Color.WHITE,up)
		_tri(st,base-up,base+up,tip,-up,up,dir,Color(.5,.4,.6),Color(.5,.4,.6),Color.WHITE,side)
	return st.commit()

# ---------------------------------------------------------------- crabs
func _crab(at: Vector3) -> void:
	var crab:=Node3D.new();crab.position=at;crab.rotation.y=rng.randf()*TAU;add_child(crab)
	var shell:=StandardMaterial3D.new();shell.albedo_color=[Color("c4502e"),Color("b8432a"),Color("d0703a")][rng.randi()%3];shell.roughness=.5
	var body:=MeshInstance3D.new();body.mesh=_blob(rng.randi()%1000,.08,.42,.8);body.material_override=shell
	body.scale=Vector3(.28,.28,.22);body.position.y=.12;crab.add_child(body)
	var legs: Array[Node3D]=[]
	for side: float in [-1.,1.]:
		for i: int in 3:
			var hip:=Node3D.new();hip.position=Vector3(side*.2,.1,-.08+float(i)*.09);crab.add_child(hip)
			G.beam(hip,Vector3.ZERO,Vector3(side*.2,.06,0),.028,shell)
			G.beam(hip,Vector3(side*.2,.06,0),Vector3(side*.32,-.1,0),.022,shell)
			legs.append(hip)
		var arm:=Node3D.new();arm.position=Vector3(side*.14,.12,-.2);crab.add_child(arm)
		G.beam(arm,Vector3.ZERO,Vector3(side*.1,.02,-.14),.035,shell)
		G.sphere(arm,Vector3(side*.12,.03,-.2),Vector3(.13,.08,.16),shell,8)
		G.beam(crab,Vector3(side*.06,.2,-.16),Vector3(side*.07,.28,-.18),.012,shell)
		G.sphere(crab,Vector3(side*.07,.29,-.18),Vector3.ONE*.035,_eye(),6)
	crabs.append({"node":crab,"home":at,"target":at,"wait":rng.randf_range(0.,3.),"legs":legs,"phase":rng.randf()*TAU})
var _eye_mat: StandardMaterial3D
func _eye() -> StandardMaterial3D:
	if _eye_mat==null:_eye_mat=StandardMaterial3D.new();_eye_mat.albedo_color=Color("111111");_eye_mat.roughness=.2
	return _eye_mat

func _physics_process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var eye:=camera.global_position
	for record: Dictionary in crabs:
		var node: Node3D=record.node
		var near:=node.global_position.distance_to(eye)<CRAB_RANGE
		node.visible=near
		if not near:continue
		record.wait=maxf(0.,float(record.wait)-delta)
		var moving:=false
		if record.wait<=0.:
			var to: Vector3=record.target-node.position;to.y=0.
			if to.length()<.08:
				var h: Vector3=record.home
				var goal:=Vector2(h.x+rng.randf_range(-3.,3.),h.z+rng.randf_range(-3.,3.))
				var ground:=floor_at(goal)
				if ground<-.8:record.target=Vector3(goal.x,ground,goal.y)
				record.wait=rng.randf_range(1.,4.)
			else:
				moving=true
				# Crabs walk sideways: face across the direction of travel.
				node.rotation.y=lerp_angle(node.rotation.y,atan2(-to.x,-to.z)+PI*.5,1.-exp(-delta*3.))
				node.position+=to.normalized()*minf(.3*delta,to.length())
				node.position.y=lerpf(node.position.y,floor_at(Vector2(node.position.x,node.position.z)),1.-exp(-delta*6.))
		record.phase=float(record.phase)+delta*(14. if moving else 0.)
		var legs: Array=record.legs
		for i: int in legs.size():
			(legs[i] as Node3D).rotation.z=sin(float(record.phase)+float(i)*1.7)*(.35 if moving else 0.)

# ---------------------------------------------------------------- wrecks
func _wreck(at: Vector3,kind: String,length_m: float) -> void:
	wrecks.append(at);_begin_group(at)
	var root:=Node3D.new();root.name="Naufragio";root.position=at+Vector3(0,-.55,0)
	root.rotation=Vector3(rng.randf_range(-.12,.12),rng.randf()*TAU,rng.randf_range(.38,.6));add_child(root)
	var hull:=VesselModels.build(kind,length_m);root.add_child(hull)
	var rotten:=StandardMaterial3D.new();rotten.albedo_color=Color("3d3328");rotten.roughness=.95;rotten.cull_mode=BaseMaterial3D.CULL_DISABLED
	var rust:=StandardMaterial3D.new();rust.albedo_color=Color("5a3b26");rust.roughness=.9
	var first:=true
	for child: Node in hull.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override=rotten if first else rust
			first=false
	# Broken mast lying on the sand, a barrel and loose planks, and growth on the hull.
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color("4a3d2e");wood.roughness=.95
	var mast_at:=at+Vector3(rng.randf_range(-4.,4.),0,rng.randf_range(-4.,4.));mast_at.y=floor_at(Vector2(mast_at.x,mast_at.z))
	G.beam(self,mast_at+Vector3(0,.1,0),mast_at+Vector3(length_m*.45,.25,1.2),.09,wood)
	for i: int in 5:
		var plank:=at+Vector3(rng.randf_range(-6.,6.),.05,rng.randf_range(-6.,6.))
		plank.y=floor_at(Vector2(plank.x,plank.z))+.04
		var board:=G.box(self,plank,Vector3(.25,.05,rng.randf_range(1.,2.2)),wood);board.rotation.y=rng.randf()*TAU
	var barrel_at:=at+Vector3(rng.randf_range(-5.,5.),0,rng.randf_range(-5.,5.));barrel_at.y=floor_at(Vector2(barrel_at.x,barrel_at.z))+.3
	var barrel:=G.cylinder(self,barrel_at,.32,.8,rust,.28,10);barrel.rotation.z=PI*.5
	for i: int in 10:_put("kelp",at,length_m*.7,rng.randf_range(.7,1.2),KELP[rng.randi()%KELP.size()],0.)
	for i: int in 8:_put("brain",at,length_m*.6,rng.randf_range(.3,.6),CORAL[rng.randi()%CORAL.size()],.05)
	for i: int in 5:_put("rock",at,length_m*.8,rng.randf_range(.6,1.4),ROCK[rng.randi()%ROCK.size()],.25)

## Sea fan (gorgonian): a flat lattice of thin branches fanning out in one vertical plane.
func _fan(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_fan_branch(st,local,Vector3.ZERO,Vector3(0,1,0),.32,.03,0)
	return st.commit()
func _fan_branch(st: SurfaceTool,local: RandomNumberGenerator,start: Vector3,dir: Vector3,length: float,radius: float,depth: int) -> void:
	var finish:=start+dir*length
	_tube(st,start,finish,radius,radius*.75,Color(.75,.75,.75).lerp(Color.WHITE,float(depth)/5.),Color(.75,.75,.75).lerp(Color.WHITE,float(depth+1)/5.))
	if depth>=5:return
	for i: int in 2:
		var turn:=local.randf_range(.25,.6)*(-1. if i==0 else 1.)
		var child:=Vector3(dir.x*cos(turn)-dir.y*sin(turn),dir.x*sin(turn)+dir.y*cos(turn),0.).normalized()
		if child.y<.15:child=(child+Vector3.UP*.5).normalized()
		_fan_branch(st,local,finish,child,length*local.randf_range(.72,.88),radius*.75,depth+1)

## Plate (table) coral: a wide, thin, slightly cupped disc on a short stalk; lathed with a wavy rim.
func _table(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st,Vector3.ZERO,Vector3(0,.32,0),.07,.06,Color(.7,.7,.7),Color(.8,.8,.8))
	var n:=18;var wob:=local.randf()*TAU
	for i: int in n:
		var a0:=TAU*float(i)/float(n);var a1:=TAU*float(i+1)/float(n)
		var r0:=.55+.07*sin(a0*3.+wob);var r1:=.55+.07*sin(a1*3.+wob)
		var c:=Vector3(0,.34,0)
		var p0:=Vector3(cos(a0)*r0,.4+.04*sin(a0*5.),sin(a0)*r0);var p1:=Vector3(cos(a1)*r1,.4+.04*sin(a1*5.),sin(a1)*r1)
		_tri(st,c,p0,p1,Vector3.UP,Vector3.UP,Vector3.UP,Color(.85,.85,.85),Color.WHITE,Color.WHITE,Vector3.UP)
		_tri(st,c-Vector3(0,.03,0),p1-Vector3(0,.03,0),p0-Vector3(0,.03,0),Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Color(.6,.6,.6),Color(.7,.7,.7),Color(.7,.7,.7),Vector3.DOWN)
	return st.commit()

## Barrel sponge (open, thick-walled vase) or a cluster of tube sponges.
func _sponge(seed_value: int,tubes: bool) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if tubes:
		for k: int in local.randi_range(3,5):
			var base:=Vector3(local.randf_range(-.18,.18),0,local.randf_range(-.18,.18))
			var top:=base+Vector3(local.randf_range(-.12,.12),local.randf_range(.45,.9),local.randf_range(-.12,.12))
			var r:=local.randf_range(.05,.08)
			_tube(st,base,top,r,r*1.15,Color(.7,.7,.7),Color.WHITE)
			_tube(st,top,top-Vector3(0,.25,0),r*.8,r*.8,Color(.35,.35,.35),Color(.25,.25,.25))
		return st.commit()
	var rings: Array=[]
	var steps:=7;var sides:=14
	for j: int in steps+1:
		var t:=float(j)/float(steps)
		var r:=.22+.18*sin(t*PI*.85)+.04*t;var y:=t*.75
		var ring: Array=[]
		for i: int in sides:
			var a:=TAU*float(i)/float(sides)
			var bump:=1.+.08*sin(a*5.+t*7.+float(seed_value))
			ring.append(Vector3(cos(a)*r*bump,y,sin(a)*r*bump))
		rings.append(ring)
	for j: int in steps:
		for i: int in sides:
			var i2:=(i+1)%sides
			var a: Vector3=rings[j][i];var b: Vector3=rings[j][i2];var c: Vector3=rings[j+1][i2];var d: Vector3=rings[j+1][i]
			var out:=Vector3(a.x+b.x,0,a.z+b.z).normalized()
			var ca:=Color(.65,.65,.65).lerp(Color.WHITE,float(j)/float(steps));var cb:=Color(.65,.65,.65).lerp(Color.WHITE,float(j+1)/float(steps))
			_tri(st,a,b,c,out,out,out,ca,ca,cb,out);_tri(st,a,c,d,out,out,out,ca,cb,cb,out)
			# Inner wall, dark: the sponge is hollow.
			var inner:=.82
			_tri(st,a*Vector3(inner,1,inner),c*Vector3(inner,1,inner),b*Vector3(inner,1,inner),-out,-out,-out,Color(.25,.22,.2),Color(.25,.22,.2),Color(.25,.22,.2),-out)
			_tri(st,a*Vector3(inner,1,inner),d*Vector3(inner,1,inner),c*Vector3(inner,1,inner),-out,-out,-out,Color(.25,.22,.2),Color(.25,.22,.2),Color(.25,.22,.2),-out)
	return st.commit()

## Sea anemone: a short column crowned with a ring of tentacles that sway (UV.y = 0 base … 1 tip).
func _anemone(seed_value: int) -> ArrayMesh:
	var local:=RandomNumberGenerator.new();local.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=local.randi_range(22,30)
	for k: int in count:
		var a:=TAU*float(k)/float(count)+local.randf()*.1
		var ring:=.08+.06*float(k%2)
		var base:=Vector3(cos(a)*ring,.12,sin(a)*ring)
		var out:=Vector3(cos(a),0,sin(a))
		var length:=local.randf_range(.18,.28);var width:=.018
		var side:=Vector3(-sin(a),0,cos(a))*width
		for i: int in 4:
			var t0:=float(i)/4.;var t1:=float(i+1)/4.
			var p0:=base+out*length*t0*.8+Vector3.UP*length*(t0-t0*t0*.4)
			var p1:=base+out*length*t1*.8+Vector3.UP*length*(t1-t1*t1*.4)
			var w0:=1.-t0*.7;var w1:=1.-t1*.7
			for v: Array in [[p0-side*w0,t0],[p0+side*w0,t0],[p1+side*w1,t1],[p0-side*w0,t0],[p1+side*w1,t1],[p1-side*w1,t1]]:
				st.set_normal((out+Vector3.UP).normalized());st.set_uv(Vector2(0,v[1]));st.set_color(Color.WHITE.lerp(Color(1,1,1),v[1]));st.add_vertex(v[0])
	# Column: a stubby cylinder, not swaying (UV.y = 0).
	for i: int in 10:
		var a0:=TAU*float(i)/10.;var a1:=TAU*float(i+1)/10.
		var d0:=Vector3(cos(a0),0,sin(a0));var d1:=Vector3(cos(a1),0,sin(a1))
		for v: Array in [[d0*.11,d0],[d1*.11,d1],[d1*.13+Vector3.UP*.13,d1],[d0*.11,d0],[d1*.13+Vector3.UP*.13,d1],[d0*.13+Vector3.UP*.13,d0]]:
			st.set_normal(v[1]);st.set_uv(Vector2.ZERO);st.set_color(Color(.7,.7,.7));st.add_vertex(v[0])
	return st.commit()
