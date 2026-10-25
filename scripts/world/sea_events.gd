extends Node3D
## Rare creatures of the open sea. Every few minutes a whale crosses the water nearby, or (rarer) a kraken rises beside the boat.
## Each one stays for about a minute and then leaves. The world map shows them while they are out.
signal event_started(text: String)
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Flora=preload("res://scripts/world/biome_flora.gd")
const WHALE_SPEED: float=2.6
const WHALE_LIFE: float=70.
const KRAKEN_LIFE: float=62.

var boat: Node3D
var clock: float=0.
var next_at: float=150.
var current: Node3D=null
var kind: String=""
var lived: float=0.
var rng:=RandomNumberGenerator.new()
var tentacles: Array[Node3D]=[]
var spawned: int=0

func _ready() -> void:
	rng.seed=7741

func set_player_boat(value: Node3D) -> void:
	boat=value

func _process(delta: float) -> void:
	if boat==null: return
	clock+=delta
	if current!=null:
		lived+=delta
		if kind=="whale":
			current.position+=-current.basis.z*WHALE_SPEED*delta
			if lived>WHALE_LIFE: _retire()
		else:
			_animate_kraken(lived)
			if lived>KRAKEN_LIFE: _retire()
		return
	if clock>=next_at:
		_spawn()

func _retire() -> void:
	current.queue_free();current=null;kind=""
	next_at=clock+rng.randf_range(300.,540.)

## A point in open water 260–420 m from the boat, or Vector3.INF if none is found.
func _open_point() -> Vector3:
	for attempt: int in 30:
		var angle:=rng.randf()*TAU;var dist:=rng.randf_range(260.,420.)
		var p:=boat.global_position+Vector3(cos(angle),0.,sin(angle))*dist
		if Layout.coast(Vector2(p.x,p.z)).x>80.:return Vector3(p.x,0.,p.z)
	return Vector3.INF

func _spawn() -> void:
	var at:=_open_point()
	if at==Vector3.INF:
		next_at=clock+20.;return
	spawned+=1
	lived=0.
	if rng.randf()<.35:
		kind="kraken";current=_build_kraken();current.position=at+Vector3(0,-9.,0)
		event_started.emit("Algo se move nas profundezas... um kraken está perto do seu barco!")
	else:
		kind="whale";current=_build_whale()
		var heading:=Vector3(cos(rng.randf()*TAU),0.,0.);heading=heading.normalized()
		current.rotation.y=atan2(-heading.x,-heading.z)
		current.position=at
		event_started.emit("Uma baleia cruza as águas ao seu redor.")
	add_child(current)

func _build_whale() -> Node3D:
	var holder:=Node3D.new();holder.name="Baleia"
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark:=Color("2b3a4a");var belly:=Color("c9d6dc")
	Flora._blob(st,Vector3(0,0,0),Vector3(1.8,1.6,6.2),belly,dark)
	Flora._frustum(st,Vector3(0,0,-6.0),Vector3(0,.4,-8.4),1.0,.25,dark,dark,6)
	Flora._frustum(st,Vector3(0,.2,-8.4),Vector3(0,.25,-9.2),.6,.1,dark,dark,5)
	st.generate_normals()
	var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=Flora.mat();holder.add_child(node)
	return holder

func _build_kraken() -> Node3D:
	var holder:=Node3D.new();holder.name="Kraken";tentacles.clear()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var purple:=Color("3a1f4f");var glow:=Color("8a5fd0")
	Flora._blob(st,Vector3(0,0,0),Vector3(3.2,2.6,3.2),purple,glow)
	st.generate_normals()
	var body:=MeshInstance3D.new();body.mesh=st.commit();body.material_override=Flora.mat();holder.add_child(body)
	for i: int in 8:
		var a:=float(i)*TAU/8.
		var pivot:=Node3D.new();pivot.position=Vector3(cos(a)*2.4,-.6,sin(a)*2.4);holder.add_child(pivot)
		var ts:=SurfaceTool.new();ts.begin(Mesh.PRIMITIVE_TRIANGLES)
		Flora._frustum(ts,Vector3.ZERO,Vector3(0,-7.5,0),.7,.1,purple,glow,6)
		ts.generate_normals()
		var tentacle:=MeshInstance3D.new();tentacle.mesh=ts.commit();tentacle.material_override=Flora.mat();pivot.add_child(tentacle)
		pivot.set_meta("base",Vector3(sin(a)*.5,0.,-cos(a)*.5))
		tentacles.append(pivot)
	for side: float in [-1.,1.]:
		var eye:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.32;sphere.height=.64;eye.mesh=sphere
		var eye_mat:=StandardMaterial3D.new();eye_mat.albedo_color=Color("ffd34e");eye_mat.emission_enabled=true;eye_mat.emission=Color("ffd34e");eye_mat.emission_energy_multiplier=2.;eye.material_override=eye_mat
		eye.position=Vector3(side*1.1,.9,2.7);holder.add_child(eye)
	return holder

func _animate_kraken(t: float) -> void:
	if current==null:return
	var rise:=smoothstep(0.,6.,t)
	var sink:=smoothstep(KRAKEN_LIFE-8.,KRAKEN_LIFE,t)
	current.position.y=lerpf(-9.,-1.2,rise)-sink*8.
	for i: int in tentacles.size():
		var base: Vector3=tentacles[i].get_meta("base")
		var wave:=sin(t*1.4+float(i)*.8)*.22
		tentacles[i].rotation=base+Vector3(wave,0.,-wave*.5)
	current.rotation.y=t*.05
