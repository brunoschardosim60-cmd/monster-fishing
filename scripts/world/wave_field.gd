extends RefCounted
## CPU companion of ocean_common.gdshaderinc. Every surface uses these parameters.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const ISLANDS = Layout.LOBES
static var ocean_center:=Vector2.ZERO
const LENGTHS := [64.,39.,23.,13.,7.1,4.7,3.1,2.0]
const WEIGHTS := [.48,.33,.25,.21,.12,.075,.043,.025]
static var time: float = 0.0
static var wind: float = .32
static var energy: float = .40
static var rain: float = 0.0
static var direction := Vector2(.9,.43).normalized()
static var waves: Array[Vector4] = []
static var phases := PackedFloat32Array([0.,1.8,4.1,.7,3.3,5.,2.,4.5])
## Local sea features, same layout as the shader uniforms: Vector4(x, z, radius, strength), up to 4 each.
static var storm_cells: Array[Vector4]=[]
## Tide level (m) added to the whole sea surface.
static var tide: float=0.
static var whirls: Array[Vector4]=[]

static func storm_factor(v: Vector2) -> float:
	var s:=0.
	for c: Vector4 in storm_cells:
		if c.w<=0.:continue
		s=maxf(s,c.w*(1.-smoothstep(c.z*.55,c.z*1.25,v.distance_to(Vector2(c.x,c.y)))))
	return s

## A storm stirs the sea well beyond its rain (ocean_common storm_halo).
static func storm_halo(v: Vector2) -> float:
	var s:=0.
	for c: Vector4 in storm_cells:
		if c.w<=0.:continue
		s=maxf(s,c.w*(1.-smoothstep(c.z*.9,c.z*2.6,v.distance_to(Vector2(c.x,c.y)))))
	return s

## Swell groups varying over kilometres (ocean_common sea_groups).
static func sea_groups(v: Vector2,i: int) -> float:
	var fi:=float(i)
	var s1:=sin(v.x*.0031+v.y*.0017+time*.011+fi*.6)
	var s2:=sin(-v.x*.0019+v.y*.0043-time*.007+fi*1.3)
	var s3:=sin(v.x*.0057-v.y*.0023+time*.013+fi*.4)
	return lerpf(.5,1.4,.5+.5*(s1*.5+s2*.35+s3*.15))

## Wandering crest lines (ocean_common sea_warp).
static func sea_warp(v: Vector2,w: Vector4,i: int) -> float:
	var fi:=float(i)
	return sin(v.dot(Vector2(-w.y,w.x))*.0105+fi*1.7)*1.3+sin(v.dot(Vector2(.0047,-.0063))+fi*.9)*1.1+sin(v.dot(Vector2(.021,-.017))+fi*2.3)*(.4 if i<3 else 1.2)

## Depth of the whirlpool funnel at a point (negative), plus its ripple; 0 outside every whirlpool.
static func whirl_offset(v: Vector2) -> float:
	var y:=0.
	for wh: Vector4 in whirls:
		if wh.w<=0.:continue
		var d:=v-Vector2(wh.x,wh.y);var dist:=d.length()
		if dist>=wh.z:continue
		var t:=1.-dist/wh.z
		var bowl:=minf(wh.z*.08,7.)*wh.w
		var core:=wh.z*.075;var c2:=core*core
		var throat:=minf(wh.z*.42,40.)*wh.w
		var f:=c2/(c2+dist*dist)-c2/(c2+wh.z*wh.z)
		y+=-bowl*t*t-throat*f+sin(atan2(d.y,d.x)*3.+dist*.35-time*3.)*.18*t*wh.w
	return y

static func _pad(list: Array[Vector4]) -> Array[Vector4]:
	var out: Array[Vector4]=list.duplicate()
	while out.size()<4:out.append(Vector4.ZERO)
	return out.slice(0,4)

static func reset() -> void:
	time=0.; wind=.32; energy=.40; rain=0.
	storm_cells.clear(); whirls.clear(); tide=0.
	ocean_center=Vector2.ZERO
	direction=Vector2(.9,.43).normalized()
	phases=PackedFloat32Array([0.,1.8,4.1,.7,3.3,5.,2.,4.5])
	advance(0.,wind,energy,rain,direction)

static func advance(delta: float, w: float, e: float, r: float, d: Vector2) -> void:
	time+=delta; wind=w; energy=e; rain=r; direction=d
	waves.clear()
	for i: int in 8:
		var angle: float=[.10,-.56,.61,-.35,.48,-.62,.3,-.27][i]
		var heading:=Vector2(.9,.43).normalized().lerp(d,.25 if i<3 else .8).normalized().rotated(angle)
		var k: float=TAU/LENGTHS[i]
		phases[i]=fposmod(phases[i]+sqrt(9.81*k)*delta,TAU)
		var amp: float=WEIGHTS[i]*(.14+e*2.5 if i<3 else .15+w*2.1)
		waves.append(Vector4(heading.x*k,heading.y*k,amp,phases[i]))

static func coast(p: Vector2) -> Vector4:
	return Layout.coast(p)

static func exposure(p: Vector2) -> float:
	var c:=coast(p)
	var lee:=smoothstep(-.2,.65,Vector2(c.y,c.z).dot(direction))*(1.-smoothstep(2.,38.,c.x))
	var port:=1.-smoothstep(.35,1.5,Vector2(p.x/16.,(p.y+17.)/21.).length())
	var channel:=1.-smoothstep(7.,32.,c.w)
	return clampf((1.-lee*.72-port*.72)*(1.-channel*.4),.16,1.)

static func depth_at(p: Vector2) -> float:
	return maxf(0.,.8+coast(p).x*.65)

static func channel_at(p: Vector2) -> float:
	# Passage between the glacier island's shelf and the first floating ice field.
	return 1.-smoothstep(.25,1.,Vector2((p.x-Layout.ICE_PASSAGE.x)/12.,(p.y-Layout.ICE_PASSAGE.y)/34.).length())

static func height_at(p: Vector3) -> float:
	if waves.is_empty(): advance(0.,wind,energy,rain,direction)
	var v:=Vector2(p.x,p.z)
	var c:=coast(v)
	var shore:=smoothstep(-1.3,6.,c.x)
	var exposed:=exposure(v)
	var channel:=channel_at(v)
	var reach:=maxf(absf(p.x-ocean_center.x),absf(p.z-ocean_center.y))
	var lod:=1.-smoothstep(185.,240.,reach)
	var lod_long:=1.-smoothstep(880.,1150.,reach)
	var open_sea:=smoothstep(80.,350.,c.x)*smoothstep(.45,1.,energy)
	var h:=0.
	var storm:=storm_factor(v)
	var halo:=storm_halo(v)
	var sharp:=.15+.3*smoothstep(.4,1.,energy)+.2*storm+.08*halo
	for i: int in 8:
		var w:=waves[i]
		var phase:=v.dot(Vector2(w.x,w.y))-w.w+sin(v.dot(Vector2(.019,.027))+float(i))*.37+sea_warp(v,w,i)
		var fade:=(lod_long*(1.+open_sea*1.2) if i<3 else lod*(1.+open_sea*.4))*(1.+storm*(1.5 if i<3 else .35))*sea_groups(v,i)*(1.+halo*(.8 if i<3 else .35))
		h+=(sin(phase)+sharp*sin(2.*phase))*w.z*lerpf(.32 if i<3 else .1,1.,exposed)*(1.-channel*(.2 if i<3 else .65))*fade
	var wash:=sin(c.x*.85-time*1.15)*.12*(.3+energy)*(1.-smoothstep(0.,9.,c.x))*smoothstep(-1.4,0.,c.x)
	var swash_s:=fposmod(time/7.5+sin(v.x*.031)*.35+cos(v.y*.027)*.35-c.x*.012,1.)
	wash+=smoothstep(0.,.18,swash_s)*(1.-smoothstep(.18,1.,swash_s))*.5*(.35+energy)*smoothstep(-9.,-1.,c.x)*(1.-smoothstep(2.,14.,c.x))
	var guided:=sin(v.y*1.8-time*1.5)*.08*channel*shore
	return h*shore+(wash+guided)*lod+whirl_offset(v)+tide

## The player's hull, so the sea is not drawn inside it (ocean.gdshader): world → hull space, and the
## box (half beam, bow z, stern z, rail y) plus the keel y, all in hull space.
static var hull_inv:=Transform3D.IDENTITY
static var hull_box:=Vector4.ZERO
static var hull_keel: float=-1.
## 1 for a double-ended hull (canoe): the cut narrows at the stern as well as at the bow.
static var hull_pointed: float=0.

static func bind(mat: ShaderMaterial) -> void:
	if waves.is_empty(): advance(0.,wind,energy,rain,direction)
	mat.set_shader_parameter("sea_time",time)
	mat.set_shader_parameter("ocean_center",ocean_center)
	mat.set_shader_parameter("wave_data",waves)
	mat.set_shader_parameter("storm_cell",_pad(storm_cells))
	mat.set_shader_parameter("whirl",_pad(whirls))
	mat.set_shader_parameter("tide",tide)
	mat.set_shader_parameter("wind_direction",direction)
	mat.set_shader_parameter("wind_strength",wind)
	mat.set_shader_parameter("swell_energy",energy)
	mat.set_shader_parameter("rain_strength",rain)
	mat.set_shader_parameter("hull_inv",hull_inv)
	mat.set_shader_parameter("hull_box",hull_box)
	mat.set_shader_parameter("hull_keel",hull_keel)
	mat.set_shader_parameter("hull_pointed",hull_pointed)
