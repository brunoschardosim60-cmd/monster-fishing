extends Node3D
## Reusable visual wrapper. Controllers own simple collision and gameplay markers.
@export_file("*.glb") var asset_path: String
@export var length_m: float = 9.0
@export var heading_degrees: float = 90.0
@export_enum("boat", "harbor", "creature", "original") var material_family: String = "boat"
@export var waterline_m: float = .65
var model: Node3D
var bounds: AABB
var meshes: Array[MeshInstance3D]=[]
const Materials=preload("res://scripts/visuals/materials.gd")

func _ready() -> void:
	if not ResourceLoader.exists(asset_path):
		push_warning("Modelo indisponível: "+asset_path); return
	model=load(asset_path).instantiate(); add_child(model)
	_collect(model)
	var first:=true
	for part: MeshInstance3D in meshes:
		var box:=model.global_transform.affine_inverse()*part.global_transform*part.get_aabb()
		bounds=box if first else bounds.merge(box); first=false
	var factor:=length_m/maxf(bounds.size.x,bounds.size.z)
	if material_family=="original": factor=length_m/bounds.size.y
	model.scale=Vector3.ONE*factor
	model.rotation_degrees.y=heading_degrees
	model.position=-(model.basis*Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))-Vector3.UP*waterline_m
	for part: MeshInstance3D in meshes:
		part.visibility_range_end=1100. if material_family=="harbor" else 650.
		part.visibility_range_end_margin=50.
		if material_family=="boat":
			var box:=part.get_aabb(); var height:=box.get_center().y
			var kind:="paint"; var tint:=Color("e2d2ad")
			if height<.13: tint=Color("1c4854")
			elif height>.36: tint=Color("364c50")
			elif box.size.y<.025 and height<.19: kind="teak"; tint=Color("c79e6e")
			elif box.size.y>.3: tint=Color("d9a463")
			part.material_override=Materials.surface(kind,tint,3.,false)
			if part.name in ["tripo_part_8","tripo_part_11","tripo_part_13","tripo_part_17","tripo_part_18"]:
				part.material_override=Materials.surface("paint",Color("23343a"),5.,false)
		elif material_family=="creature":
			part.material_override=Materials.surface("granite",Color("ae9c76"),5.,false)
		elif material_family=="harbor":
			if "dressed" in asset_path:
				for surface: int in part.mesh.get_surface_count():
					var source: Material=part.get_active_material(surface)
					var id: String=source.resource_name
					var tint:=Color("bdb59c");var kind:="paint"
					if "Roof" in id:kind="weathered_wood";tint=Color("a87753")
					elif "Timber" in id:kind="weathered_wood";tint=Color("a59779")
					elif "Stone" in id:kind="granite";tint=Color("aeb1a4")
					part.set_surface_override_material(surface,Materials.surface(kind,tint,.6,true))
				continue
			var material:=Materials.surface("weathered_wood",Color("b2a28a"),2.,false)
			part.material_override=material
	if material_family in ["boat","harbor","creature"]:
		preload("res://scripts/world/static_batch.gd").build(model,[])

func _collect(node: Node) -> void:
	if node is MeshInstance3D: meshes.append(node)
	for child: Node in node.get_children(): _collect(child)
