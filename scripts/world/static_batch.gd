extends RefCounted
## Merge static surfaces by shared material and spatial cell. Original collision
## bodies stay intact; animated birds, buoys and the water keep their own draws.

static func build(world: Node3D, dynamic_roots: Array[Node3D]) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(world, dynamic_roots, meshes)
	var groups: Dictionary = {}
	for instance: MeshInstance3D in meshes:
		var mat: Material = instance.material_override
		if not mat is StandardMaterial3D or instance.mesh == null:
			continue
		var p := instance.global_position
		var key := "%d:%d:%d" % [mat.get_instance_id(), floori(p.x / 40.0), floori(p.z / 40.0)]
		if not groups.has(key):
			groups[key] = {"instances": [], "material": mat}
		groups[key].instances.append(instance)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var instances: Array = group.instances
		if instances.size() < 2:
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for value: MeshInstance3D in instances:
			var relative := world.global_transform.affine_inverse() * value.global_transform
			for index: int in value.mesh.get_surface_count():
				surface.append_from(value.mesh, index, relative)
			value.visible = false
		var batch := MeshInstance3D.new()
		batch.name = "StaticSceneryBatch"
		batch.mesh = surface.commit()
		batch.material_override = group.material
		world.add_child(batch)

static func _collect(node: Node, excluded: Array[Node3D], output: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D:return
	if node is Node3D and not node.visible:return
	if node is Node3D and node in excluded:
		return
	if node is MeshInstance3D:
		output.append(node)
	for child: Node in node.get_children():
		_collect(child, excluded, output)
