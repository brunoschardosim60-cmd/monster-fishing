extends Node3D
## The home island's meadows and woods: wildflower drifts on the open slopes, flowering bushes along the
## trails, ferns, clover and mushrooms under the trees (Quaternius nature kit, CC0), animals grazing and
## butterflies over the flowers near the player. Everything is MultiMesh with short visibility ranges, so the
## island is dense where you walk and costs little from the sea.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Life=preload("res://scripts/world/island_life.gd")
const HOME_LOBES: Array[int]=[0,1,2,3,7]
## asset, count, scale range, visibility end (m), placement (open = meadows, edge = beside trails, shade = woods)
const SCATTER: Array=[
	["Flower_3_Group",900,Vector2(.8,1.3),130.,"open"],["Flower_4_Group",800,Vector2(.8,1.3),130.,"open"],
	["Flower_1_Group",600,Vector2(.8,1.2),120.,"open"],["Flower_2_Group",500,Vector2(.8,1.2),120.,"open"],
	["Flower_7_Group",400,Vector2(.8,1.2),120.,"edge"],["Clover_1",700,Vector2(.9,1.4),90.,"shade"],
	["Bush_Common_Flowers",260,Vector2(.9,1.4),220.,"edge"],["Bush_Large_Flowers",120,Vector2(.9,1.3),260.,"open"],
	["Bush_Common",260,Vector2(.9,1.5),220.,"shade"],["Fern_1",520,Vector2(.9,1.6),140.,"shade"],
	["Plant_1_Big",160,Vector2(.8,1.2),160.,"shade"],["Mushroom_RedCap",120,Vector2(.7,1.2),60.,"shade"],
	["Grass_Wide_Tall",900,Vector2(.9,1.4),110.,"open"],["Rock_Medium_1",80,Vector2(.6,1.4),300.,"open"]]
var _rng:=RandomNumberGenerator.new()
var butterflies: CPUParticles3D
var counts: Dictionary={}

func _ready() -> void:
	_rng.seed=31337
	for item: Array in SCATTER:_scatter(str(item[0]),int(item[1]),item[2],float(item[3]),str(item[4]))
	_animals()
	_butterflies()

func _bounds() -> Rect2:
	var r:=Rect2()
	for i: int in HOME_LOBES:
		var l: Vector4=Layout.LOBES[i];var b:=Rect2(l.x-l.z,l.y-l.w,l.z*2.,l.w*2.)
		r=b if r.size==Vector2.ZERO else r.merge(b)
	return r

## Slope (rise per metre) of the terrain at p.
func _slope(p: Vector2) -> float:
	var h:=Layout.ground(p)
	return maxf(absf(Layout.ground(p+Vector2(1.5,0))-h),absf(Layout.ground(p+Vector2(0,1.5))-h))/1.5

func _spot(kind: String) -> Vector3:
	var area:=_bounds()
	for attempt: int in (500 if kind=="edge" else 120):
		var p:=Vector2(_rng.randf_range(area.position.x,area.end.x),_rng.randf_range(area.position.y,area.end.y))
		var c:=Layout.coast(p)
		if c.x>-6.:continue  # in the water or on the beach
		var h:=Layout.ground(p)
		if h<2.5 or _slope(p)>.5 or Layout.in_town(p) or Layout.plot_ground(p):continue
		var trail:=Layout.path_at(p).x
		if trail<2.2:continue
		var woods:=Layout.noise(p,.7)>.12
		match kind:
			"open":if woods or trail<8.:continue
			"edge":if trail>9.:continue
			"shade":if not woods and _rng.randf()<.75:continue
		return Vector3(p.x,h-.05,p.y)
	return Vector3.INF

func _scatter(asset: String,count: int,scale_range: Vector2,view: float,kind: String) -> void:
	var path:="res://assets/environment/quaternius_nature/%s.gltf"%asset
	if not ResourceLoader.exists(path):return
	var parts:=_parts(path)
	if parts.is_empty():return
	# Flowers come in drifts: pick a centre, then several plants around it.
	var transforms: Array[Transform3D]=[]
	var misses:=0
	while transforms.size()<count and misses<20:
		var centre:=_spot(kind)
		if centre==Vector3.INF:misses+=1;continue
		var drift:=_rng.randi_range(3,9) if kind!="shade" else _rng.randi_range(1,4)
		for k: int in drift:
			var q:=Vector2(centre.x,centre.z)+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(0.,6.)
			if Layout.coast(q).x>-6. or Layout.in_town(q):continue
			var s:=_rng.randf_range(scale_range.x,scale_range.y)
			transforms.append(Transform3D(Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3.ONE*s),Vector3(q.x,Layout.ground(q)-.05,q.y)))
	counts[asset]=transforms.size()
	if transforms.is_empty():return
	# Split into tiles so the visibility range culls per area, not per island.
	var tiles: Dictionary={}
	for t: Transform3D in transforms:
		var key:=Vector2i(int(floor(t.origin.x/80.)),int(floor(t.origin.z/80.)))
		if not tiles.has(key):tiles[key]=[]
		(tiles[key] as Array).append(t)
	for key: Vector2i in tiles:
		var list: Array=tiles[key]
		for part: Dictionary in parts:
			var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=list.size()
			for i: int in list.size():mm.set_instance_transform(i,(list[i] as Transform3D)*(part.xform as Transform3D))
			var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.name="%s_%d_%d"%[asset,key.x,key.y]
			node.visibility_range_end=view;node.visibility_range_end_margin=view*.15;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if view<200. else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(node)

static var _part_cache: Dictionary={}
func _parts(path: String) -> Array:
	if _part_cache.has(path):return _part_cache[path]
	var scene: Node3D=(load(path) as PackedScene).instantiate()
	var out:=[]
	for mi: Node in scene.find_children("*","MeshInstance3D",true,false):
		var m:=mi as MeshInstance3D
		var xform:=Transform3D.IDENTITY;var n: Node=m
		while n!=scene and n is Node3D:xform=(n as Node3D).transform*xform;n=n.get_parent()
		var mesh: Mesh=m.mesh.duplicate()
		for s: int in mesh.get_surface_count():
			var mat:=m.get_active_material(s)
			if mat is BaseMaterial3D:
				mat=mat.duplicate();(mat as BaseMaterial3D).cull_mode=BaseMaterial3D.CULL_DISABLED
				if (mat as BaseMaterial3D).albedo_texture!=null:(mat as BaseMaterial3D).transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mesh.surface_set_material(s,mat)
		out.append({"mesh":mesh,"xform":xform})
	scene.free();_part_cache[path]=out
	return out

func _animals() -> void:
	var holder:=Node3D.new();holder.name="FaunaDaAurora";add_child(holder)
	for herd: Array in [["cervo",6,"shade"],["capivara",5,"open"],["cabra",5,"open"],["coelho",10,"open"]]:
		var spots: Array[Vector3]=[]
		var anchor:=_spot(str(herd[2]))
		if anchor==Vector3.INF:continue
		for k: int in int(herd[1]):
			var q:=Vector2(anchor.x,anchor.z)+Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(2.,14.)
			if Layout.coast(q).x>-6. or Layout.in_town(q):continue
			spots.append(Vector3(q.x,Layout.ground(q),q.y))
		Life.make_animals(holder,str(herd[0]),spots,_rng,Vector2(.5,.6) if herd[0]=="coelho" else Vector2(.9,1.2))
	var centre:=Vector3(-60,70,330)
	Life.make_birds(holder,"papagaio",centre,140.,9,_rng)
	Life.make_birds(holder,"gaivota",Vector3(40,40,-40),160.,10,_rng)

## Butterflies over the flowers around the player (only in daylight, see _process).
func _butterflies() -> void:
	butterflies=CPUParticles3D.new();butterflies.name="Borboletas";butterflies.amount=40;butterflies.lifetime=9.;butterflies.preprocess=9.
	butterflies.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;butterflies.emission_box_extents=Vector3(22,1.2,22)
	butterflies.direction=Vector3(1,.2,0);butterflies.spread=180.;butterflies.initial_velocity_min=.4;butterflies.initial_velocity_max=1.2;butterflies.gravity=Vector3.ZERO
	butterflies.angular_velocity_min=-60.;butterflies.angular_velocity_max=60.;butterflies.scale_amount_min=.6;butterflies.scale_amount_max=1.
	butterflies.color_initial_ramp=Gradient.new();butterflies.color_initial_ramp.set_color(0,Color("ffd23a"));butterflies.color_initial_ramp.set_color(1,Color("ff7ab8"))
	butterflies.color_initial_ramp.add_point(.5,Color("ffffff"));butterflies.color_initial_ramp.add_point(.75,Color("7ab8ff"))
	var wing:=QuadMesh.new();wing.size=Vector2(.14,.09)
	var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	wing.material=mat;butterflies.mesh=wing;butterflies.local_coords=false;add_child(butterflies)

func _process(_delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var p:=camera.global_position;var q:=Vector2(p.x,p.z)
	var on_land:=Layout.coast(q).x<-8. and not Layout.in_town(q) and _bounds().has_point(q)
	var world=get_parent()
	var day: bool=world==null or world.get("ocean")==null or float(world.ocean.daylight)>.5
	butterflies.emitting=on_land and day
	if on_land:butterflies.global_position=Vector3(p.x,Layout.ground(q)+1.2,p.z)
