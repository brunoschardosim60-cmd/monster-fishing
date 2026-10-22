extends Node3D
## The entire supplied harbor, at architectural scale, with its actual mesh collision.
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
var model: Node3D
var gear: Marker3D
var workshop: Marker3D
func _ready() -> void:
	model=preload("res://scripts/assets/external_model.gd").new();model.asset_path="res://assets/environment/harbor_dressed.glb";model.length_m=58.;model.waterline_m=0.;model.material_family="harbor";add_child(model)
	for mesh: MeshInstance3D in model.meshes:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();body.add_child(shape);mesh.add_child(body)
	var wood:=M.surface("weathered_wood",Color("b3a18b"),1.)
	# Accessible market pier links the existing seafront to the imported district.
	for x: int in range(1,81):
		var board_z:=16. if x<47 else 14.
		var board_width:=10. if x<47 else 4.
		G.box(self,Vector3(float(x),1.6,board_z),Vector3(.98,.18,board_width),wood,true)
		if x%4==0:
			for z: float in [16.3,19.7]:G.cylinder(self,Vector3(float(x),.2,z),.14,4.,wood)
	G.box(self,Vector3(80,1.6,12.5),Vector3(3.,.18,4.),wood,true)
	for data: Dictionary in [{"name":"Bazar do Porto Velho","p":Vector3(35,1.7,11.6),"gear":true},{"name":"Acessórios navais","p":Vector3(42,1.7,11.6),"gear":false}]:
		var at: Vector3=data.p
		G.box(self,at+Vector3(0,.55,-1.6),Vector3(3.,1.1,.8),wood,true)
		var canvas:=M.surface("fabric",Color("597b76") if data.gear else Color("b78e60"),2.)
		G.box(self,at+Vector3(0,2.4,-1.5),Vector3(3.6,.08,2.5),canvas)
		for side: float in [-1.,1.]:G.cylinder(self,at+Vector3(side*1.6,1.15,-1.5),.055,2.3,wood)
		var marker:=Marker3D.new();marker.position=at;add_child(marker)
		if data.gear:gear=marker
		else:workshop=marker
		G.label(self,data.name,at+Vector3(0,2.2,-2.8),18)
		var vendor:=preload("res://scripts/player/imported_angler.gd").new();vendor.position=at+Vector3(0,0,-2.3);vendor.rotation.y=PI;add_child(vendor)
		vendor.set_meta("shop_idle",true)
func _process(delta: float) -> void:
	for child: Node in get_children():
		if child.has_meta("shop_idle"):child.update_animation(0.,false,delta)
