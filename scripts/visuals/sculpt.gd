extends RefCounted
## Rounded engineering shapes and smooth organic lofts, authored in metres.
static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size*.5
	var r := minf(radius,minf(h.x,minf(h.y,h.z))*.9)
	for axis: int in range(3):
		var u := (axis+1)%3
		var v := (axis+2)%3
		for side: float in [-1.,1.]:
			var us := [-h[u],-h[u]+r,h[u]-r,h[u]]
			var vs := [-h[v],-h[v]+r,h[v]-r,h[v]]
			for i: int in range(3):
				for j: int in range(3):
					var points: Array[Vector3]=[]
					for ij: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
						var p := Vector3.ZERO
						p[axis]=h[axis]*side
						p[u]=us[ij.x]
						p[v]=vs[ij.y]
						points.append(p)
					for index: int in ([0,2,1,0,3,2] if side>0 else [0,1,2,0,2,3]):
						var p := points[index]
						var core := p.clamp(-h+Vector3.ONE*r,h-Vector3.ONE*r)
						var normal := (p-core).normalized()
						st.set_normal(normal)
						st.set_uv(Vector2(p[u]/size[u]+.5,p[v]/size[v]+.5))
						st.add_vertex(core+normal*r)
	st.index()
	return st.commit()

static func ellipsoid(parent: Node3D,position: Vector3,radii: Vector3,mat: Material) -> MeshInstance3D:
	var sphere:=SphereMesh.new()
	sphere.radius=1.
	sphere.height=2.
	sphere.radial_segments=32
	sphere.rings=20
	var node:=MeshInstance3D.new()
	node.mesh=sphere
	node.material_override=mat
	node.position=position
	node.scale=radii
	parent.add_child(node)
	return node
