extends Node3D
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
var village: Node3D
var fishers: Array[Node3D]=[]
var stock: Array[Dictionary]=[]
var bridges: Array[Dictionary]=[]
var vendors: Array[Node3D]=[]
var walkers: Array[Node3D]=[]
var wood: Material
var trim: Material
var iron: Material
var canopies: Array[ShaderMaterial]=[]
func _ready() -> void:
	wood=M.surface("weathered_wood",Color("baaa88"),1.5)
	trim=M.surface("teak",Color("826146"),1.1)
	iron=G.material(Color("344a4b"),.36)
	_bridge(Vector3(-30,1.4,-4),Vector3(-61,1.4,-4),.48)
	_bridge(Vector3(29,1.4,-18),Vector3(70,1.4,-18),.7)
	_bridge(Vector3(70,1.4,-18),Vector3(70,1.4,-7),.18)
	_bridge(Vector3(70,1.4,-7),Vector3(70,1.32,5),0.,false)
	_bridge(Vector3(-36,1.675,-4),Vector3(-36,1.32,0),0.,false)
	_stall(Vector3(-49,1.8,-9.5),"market_bridge",Color("648c87"))
	_stall(Vector3(-59,1.5,-9.5),"workshop_bridge",Color("a78a5f"))
	_stall(Vector3(51,2.,-23.5),"gear_bridge",Color("bdab76"))
	# Landing bays connect directly to the walk deck; fishing lines clear the rails.
	for at: Vector3 in [Vector3(61,1.9,-22),Vector3(-43,1.8,-8.5)]:
		G.box(self,at-Vector3.UP*.12,Vector3(4.,.24,5.6),wood,true)
		var angler:=preload("res://scripts/world/working_fisher.gd").new();angler.position=at+Vector3(0,0,-1.6);angler.district=self;add_child(angler);fishers.append(angler)
	for x: float in [-61.,-49.,-37.,29.,42.,55.,69.]:
		var at:=Vector3(x,1.5,-5.5 if x<0. else -16.4)
		village._lamp(at,iron)
	for i: int in 2:
		var walker:=preload("res://scripts/world/village_resident.gd").new();walker.speed=1.1+float(i)*.15;walker.follow_terrain=false;walker.ground_sampler=deck_height
		walker.route.assign([Vector3(34+i*13,1.5,-18),Vector3(69.5,1.4,-18),Vector3(70,1.4,-8),Vector3(70,1.4,-18),Vector3(32,1.5,-18)])
		add_child(walker);walkers.append(walker)
	# Batch only fixed fittings. Residents, rod lines and catches stay dynamic.
	var excluded: Array[Node3D]=[];excluded.append_array(fishers);excluded.append_array(vendors);excluded.append_array(walkers)
	preload("res://scripts/world/static_batch.gd").build(self,excluded)
func _bridge(a: Vector3,b: Vector3,rise: float,rails: bool=true) -> void:
	bridges.append({"a":a,"b":b,"rise":rise})
	var length:=a.distance_to(b);var direction:=(b-a).normalized();var side:=Vector3(-direction.z,0,direction.x)
	var count:=ceili(length/.55);var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in count:
		var t:=float(i)/count;var u:=float(i+1)/count
		var p:=a.lerp(b,t)+Vector3.UP*sin(t*PI)*rise;var q:=a.lerp(b,u)+Vector3.UP*sin(u*PI)*rise
		for v: Vector3 in [p-side*1.8,q+side*1.8,p+side*1.8,p-side*1.8,q-side*1.8,q+side*1.8]:surface.add_vertex(v)
		var board:=G.box(self,(p+q)*.5-Vector3.UP*.09,Vector3(3.6,.18,p.distance_to(q)-.012),wood)
		board.rotation=Vector3(atan2(q.y-p.y,Vector2(q.x-p.x,q.z-p.z).length()),atan2(q.x-p.x,q.z-p.z),0)
		if i%7==0:
			for sign_value: float in [-1.,1.]:
				G.cylinder(self,p+side*sign_value*1.65-Vector3.UP*2.,.15,4.,trim,-1.,12)
				G.beam(self,p+side*sign_value*1.65-Vector3.UP*1.5,q+direction*2.5+side*sign_value*1.65-Vector3.UP*.2,.09,trim)
		if rails and i>2 and i<count-3:
			for sign_value: float in [-1.,1.]:
				# Shop and fishing bays stay open along the south edge.
				var south:=side.z*sign_value<0.
				var bay:=south and ((p.x>-63 and p.x< -39) or (p.x>47 and p.x<64))
				var warehouse_entry:=not south and p.x> -40. and p.x< -32. and absf(p.z+4.)<1.
				if bay or warehouse_entry:continue
				for height: float in [.45,1.05]:G.beam(self,p+side*sign_value*1.72+Vector3.UP*height,q+side*sign_value*1.72+Vector3.UP*height,.045,trim)
				if i%3==0:G.cylinder(self,p+side*sign_value*1.72+Vector3.UP*.52,.055,1.1,trim)
				var rail:=G.box(self,(p+q)*.5+side*sign_value*1.74+Vector3.UP*.6,Vector3(.08,1.15,p.distance_to(q)),iron,true);rail.rotation.y=atan2(q.x-p.x,q.z-p.z);rail.hide()
	surface.generate_normals();var mesh:=surface.commit();var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);add_child(body)
func _stall(at: Vector3,id: String,color: Color) -> void:
	G.box(self,at-Vector3.UP*.12,Vector3(6.,.24,7.6),wood,true)
	for i: int in 15:G.box(self,at+Vector3(-2.8+i*.4,.009,0),Vector3(.386,.018,7.6),wood)
	G.box(self,at+Vector3(0,.48,-.65),Vector3(3.8,.96,.9),trim,true)
	for i: int in 12:G.box(self,at+Vector3(-1.74+i*.316,.5,-.18),Vector3(.30,.86,.06),wood)
	G.box(self,at+Vector3(0,1.,-.65),Vector3(4.,.09,1.1),wood)
	for x: float in [-2.3,2.3]:
		for z: float in [-2.,1.]:G.cylinder(self,at+Vector3(x,1.45,z),.065,2.9,trim)
	var canvas:=ShaderMaterial.new();canvas.shader=preload("res://assets/shaders/harbor_canvas.gdshader");canvas.set_shader_parameter("fabric_tex",load("res://assets/textures/fabric_color.png"));canvas.set_shader_parameter("canvas_tint",color);canopies.append(canvas)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in 20:
		for z: int in 12:
			for corner: Vector2 in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
				var uv:=Vector2((x+corner.x)/20.,(z+corner.y)/12.)
				var px: float=(uv.x-.5)*5.;var pz: float=(uv.y-.5)*3.8-.5
				var py:=2.78+sin(uv.x*PI)*.42-sin(uv.y*PI)*.12
				surface.set_uv(uv);surface.add_vertex(Vector3(px,py,pz))
	surface.generate_normals();G.mesh_node(self,surface.commit(),canvas,at)
	G.beam(self,at+Vector3(0,3.2,-2.4),at+Vector3(0,3.2,1.4),.035,iron)
	for x: float in [-2.3,2.3]:G.beam(self,at+Vector3(x,2.9,-2.),at+Vector3(0,3.2,-2.4),.023,iron)
	var marker:=Marker3D.new();marker.position=at+Vector3(0,0,1.);add_child(marker);village.services[id]=marker
	var vendor:=preload("res://scripts/player/imported_angler.gd").new();vendor.position=at+Vector3(0,0,-1.6);vendor.rotation.y=PI;add_child(vendor);vendors.append(vendor)
	for i: int in 4:
		var p:=at+Vector3(-1.3+i*.85,1.,-.65)
		G.box(self,p,Vector3(.75,.08,.65),wood)
		if id=="market_bridge":
			var fish:=preload("res://scripts/creatures/marine_visual.gd").new();fish.species="mackerel";fish.scale=Vector3.ONE*.35;fish.position=p+Vector3.UP*.08;fish.rotation.z=PI*.5;fish.swimming=false;add_child(fish)
		else:
			var ring:=TorusMesh.new();ring.inner_radius=.13;ring.outer_radius=.2;ring.rings=24;ring.ring_segments=8;G.mesh_node(self,ring,trim,p+Vector3.UP*.04)
func _process(delta: float) -> void:
	for vendor: Node3D in vendors:vendor.update_animation(0.,false,delta)
	for canvas: ShaderMaterial in canopies:canvas.set_shader_parameter("wind_strength",preload("res://scripts/world/wave_field.gd").wind)
func receive_catch(data: Dictionary) -> void:
	if stock.size()<24:stock.append(data.duplicate(true))

func deck_height(at: Vector3) -> float:
	var height:=1.4;var closest:=10000.
	for bridge: Dictionary in bridges:
		var a:=Vector2(bridge.a.x,bridge.a.z);var b:=Vector2(bridge.b.x,bridge.b.z);var p:=Vector2(at.x,at.z)
		var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0.,1.)
		var distance:=p.distance_to(a.lerp(b,t))
		if distance<closest:
			closest=distance;height=lerpf(bridge.a.y,bridge.b.y,t)+sin(t*PI)*float(bridge.rise)
	return height+.03
