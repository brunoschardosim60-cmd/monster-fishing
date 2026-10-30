extends RefCounted
## The ships built in Blender (tools/blender/shipwright.py): loads a GLB, gives each part the game's
## materials by the name it carries (planked hull with paint and wear, decks in teak, sailcloth with
## seams and patches, rope, iron, brass, glowing stern windows), and reads the layout JSON beside it
## (decks, helm, cabin, stairs, mast) so the boat systems know where things are.
const M=preload("res://scripts/visuals/materials.gd")
const KINDS: Dictionary={"chalupa":"res://assets/boats/ships/chalupa.glb","galeao_sot":"res://assets/boats/ships/galeao.glb","bergantim_sot":"res://assets/boats/ships/bergantim.glb","submarino_sot":"res://assets/boats/ships/submarino.glb"}
static var _layouts: Dictionary={}
static var _mats: Dictionary={}

static func has(kind: String) -> bool:return KINDS.has(kind)

static func layout(kind: String) -> Dictionary:
	if _layouts.has(kind):return _layouts[kind]
	var path: String=str(KINDS[kind]).replace(".glb",".json")
	var data: Dictionary={}
	var f:=FileAccess.open(path,FileAccess.READ)
	if f!=null:data=JSON.parse_string(f.get_as_text());f.close()
	_layouts[kind]=data
	return data

static func v3(a: Array) -> Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func _material(name: String) -> Material:
	var key: String=name.get_slice(".",0)
	if _mats.has(key):return _mats[key]
	var m: Material
	match key:
		"Casco":
			var s:=ShaderMaterial.new();s.shader=preload("res://assets/shaders/painted_hull.gdshader")
			s.set_shader_parameter("strake",.22);s.set_shader_parameter("wear",.45);s.set_shader_parameter("wood_tint",Color("6b4a2c"));m=s
		"Conves":m=M.surface("teak",Color("b08a5a"),.9,false)
		"Madeira":m=M.surface("weathered_wood",Color("8a6038"),1.1,false)
		"MadeiraEscura":m=M.surface("weathered_wood",Color("4a3424"),1.1,false)
		"Faixa":
			var f:=StandardMaterial3D.new();f.albedo_color=Color("c9a23a");f.roughness=.55;m=f
		"Vela":
			var v:=ShaderMaterial.new();v.shader=preload("res://assets/shaders/sail_cloth.gdshader");m=v
		"Corda":
			var c:=StandardMaterial3D.new();c.albedo_color=Color("8a7656");c.roughness=.95;m=c
		"Ferro":
			var i:=StandardMaterial3D.new();i.albedo_color=Color("2a2826");i.roughness=.45;i.metallic=.6;m=i
		"Latao","Ouro":
			var b:=StandardMaterial3D.new();b.albedo_color=Color("c49a45") if key=="Latao" else Color("e0b040");b.roughness=.3;b.metallic=.9;m=b
		"Vidro":
			var g:=StandardMaterial3D.new();g.albedo_color=Color("2a2418");g.roughness=.1;g.metallic=.2
			g.emission_enabled=true;g.emission=Color("ffb860");g.emission_energy_multiplier=.2;m=g
		_:
			var d:=StandardMaterial3D.new();d.albedo_color=Color("777777");m=d
	_mats[key]=m
	return m

## Night glow of the stern windows and lanterns (0 day … 1 night).
static func set_night(value: float) -> void:
	var g: StandardMaterial3D=_material("Vidro")
	g.emission_energy_multiplier=lerpf(.15,1.3,value)

## The ship's model, with materials applied. Meta: "sails" (sail meshes), "wheel" (the helm wheel node,
## spun about its axis by the boat), "layout" (the JSON).
static func build(kind: String) -> Node3D:
	var scene: PackedScene=load(KINDS[kind])
	var root: Node3D=scene.instantiate()
	root.name="Navio_"+kind
	var sails: Array=[]
	var wheel_parts: Array[Node3D]=[]
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mi: MeshInstance3D=node
		for sidx: int in mi.mesh.get_surface_count():
			var src: Material=mi.mesh.surface_get_material(sidx)
			mi.set_surface_override_material(sidx,_material(src.resource_name if src!=null else ""))
		var n: String=mi.name
		if n.begins_with("Vela") or n.begins_with("Bujarrona") or n.begins_with("Giba"):sails.append(mi)
		if n.begins_with("Roda") or n.begins_with("Raio") or n.begins_with("Cubo"):wheel_parts.append(mi)
		mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mi.get_aabb().size.length()>3. else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Square sails turn with their yard about the mast (bracing) and hoist from the yard down; each gets
	# its pivot point (mast, yard height) as "tack", and its yard rides along (sail_rig.gd).
	var lay0: Dictionary=layout(kind)
	var mast: Vector3=v3(lay0.mast) if lay0.has("mast") else Vector3.ZERO
	var yards: Array=[]
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var n2: String=node.name
		if n2.begins_with("Verga") or n2.begins_with("Lais"):yards.append(node)
	var rigged: Array=[]
	for sail_mi in sails:
		var mi: MeshInstance3D=sail_mi
		if not mi.name.begins_with("Vela_"):continue
		var box: AABB=mi.transform*mi.get_aabb()
		# One mast: its position from the layout. Several (galleon): the sail hangs .5 m before its own mast.
		var tack:=Vector3(mast.x,box.end.y,mast.z) if lay0.has("mast") else Vector3(0.,box.end.y,box.get_center().z+.5)
		mi.set_meta("tack",tack);mi.set_meta("square",true)
		for y: Node3D in yards:
			var yc: Vector3=y.position if y.position!=Vector3.ZERO else (y as MeshInstance3D).transform*(y as MeshInstance3D).get_aabb().get_center()
			if absf(yc.y-box.end.y)<.6 and absf(yc.z-tack.z)<2.:y.set_meta("from",tack)
		rigged.append(mi)
	root.set_meta("booms",yards)
	root.set_meta("sails",rigged);root.set_meta("layout",layout(kind))
	root.set_meta("rails",[]);root.set_meta("seats",[]);root.set_meta("oars",[])
	# The wheel parts are gathered under one pivot on the wheel's axle so the boat can turn it.
	var lay: Dictionary=layout(kind)
	if lay.has("wheel") and not wheel_parts.is_empty():
		var mount:=Node3D.new();mount.name="EixoDoLeme";root.add_child(mount)
		mount.position=v3(lay.wheel);mount.rotation.x=PI*.5  # the spin node's Y runs along the axle
		var spin:=Node3D.new();spin.name="RodaDoLeme";mount.add_child(spin)
		for part: Node3D in wheel_parts:
			var t: Transform3D=_to_root(part,root)
			part.owner=null;part.get_parent().remove_child(part);spin.add_child(part);part.transform=mount.transform.affine_inverse()*t
		root.set_meta("wheel",spin)
	return root

static func _to_root(node: Node3D,root: Node3D) -> Transform3D:
	var t: Transform3D=node.transform;var p: Node=node.get_parent()
	while p!=null and p!=root:
		if p is Node3D:t=(p as Node3D).transform*t
		p=p.get_parent()
	return t
