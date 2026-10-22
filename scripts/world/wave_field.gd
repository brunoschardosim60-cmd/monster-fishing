extends RefCounted
## CPU companion of ocean_common.gdshaderinc. Every surface uses these parameters.
const ISLANDS := [Vector4(0,18,29,32), Vector4(-95,-95,20,24), Vector4(115,-150,29,34), Vector4(35,-265,32,30)]
const LENGTHS := [64.,39.,23.,13.,7.1,4.7,3.1,2.0]
const WEIGHTS := [.48,.33,.25,.21,.12,.075,.043,.025]
static var time: float = 0.0
static var wind: float = .32
static var energy: float = .40
static var rain: float = 0.0
static var direction := Vector2(.9,.43).normalized()
static var waves: Array[Vector4] = []
static var phases := PackedFloat32Array([0.,1.8,4.1,.7,3.3,5.,2.,4.5])

static func reset() -> void:
	time=0.; wind=.32; energy=.40; rain=0.
	direction=Vector2(.9,.43).normalized()
	phases=PackedFloat32Array([0.,1.8,4.1,.7,3.3,5.,2.,4.5])
	advance(0.,wind,energy,rain,direction)

static func advance(delta: float, w: float, e: float, r: float, d: Vector2) -> void:
	time+=delta; wind=w; energy=e; rain=r; direction=d
	waves.clear()
	for i: int in 8:
		var angle: float=[.10,-.56,.61,-.28,1.1,-1.3,.8,-.7][i]
		var heading:=Vector2(.9,.43).normalized().lerp(d,.25 if i<3 else .8).normalized().rotated(angle)
		var k: float=TAU/LENGTHS[i]
		phases[i]=fposmod(phases[i]+sqrt(9.81*k)*delta,TAU)
		var amp: float=WEIGHTS[i]*(.14+e*2.5 if i<3 else .15+w*2.1)
		waves.append(Vector4(heading.x*k,heading.y*k,amp,phases[i]))

static func coast(p: Vector2) -> Vector4:
	var nearest:=10000.; var second:=10000.; var normal:=Vector2.UP
	for island: Vector4 in ISLANDS:
		var q:=(p-Vector2(island.x,island.y))/Vector2(island.z,island.w)
		var dist:=(q.length()-1.)*minf(island.z,island.w)
		if dist<nearest:
			second=nearest; nearest=dist
			normal=Vector2(q.x/island.z,q.y/island.w).normalized()
		elif dist<second: second=dist
	return Vector4(nearest,normal.x,normal.y,second)

static func exposure(p: Vector2) -> float:
	var c:=coast(p)
	var lee:=smoothstep(-.2,.65,Vector2(c.y,c.z).dot(direction))*(1.-smoothstep(2.,38.,c.x))
	var port:=1.-smoothstep(.35,1.5,Vector2(p.x/16.,(p.y+17.)/21.).length())
	var channel:=1.-smoothstep(7.,32.,c.w)
	return clampf((1.-lee*.72-port*.72)*(1.-channel*.4),.16,1.)

static func depth_at(p: Vector2) -> float:
	return maxf(0.,.8+coast(p).x*.65)

static func channel_at(p: Vector2) -> float:
	# Passage between the northern island's shelf and the floating ice field.
	return 1.-smoothstep(.25,1.,Vector2((p.x-84.)/6.,(p.y+136.)/17.).length())

static func height_at(p: Vector3) -> float:
	if waves.is_empty(): advance(0.,wind,energy,rain,direction)
	var v:=Vector2(p.x,p.z)
	var c:=coast(v)
	var shore:=smoothstep(-1.3,6.,c.x)
	var exposed:=exposure(v)
	var channel:=channel_at(v)
	var lod:=1.-smoothstep(185.,240.,maxf(absf(p.x),absf(p.z)))
	var h:=0.
	for i: int in 8:
		var w:=waves[i]
		var phase:=v.dot(Vector2(w.x,w.y))-w.w+sin(v.dot(Vector2(.019,.027))+float(i))*.37
		h+=(sin(phase)+.15*sin(2.*phase))*w.z*lerpf(.32 if i<3 else .1,1.,exposed)*(1.-channel*(.2 if i<3 else .65))
	var wash:=sin(c.x*.85-time*1.15)*.12*(.3+energy)*(1.-smoothstep(0.,9.,c.x))*smoothstep(-1.4,0.,c.x)
	var guided:=sin(v.y*1.8-time*1.5)*.08*channel*shore
	return (h*shore+wash+guided)*lod

static func bind(mat: ShaderMaterial) -> void:
	if waves.is_empty(): advance(0.,wind,energy,rain,direction)
	mat.set_shader_parameter("sea_time",time)
	mat.set_shader_parameter("wave_data",waves)
	mat.set_shader_parameter("wind_direction",direction)
	mat.set_shader_parameter("wind_strength",wind)
	mat.set_shader_parameter("swell_energy",energy)
	mat.set_shader_parameter("rain_strength",rain)
