extends RefCounted
## Sculpted meshes for the large sea animals, built once and cached: smooth lathes for bodies, tapered tubes for
## tentacles (bent in the vertex shader), a domed carapace, flipper blades and a ray disc. UVs carry the parameters the
## shaders use for patterns (scutes, suckers, spots) and for animation.
static var _cache: Dictionary={}

static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals();st.generate_tangents()
	return st.commit()

## Surface of revolution around +Y. profile: Vector2(radius, height) from bottom to top. squash scales x/z.
static func lathe(key: String,profile: PackedVector2Array,segments: int=28,squash: Vector2=Vector2.ONE) -> ArrayMesh:
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:=profile.size()
	for r: int in rows-1:
		for s: int in segments:
			var quad: Array=[[r,s],[r+1,s],[r+1,s+1],[r,s],[r+1,s+1],[r,s+1]]
			for c: Array in quad:
				var p:=profile[int(c[0])];var a:=float(int(c[1]))/float(segments)*TAU
				st.set_uv(Vector2(float(int(c[1]))/float(segments),float(int(c[0]))/float(rows-1)))
				st.add_vertex(Vector3(cos(a)*p.x*squash.x,p.y,sin(a)*p.x*squash.y))
	var mesh:=_commit(st);_cache[key]=mesh
	return mesh

## Straight tapered tube along +Y (0..length). UV.y = position along (0 base, 1 tip), UV.x = angle around.
static func tube(key: String,length: float,r0: float,r1: float,rings: int=26,segments: int=12) -> ArrayMesh:
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: int in rings:
		for s: int in segments:
			for c: Vector2i in [Vector2i(r,s),Vector2i(r+1,s),Vector2i(r+1,s+1),Vector2i(r,s),Vector2i(r+1,s+1),Vector2i(r,s+1)]:
				var t:=float(c.x)/float(rings);var a:=float(c.y)/float(segments)*TAU
				var rad:=lerpf(r0,r1,pow(t,.8))*(1. if c.x<rings else 0.)
				st.set_uv(Vector2(float(c.y)/float(segments),t))
				st.add_vertex(Vector3(cos(a)*rad,t*length,sin(a)*rad))
	var mesh:=_commit(st);_cache[key]=mesh
	return mesh

## Turtle carapace: an oval dome (front at -Z) with a low keel, flared and scalloped rim; plus the flat plastron.
## UV = normalised (x, z) over the shell, used by the scute shader.
static func carapace(key: String,length: float,width: float,height: float) -> ArrayMesh:
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=14;var segs:=40
	var point:=func(v: float,u: float) -> Vector3:
		var a:=u*TAU
		var rim:=1.+.035*sin(a*13.)*smoothstep(.15,.6,absf(sin(a*.5)))  # scalloped back edge
		var ox:=sin(a)*width*.5*v*rim;var oz:=-cos(a)*length*.5*v*rim*(1.+.06*cos(a))
		var dome:=height*pow(maxf(0.,1.-v*v),.65)+height*.06*(1.-absf(sin(a)))*(1.-v)  # keel along the spine
		var flare:=-height*.12*smoothstep(.82,1.,v)
		return Vector3(ox,dome+flare,oz)
	for r: int in rings:
		for s: int in segs:
			for c: Vector2i in [Vector2i(r,s),Vector2i(r,s+1),Vector2i(r+1,s+1),Vector2i(r,s),Vector2i(r+1,s+1),Vector2i(r+1,s)]:
				var v:=float(c.x)/float(rings);var u:=float(c.y)/float(segs)
				var p: Vector3=point.call(v,u)
				st.set_uv(Vector2(p.x/(width*.5),p.z/(length*.5)))
				st.add_vertex(p)
	# Plastron: a slightly smaller flat oval just under the rim, facing down.
	for s: int in segs:
		var a0:=float(s)/float(segs)*TAU;var a1:=float(s+1)/float(segs)*TAU
		var p0:=Vector3(sin(a0)*width*.44,-height*.12,-cos(a0)*length*.44);var p1:=Vector3(sin(a1)*width*.44,-height*.12,-cos(a1)*length*.44)
		for p: Vector3 in [Vector3(0,-height*.16,0),p1,p0]:
			st.set_uv(Vector2(9.,9.));st.add_vertex(p)
	var mesh:=_commit(st);_cache[key]=mesh
	return mesh

## Flipper blade along +X from the shoulder: tapered, swept back (+Z) towards the tip, thin and rounded.
static func flipper(key: String,length: float,chord: float,sweep: float) -> ArrayMesh:
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n:=12;var m:=10
	var point:=func(i: int,j: int) -> Vector3:
		var s:=float(i)/float(n);var a:=float(j)/float(m)*TAU
		var w:=chord*(.55+.45*sin(PI*minf(1.,s*1.4+.15)))*(1.-s*.75)
		var th:=chord*.16*(1.-s*.8)
		return Vector3(s*length,sin(a)*th*.5,cos(a)*w*.5+sweep*s*s)
	for i: int in n:
		for j: int in m:
			for c: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var p: Vector3=point.call(c.x,c.y)
				st.set_uv(Vector2(float(c.x)/float(n),float(c.y)/float(m)));st.add_vertex(p)
	var mesh:=_commit(st);_cache[key]=mesh
	return mesh

## Ray disc: a diamond with a rounded front, thick at the middle, thin at the wing tips. Front at -Z.
## UV = (x / half span, z / half length). The vertex shader flaps or undulates the wings from UV.x.
static func ray_disc(key: String,span: float,length: float,thickness: float) -> ArrayMesh:
	if _cache.has(key):return _cache[key]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx:=24;var nz:=16
	var outline:=func(zn: float) -> float:
		# Half width at a normalised length position (-1 front, 1 back): widest a little ahead of the middle.
		# Rounded diamond: the wing tips sit a little ahead of the middle, the back tapers to the tail.
		var k:=zn+.15
		return clampf(1.-pow(absf(k)/(1.15 if k<0. else 1.0),1.25),0.,1.)
	for side: float in [1.,-1.]:
		for i: int in nx:
			for k: int in nz:
				for c: Vector2i in [Vector2i(i,k),Vector2i(i+1,k),Vector2i(i+1,k+1),Vector2i(i,k),Vector2i(i+1,k+1),Vector2i(i,k+1)]:
					var zn:=-1.+2.*float(c.y)/float(nz)
					var xn:=(-1.+2.*float(c.x)/float(nx))*float(outline.call(zn))
					var t:=thickness*(1.-xn*xn)*(1.-zn*zn*.6)
					var p:=Vector3(xn*span*.5,side*t*.5,zn*length*.5)
					st.set_uv(Vector2(xn,zn));st.set_uv2(Vector2(side,0.))
					st.add_vertex(p)
		# Flip winding for the underside so both faces point outward.
	var arrays:=st.commit_to_arrays()
	var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv2: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	var count:=verts.size()
	var st2:=SurfaceTool.new();st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for tri: int in count/3:
		var order:=[0,1,2] if uv2[tri*3].x>0. else [0,2,1]
		for o: int in order:
			var idx:=tri*3+o
			st2.set_uv(uv[idx]);st2.set_uv2(uv2[idx]);st2.add_vertex(verts[idx])
	var mesh:=_commit(st2);_cache[key]=mesh
	return mesh
