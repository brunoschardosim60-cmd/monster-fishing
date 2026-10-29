extends Node3D
## The boatyard's sales pier: every boat the yard sells lies moored bow-in along the far side of the yard
## pier, afloat and riding the swell, each with a board on the pier giving its name and price (or "SEU"
## when you own it). Walk up to a board and press E to buy that boat or switch to it: the yard brings
## the boat you take round to the berth and keeps the other one here.
const HullClasses=preload("res://scripts/boats/hull_classes.gd")
const Models=preload("res://scripts/boats/vessel_models.gd")
const Economy=preload("res://scripts/inventory/harbor_economy.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const G=preload("res://scripts/world/geometry.gd")
const ORDER: Array[String]=["canoa","aurora","veloz","expedicao","traineira","veleiro","escuna"]
const REACH: float=3.2

## id -> {node, board (Label3D), at (pier point, world), draft}
var displays: Dictionary={}
var _phase: float=0.
var pontoon_length: float=0.

## A floating pontoon runs from the pier head (`to`) away from the berth side (`side`); the boats lie
## bow-in along its seaward edge, in deep water, smallest nearest the pier.
func build(from: Vector2,to: Vector2,side: Vector2) -> void:
	var out:=(to-from).normalized()
	var away:=-side
	var bow_yaw: float=atan2(out.x,out.y)
	var wood:=preload("res://scripts/visuals/materials.gd").surface("weathered_wood",Color("8f7a5e"),1.5)
	var dark:=G.material(Color("4a3a2a"),.9)
	var rope:=G.material(Color("c8b58a"),.9)
	var along: float=2.6
	var slots: Array=[]
	for id: String in ORDER:
		var data: Dictionary=Economy.BOATS[id]
		var spec: Dictionary=HullClasses.spec(str(data.get("model","tripo")))
		var beam: float=float(spec.beam)*float(data.scale)
		along+=beam*.5;slots.append(along);along+=beam*.5+1.6
	pontoon_length=along
	var root:=to+away*1.5
	var mid:=root+away*along*.5
	var deck:=G.box(self,Vector3(mid.x,1.45,mid.y),Vector3(2.4,.25,along),wood,true);deck.rotation.y=atan2(away.x,away.y)
	for i: int in int(along/4.)+1:
		var q:=root+away*minf(float(i)*4.,along)
		for s: float in [-1.,1.]:G.cylinder(self,Vector3(q.x+out.x*s*1.1,.9,q.y+out.y*s*1.1),.11,1.3,dark)
	var head:=G.label(self,"BARCOS À VENDA",Vector3(root.x+away.x*1.2,3.7,root.y+away.y*1.2),34);head.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;head.rotation=Vector3.ZERO;head.visibility_range_end=60.
	for k: int in ORDER.size():
		var id: String=ORDER[k]
		var data: Dictionary=Economy.BOATS[id]
		var model: String=str(data.get("model","tripo"))
		var spec: Dictionary=HullClasses.spec(model)
		var scale_value: float=float(data.scale)
		var beam: float=float(spec.beam)*scale_value;var length: float=float(spec.get("model_length",spec.length))*scale_value
		var slot:=root+away*float(slots[k])
		var centre:=slot+out*(1.2+.8+length*.5)
		var holder:=Node3D.new();holder.name="Mostra_"+id
		holder.position=Vector3(centre.x,0.,centre.y);holder.rotation.y=bow_yaw;add_child(holder)
		var body: Node3D
		if model=="tripo":
			body=preload("res://scenes/models/fishing_boat_model.tscn").instantiate();body.set("livery",[data.hull,data.top]);holder.add_child(body)
		else:
			body=Models.build(str(spec.kind),float(spec.model_length),11);holder.add_child(body)
			# Sails stowed while she is for sale.
			for sail: Node3D in body.get_meta("sails",[]):sail.visible=false
		body.scale=Vector3.ONE*scale_value
		# Two mooring lines from the bow to cleats on the pontoon.
		for s: float in [-1.,1.]:
			var a:=Vector3(s*beam*.25,float(spec.deck.y)*scale_value+.15,-length*.47)
			var cleat:=slot+away*s*minf(beam*.4,1.)+out*1.1
			G.beam(holder,a,_local(holder,Vector3(cleat.x,1.6,cleat.y)),.025,rope)
		var board:=Label3D.new();board.name="Placa_"+id
		board.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;board.font_size=40;board.pixel_size=.0065
		board.outline_size=10;board.modulate=Color("fff0cf");board.outline_modulate=Color("193f3d")
		board.visibility_range_end=45.
		var at:=slot+out*.7
		board.position=Vector3(at.x,3.3,at.y);add_child(board)
		G.cylinder(self,Vector3(at.x,2.1,at.y),.06,1.2,dark)
		displays[id]={"node":holder,"board":board,"at":Vector3(at.x,1.6,at.y),"draft":float(spec.draft),"length":length}
	_phase=float(get_instance_id()%97)

func _local(holder: Node3D,world_point: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP,holder.rotation.y),holder.position).affine_inverse()*world_point

## Boards follow what you own and use; the boat you are using is not moored here (it is wherever you left it).
func refresh(inventory: RefCounted) -> void:
	for id: String in displays:
		var d: Dictionary=displays[id]
		var title: String=str(Economy.BOATS[id].title).get_slice(" ·",0)
		var using: bool=str(inventory.boat_id)==id
		(d.node as Node3D).visible=not using;(d.board as Label3D).visible=not using
		var state: String="EM USO" if using else ("SEU · E para usar" if id in inventory.owned_boats else "%d moedas · E para comprar"%int(Economy.BOATS[id].price))
		(d.board as Label3D).text="%s\n%s"%[title.to_upper(),state]

## The board within reach of a walker, or "".
func nearest(at: Vector3) -> String:
	var best:="";var best_d:=REACH
	for id: String in displays:
		var d: float=Vector2(at.x,at.z).distance_to(Vector2(displays[id].at.x,displays[id].at.z))
		if d<best_d and absf(at.y-float(displays[id].at.y))<2.5:best=id;best_d=d
	return best

func _process(delta: float) -> void:
	_phase+=delta
	var cam:=get_viewport().get_camera_3d() if get_viewport()!=null else null
	for id: String in displays:
		var d: Dictionary=displays[id];var node: Node3D=d.node
		if not node.visible:continue
		if cam!=null and cam.global_position.distance_squared_to(node.global_position)>220.*220.:continue
		var p:=node.global_position
		var h: float=Waves.height_at(p)
		node.position.y=h-float(d.draft)
		var ahead: float=Waves.height_at(p-node.global_basis.z*2.)-Waves.height_at(p+node.global_basis.z*2.)
		var beside: float=Waves.height_at(p+node.global_basis.x*1.2)-Waves.height_at(p-node.global_basis.x*1.2)
		node.rotation.x=lerpf(node.rotation.x,clampf(ahead*.2,-.12,.12),delta*2.)
		node.rotation.z=lerpf(node.rotation.z,clampf(-beside*.35,-.15,.15)+sin(_phase*.9+float(id.length()))*.012,delta*2.)
