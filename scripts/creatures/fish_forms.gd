extends RefCounted
## Parametric fish bodies. One ArrayMesh per form (cached), painted with vertex colours, head towards +X,
## tail towards -X, body length 1 (x from -0.5 to 0.5; tails extend beyond). Callers scale by `length`.
## Add a species: add an entry to FORMS, a data/fish/<id>.tres, and (optionally) a school in marine_ecosystem.gd.
const SEGMENTS: int=16
const RINGS: int=30
const SHADER=preload("res://assets/shaders/fish_form.gdshader")
## length: metres. speed: cruise m/s. profile: [x, half-height, half-width] from tail to nose.
## pattern: none | bars | stripe | spots. tail: forked | lunate | rounded | shark | frill.
## fins: dorsal/anal entries are [x_start, x_end, height, apex 0..1]. belly_ratio < 1 flattens the underside.
const FORMS: Dictionary={
	"sardine":{"length":.55,"speed":2.2,"profile":[[-.5,0,0],[-.42,.03,.02],[-.28,.06,.035],[-.05,.1,.055],[.15,.115,.06],[.33,.09,.048],[.46,.04,.022],[.5,0,0]],
		"back":"2f7f9e","belly":"e8f2f3","pattern":"spots","pattern_color":"173a52","pattern_count":6,"fin":"8fb5c2","tail":"forked","tail_span":.3,"tail_len":.17,
		"dorsal":[[-.12,.1,.1,.4]],"anal":[[-.2,-.02,.05,.5]],"pectoral":.08},
	"seabass":{"length":1.05,"speed":1.5,"profile":[[-.5,0,0],[-.42,.04,.025],[-.28,.09,.05],[-.05,.15,.08],[.15,.165,.085],[.33,.12,.065],[.46,.05,.03],[.5,0,0]],
		"back":"6e7a52","belly":"e5dcb4","pattern":"stripe","pattern_color":"4c5a3a","fin":"8a8f5d","tail":"rounded","tail_span":.3,"tail_len":.17,
		"dorsal":[[-.2,.1,.13,.6],[.12,.28,.08,.4]],"anal":[[-.22,-.04,.07,.5]],"pectoral":.11},
	"sargo":{"length":.6,"speed":1.3,"profile":[[-.5,0,0],[-.42,.04,.025],[-.3,.1,.04],[-.05,.2,.06],[.15,.22,.065],[.33,.16,.05],[.46,.06,.025],[.5,0,0]],
		"back":"d9c46c","belly":"f3efd0","pattern":"bars","pattern_color":"1d1d1d","pattern_count":5,"fin":"c9b455","tail":"forked","tail_span":.3,"tail_len":.17,
		"dorsal":[[-.28,.22,.14,.5]],"anal":[[-.25,.0,.08,.5]],"pectoral":.1,"belly_ratio":.85},
	"cirurgiao":{"length":.62,"speed":1.4,"profile":[[-.5,0,0],[-.42,.05,.02],[-.3,.12,.035],[-.05,.22,.05],[.15,.24,.055],[.33,.17,.045],[.46,.06,.022],[.5,0,0]],
		"back":"2b63d8","belly":"4fa0ee","pattern":"stripe","pattern_color":"14224f","fin":"f2d23c","tail":"lunate","tail_span":.38,"tail_len":.2,
		"dorsal":[[-.32,.28,.15,.45]],"anal":[[-.28,.05,.1,.5]],"pectoral":.1,"belly_ratio":.9},
	"pargo":{"length":.9,"speed":1.4,"profile":[[-.5,0,0],[-.42,.04,.025],[-.28,.1,.05],[-.05,.18,.08],[.15,.2,.09],[.33,.15,.07],[.46,.06,.03],[.5,0,0]],
		"back":"c1382f","belly":"f0b8a8","pattern":"none","fin":"b02d28","tail":"forked","tail_span":.32,"tail_len":.18,
		"dorsal":[[-.24,.14,.14,.55]],"anal":[[-.22,-.02,.08,.5]],"pectoral":.11},
	"baiacu":{"length":1.15,"speed":.9,"profile":[[-.5,0,0],[-.44,.03,.025],[-.34,.11,.09],[-.1,.27,.2],[.12,.31,.23],[.33,.24,.18],[.46,.1,.07],[.5,0,0]],
		"back":"b3a46a","belly":"f4eed4","pattern":"spots","pattern_color":"5b4a24","pattern_count":7,"fin":"d6c98a","tail":"rounded","tail_span":.22,"tail_len":.15,
		"dorsal":[[-.28,-.12,.1,.5]],"anal":[[-.28,-.14,.09,.5]],"pectoral":.12,"spines":true},
	"tubarao_recife":{"length":2.3,"speed":1.8,"profile":[[-.5,0,0],[-.4,.03,.03],[-.25,.07,.06],[-.05,.1,.085],[.18,.095,.09],[.36,.065,.07],[.47,.025,.035],[.5,0,0]],
		"back":"6b7a86","belly":"eef0ee","pattern":"none","fin":"5d6a74","tail":"shark","tail_span":.34,"tail_len":.24,"sharp":true,"tip":"f2f4f2",
		"dorsal":[[-.1,.12,.17,.35]],"anal":[[-.3,-.22,.05,.5]],"pectoral":.2,"snout":true},
	"tubarao_branco":{"length":4.4,"speed":2.4,"profile":[[-.5,0,0],[-.4,.035,.03],[-.25,.08,.065],[-.05,.125,.1],[.18,.125,.105],[.36,.085,.08],[.47,.03,.04],[.5,0,0]],
		"back":"6b7580","belly":"f6f6f4","pattern":"none","fin":"59636d","tail":"shark","tail_span":.36,"tail_len":.26,"sharp":true,
		"dorsal":[[-.08,.14,.2,.4]],"anal":[[-.3,-.22,.05,.5]],"pectoral":.22,"snout":true},
	"peixe_lua":{"length":2.3,"speed":.9,"profile":[[-.5,0,0],[-.43,.12,.03],[-.3,.3,.07],[-.05,.43,.1],[.15,.44,.105],[.33,.34,.08],[.46,.14,.04],[.5,0,0]],
		"back":"8d9ba3","belly":"d8dfe0","pattern":"spots","pattern_color":"6f7e87","pattern_count":8,"fin":"7d8b93","tail":"frill","tail_span":.8,"tail_len":.1,
		"dorsal":[[-.38,.0,.55,.35]],"anal":[[-.38,.0,.55,.35]],"pectoral":.1,"belly_ratio":1.},
	"peixe_serra":{"length":3.2,"speed":1.2,"profile":[[-.5,0,0],[-.4,.025,.04],[-.25,.05,.1],[-.05,.07,.14],[.1,.07,.15],[.25,.05,.11],[.33,.025,.06],[.36,0,0]],
		"back":"7a7d6f","belly":"e6e3d2","pattern":"none","fin":"6b6d60","tail":"shark","tail_span":.2,"tail_len":.2,"sharp":true,
		"dorsal":[[-.15,.0,.1,.4],[-.34,-.2,.07,.5]],"anal":[],"pectoral":.18,"rostrum":.46,"belly_ratio":.7},
	"atum_rei":{"length":2.5,"speed":2.6,"profile":[[-.5,0,0],[-.43,.025,.02],[-.3,.075,.05],[-.05,.17,.11],[.15,.19,.12],[.33,.14,.09],[.46,.05,.035],[.5,0,0]],
		"back":"1f3f78","belly":"dfe6ec","pattern":"stripe","pattern_color":"c9a227","fin":"d2b030","tail":"lunate","tail_span":.46,"tail_len":.24,"sharp":false,
		"dorsal":[[-.16,.06,.1,.5],[.1,.26,.14,.4]],"anal":[[-.24,-.05,.1,.5]],"finlets":true,"pectoral":.16},
	# Shallow-water fish near the beaches: a silvery baitfish shoal and bright reef damselfish.
	"manjuba":{"length":.22,"speed":2.,"profile":[[-.5,0,0],[-.42,.03,.02],[-.28,.06,.035],[-.05,.09,.05],[.15,.1,.052],[.33,.08,.042],[.46,.035,.02],[.5,0,0]],
		"back":"5fa8a0","belly":"f4f8f6","pattern":"stripe","pattern_color":"c8d6d8","fin":"c9dcdc","tail":"forked","tail_span":.3,"tail_len":.17,
		"dorsal":[[-.1,.08,.08,.4]],"anal":[[-.2,-.02,.04,.5]],"pectoral":.07},
	"donzela":{"length":.3,"speed":1.3,"profile":[[-.5,0,0],[-.42,.05,.02],[-.3,.13,.035],[-.05,.21,.05],[.15,.22,.052],[.33,.15,.042],[.46,.06,.02],[.5,0,0]],
		"back":"f0c419","belly":"fbe98a","pattern":"bars","pattern_color":"1c2a3a","pattern_count":5,"fin":"f5d43a","tail":"forked","tail_span":.32,"tail_len":.17,
		"dorsal":[[-.3,.24,.14,.5]],"anal":[[-.26,.02,.08,.5]],"pectoral":.09,"belly_ratio":.9}
}
static var cache: Dictionary={}
static var materials: Dictionary={}

static func has_form(id: String) -> bool:return FORMS.has(id)
static func length_of(id: String) -> float:return float(FORMS[id].length)
static func speed_of(id: String) -> float:return float(FORMS[id].speed)

static func material(id: String,use_time: bool=false) -> ShaderMaterial:
	var key:=id+str(use_time)
	if materials.has(key):return materials[key]
	var mat:=ShaderMaterial.new();mat.shader=SHADER;mat.set_shader_parameter("use_time",use_time)
	var form: Dictionary=FORMS[id]
	var big:=float(form.length)>1.8
	mat.set_shader_parameter("wag",.1 if big else .2);mat.set_shader_parameter("time_speed",4. if big else 8.)
	if id=="peixe_lua":mat.set_shader_parameter("wag",.05)
	materials[key]=mat;return mat

static func _cr(p0: float,p1: float,p2: float,p3: float,t: float) -> float:
	return .5*((2.*p1)+(-p0+p2)*t+(2.*p0-5.*p1+4.*p2-p3)*t*t+(-p0+3.*p1-3.*p2+p3)*t*t*t)

## Smooth half-height / half-width at x along the control profile.
static func _section(profile: Array,x: float) -> Vector2:
	var n:=profile.size()
	for i: int in n-1:
		var a: Array=profile[i];var b: Array=profile[i+1]
		if x>=float(a[0]) and x<=float(b[0]):
			var t:=inverse_lerp(float(a[0]),float(b[0]),x)
			var p0: Array=profile[maxi(i-1,0)];var p3: Array=profile[mini(i+2,n-1)]
			return Vector2(maxf(0.,_cr(float(p0[1]),float(a[1]),float(b[1]),float(p3[1]),t)),maxf(0.,_cr(float(p0[2]),float(a[2]),float(b[2]),float(p3[2]),t)))
	return Vector2.ZERO

static func _paint(form: Dictionary,x: float,ny: float,angle: float) -> Color:
	var back:=Color(str(form.back));var belly:=Color(str(form.belly))
	# Sharks and rays have a hard countershading line; most fish blend back into belly.
	var c:Color=belly.lerp(back,smoothstep(-.12,.02,ny)) if bool(form.get("sharp",false)) else belly.lerp(back,smoothstep(-.35,.55,ny))
	var pc:=Color(str(form.get("pattern_color","000000")))
	match str(form.get("pattern","none")):
		"bars":
			var count:=float(form.get("pattern_count",5))
			if x>-.3 and x<.3 and sin((x+.3)*count*TAU/.6)>.35:c=c.lerp(pc,.9)
		"stripe":
			if x>-.38 and x<.36 and absf(ny-.12)<.13:c=c.lerp(pc,.85)
		"spots":
			var count:=float(form.get("pattern_count",6))
			if ny>-.1 and x>-.35 and x<.28 and sin(x*count*9.)*sin(angle*3.+x*8.)>.55:c=c.lerp(pc,.8)
	if x>.4:c=c.darkened(.12)
	return c

## Species drawn with a model from Bruno's marine pack instead of the parametric body
## (head +X, length 1, painted by scripts/pipeline/color_imported.py).
const MODELS: Dictionary={"tubarao_branco":"res://assets/models/imported/shark.res","tubarao_recife":"res://assets/models/imported/shark.res"}

static func mesh(id: String) -> ArrayMesh:
	if cache.has(id):return cache[id]
	if MODELS.has(id):cache[id]=load(MODELS[id]);return cache[id]
	var form: Dictionary=FORMS[id];var profile: Array=form.profile
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var belly_ratio:=float(form.get("belly_ratio",.82))
	var x0:=float(profile[0][0]);var x1:=float(profile[profile.size()-1][0])
	var rings: Array=[]
	for r: int in RINGS+1:
		var x:=lerpf(x0,x1,float(r)/float(RINGS));var s:=_section(profile,x);var ring: Array=[]
		for k: int in SEGMENTS:
			var a:=TAU*float(k)/float(SEGMENTS)
			var sy:=sin(a);var h:=s.x*(1. if sy>=0. else belly_ratio)
			var v:=Vector3(x,sy*h,cos(a)*s.y)
			var n:=Vector3(0,sy/maxf(h,.001),cos(a)/maxf(s.y,.001)).normalized()
			if x>x1-.05:n=n.lerp(Vector3.RIGHT,.5).normalized()
			ring.append([v,n,_paint(form,x,sy,a)])
		rings.append(ring)
	for r: int in RINGS:
		for k: int in SEGMENTS:
			var k2:=(k+1)%SEGMENTS
			var a: Array=rings[r][k];var b: Array=rings[r+1][k];var c: Array=rings[r+1][k2];var d: Array=rings[r][k2]
			for q: Array in [a,c,b,a,d,c]:
				st.set_color(q[2]);st.set_normal(q[1]);st.add_vertex(q[0])
	var fin_color:=Color(str(form.fin))
	var body_top:=func(x: float) -> float:return _section(profile,x).x
	var body_bottom:=func(x: float) -> float:return -_section(profile,x).x*belly_ratio
	var tri:=func(p: Array,col: Color) -> void:
		var nrm: Vector3=((p[1]-p[0]).cross(p[2]-p[0])).normalized()
		for v: Vector3 in p:
			st.set_color(col);st.set_normal(nrm);st.add_vertex(v)
	# Dorsal and anal fins: a fan from the body surface up to an apex.
	for fin: Array in form.get("dorsal",[]):
		var xs:=float(fin[0]);var xe:=float(fin[1]);var hgt:=float(fin[2]);var apex:=lerpf(xs,xe,float(fin[3]))
		var steps:=6
		for i: int in steps:
			var xa:=lerpf(xs,xe,float(i)/steps);var xb:=lerpf(xs,xe,float(i+1)/steps)
			var ya:float=body_top.call(xa)-.01;var yb:float=body_top.call(xb)-.01
			var ta:=clampf(1.-absf(xa-apex)/maxf(xe-xs,.01)*1.6,.0,1.)
			var tb:=clampf(1.-absf(xb-apex)/maxf(xe-xs,.01)*1.6,.0,1.)
			var top_a:=ya+hgt*ta;var top_b:=yb+hgt*tb
			tri.call([Vector3(xa,ya,0),Vector3(xb,yb,0),Vector3(xb,top_b,0)],fin_color)
			tri.call([Vector3(xa,ya,0),Vector3(xb,top_b,0),Vector3(xa,top_a,0)],fin_color.lightened(.05))
	for fin: Array in form.get("anal",[]):
		var xs:=float(fin[0]);var xe:=float(fin[1]);var hgt:=absf(float(fin[2]));var apex:=lerpf(xs,xe,float(fin[3]))
		var steps:=5
		for i: int in steps:
			var xa:=lerpf(xs,xe,float(i)/steps);var xb:=lerpf(xs,xe,float(i+1)/steps)
			var ya:float=body_bottom.call(xa)+.01;var yb:float=body_bottom.call(xb)+.01
			var ta:=clampf(1.-absf(xa-apex)/maxf(xe-xs,.01)*1.6,.0,1.);var tb:=clampf(1.-absf(xb-apex)/maxf(xe-xs,.01)*1.6,.0,1.)
			tri.call([Vector3(xa,ya,0),Vector3(xb,yb,0),Vector3(xb,yb-hgt*tb,0)],fin_color)
			tri.call([Vector3(xa,ya,0),Vector3(xb,yb-hgt*tb,0),Vector3(xa,ya-hgt*ta,0)],fin_color.darkened(.05))
	if bool(form.get("finlets",false)):
		for i: int in 7:
			var fx:=-.28-float(i)*.03
			tri.call([Vector3(fx,body_top.call(fx)-.005,0),Vector3(fx-.025,body_top.call(fx-.025)-.005,0),Vector3(fx-.03,body_top.call(fx)+.03,0)],Color("e6c93a"))
			tri.call([Vector3(fx,body_bottom.call(fx)+.005,0),Vector3(fx-.025,body_bottom.call(fx-.025)+.005,0),Vector3(fx-.03,body_bottom.call(fx)-.03,0)],Color("e6c93a"))
	# Paired pectoral fins.
	var pect:=float(form.get("pectoral",.1))
	if pect>0.:
		var px:=.22;var s:=_section(profile,px)
		for side: float in [-1.,1.]:
			tri.call([Vector3(px,-s.x*.25,s.y*.9*side),Vector3(px-pect*.9,-s.x*.55-pect*.15,(s.y+pect*.85)*side),Vector3(px-pect*1.3,-s.x*.3,(s.y+pect*.35)*side)],fin_color.lightened(.1))
		# Pelvic fins.
		var qx:=-.02
		for side: float in [-1.,1.]:
			tri.call([Vector3(qx,body_bottom.call(qx),.03*side),Vector3(qx-pect*.7,body_bottom.call(qx)-pect*.5,.07*side),Vector3(qx-pect*.9,body_bottom.call(qx)-.005,.04*side)],fin_color)
	# Tail.
	var tail_len:=float(form.get("tail_len",.17));var span:=float(form.get("tail_span",.3));var tx:=x0+.02
	match str(form.get("tail","forked")):
		"forked":
			tri.call([Vector3(tx,0,0),Vector3(tx-tail_len,span*.5,0),Vector3(tx-tail_len*.55,0,0)],fin_color)
			tri.call([Vector3(tx,0,0),Vector3(tx-tail_len*.55,0,0),Vector3(tx-tail_len,-span*.5,0)],fin_color)
		"lunate":
			tri.call([Vector3(tx,.02,0),Vector3(tx-tail_len*1.05,span*.52,0),Vector3(tx-tail_len*.5,0,0)],fin_color)
			tri.call([Vector3(tx,-.02,0),Vector3(tx-tail_len*.5,0,0),Vector3(tx-tail_len*1.05,-span*.52,0)],fin_color)
			tri.call([Vector3(tx,.02,0),Vector3(tx-tail_len*.5,0,0),Vector3(tx,-.02,0)],fin_color.darkened(.05))
		"rounded":
			tri.call([Vector3(tx,.015,0),Vector3(tx-tail_len,span*.42,0),Vector3(tx-tail_len*1.05,0,0)],fin_color)
			tri.call([Vector3(tx,-.015,0),Vector3(tx-tail_len*1.05,0,0),Vector3(tx-tail_len,-span*.42,0)],fin_color)
			tri.call([Vector3(tx,.015,0),Vector3(tx-tail_len*1.05,0,0),Vector3(tx,-.015,0)],fin_color.darkened(.05))
		"shark":
			tri.call([Vector3(tx,.015,0),Vector3(tx-tail_len*1.15,span*.62,0),Vector3(tx-tail_len*.45,.01,0)],fin_color)
			tri.call([Vector3(tx,-.01,0),Vector3(tx-tail_len*.45,.0,0),Vector3(tx-tail_len*.7,-span*.3,0)],fin_color.darkened(.05))
			tri.call([Vector3(tx-tail_len*.45,.0,0),Vector3(tx-tail_len*.7,-span*.3,0),Vector3(tx-tail_len*.3,-.02,0)],fin_color)
		"frill":
			var steps:=7
			for i: int in steps:
				var a:=-1.+2.*float(i)/steps;var b:=-1.+2.*float(i+1)/steps
				var ra:=sqrt(maxf(0.,1.-a*a));var rb:=sqrt(maxf(0.,1.-b*b))
				tri.call([Vector3(tx,a*span*.5,0),Vector3(tx-tail_len*ra,a*span*.5,0),Vector3(tx-tail_len*rb,b*span*.5,0)],fin_color)
				tri.call([Vector3(tx,a*span*.5,0),Vector3(tx-tail_len*rb,b*span*.5,0),Vector3(tx,b*span*.5,0)],fin_color)
	# Eyes: dark bead with a pale ring, set high and forward.
	var eye_x:=x1-.14;var es:=_section(profile,eye_x);var er:=.026 if float(form.length)<1.5 else .02
	if id=="peixe_serra":eye_x=.22;es=_section(profile,eye_x)
	for side: float in [-1.,1.]:
		_blob(st,Vector3(eye_x,es.x*.35,es.y*.93*side),er*1.5,Color("e8e4cc"))
		_blob(st,Vector3(eye_x+.003,es.x*.35,es.y*.97*side),er,Color("0b0b0d"))
	# Extras per form.
	if bool(form.get("spines",false)):
		for i: int in 34:
			var a:=float(i)*2.399;var xx:=lerpf(-.28,.3,fposmod(float(i)*.37,1.));var s2:=_section(profile,xx)
			var p:=Vector3(xx,sin(a)*s2.x,cos(a)*s2.y);var dir:=Vector3(0,sin(a)*s2.x/maxf(s2.x*s2.x,.001)*.04,cos(a)*s2.y/maxf(s2.y*s2.y,.001)*.04).normalized()*.045
			tri.call([p+Vector3(.006,0,0),p-Vector3(.006,0,0),p+dir],Color("f1e9c4"))
	if form.has("rostrum"):
		var rl:=float(form.rostrum);		var bx:=float(profile[profile.size()-1][0])
		var blade:=Color("9a9a8c")
		tri.call([Vector3(bx,.01,.055),Vector3(bx,.01,-.055),Vector3(bx+rl,.0,.0)],blade)
		tri.call([Vector3(bx,-.01,.055),Vector3(bx+rl,.0,.0),Vector3(bx,-.01,-.055)],blade.darkened(.2))
		for i: int in 9:
			var tx2:=bx+rl*(.1+float(i)*.095);var half:=lerpf(.055,.004,float(i)/9.)
			for side: float in [-1.,1.]:
				tri.call([Vector3(tx2,.0,half*side),Vector3(tx2+.02,.0,half*side),Vector3(tx2+.008,.0,(half+.035)*side)],Color("efe9d4"))
	st.index()
	var result:=st.commit();cache[id]=result;return result

static func _blob(st: SurfaceTool,at: Vector3,radius: float,color: Color) -> void:
	# A small octahedron-ish bead; cheap and reads as an eye at any distance.
	var pts:=[Vector3(radius,0,0),Vector3(-radius*.4,0,0),Vector3(0,radius,0),Vector3(0,-radius,0),Vector3(0,0,radius),Vector3(0,0,-radius)]
	for tri_idx: Array in [[0,2,4],[0,4,3],[0,3,5],[0,5,2],[1,4,2],[1,3,4],[1,5,3],[1,2,5]]:
		var p: Array=[at+pts[tri_idx[0]],at+pts[tri_idx[1]],at+pts[tri_idx[2]]]
		var nrm: Vector3=((p[1]-p[0]).cross(p[2]-p[0])).normalized()
		for v: Vector3 in p:
			st.set_color(color);st.set_normal(nrm);st.add_vertex(v)
