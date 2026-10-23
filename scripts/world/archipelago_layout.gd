extends RefCounted
## Metres, sea level = 0. Shared coastline contract with archipelago_coast.gdshaderinc.
const WORLD_HALF: float = 2200.0
const LOBES: Array[Vector4]=[
	Vector4(0,230,220,230),Vector4(-140,105,95,115),Vector4(150,110,100,130),Vector4(-65,540,330,480),
	Vector4(-690,-510,220,260),Vector4(790,-640,250,320),Vector4(20,-1340,330,300),Vector4(-110,-18,30,29)]
const TRAIL: Array[Vector3]=[
	Vector3(0,1.25,-10),Vector3(0,1.25,32),Vector3(10,4,75),Vector3(-30,12,120),
	Vector3(-70,21,170),Vector3(-55,29,220),Vector3(10,35,260),Vector3(70,47,295),
	Vector3(90,63,345),Vector3(50,71,395),Vector3(-20,78,430),Vector3(-65,86,490)]
const WEST_TRAIL: Array[Vector3]=[
	Vector3(-30,12,120),Vector3(-105,13,115),Vector3(-155,15,145),Vector3(-170,22,210),
	Vector3(-150,28,265),Vector3(-110,38,310),Vector3(-55,39,300),Vector3(10,35,260)]
const EAST_TRAIL: Array[Vector3]=[Vector3(0,1.25,32),Vector3(60,1.25,32),Vector3(115,5,62),Vector3(155,7,95),Vector3(190,3,105)]
const NORTH_TRAIL: Array[Vector3]=[Vector3(-65,86,490),Vector3(-140,106,560),Vector3(-170,116,650),Vector3(-60,150,725),Vector3(50,150,775),Vector3(145,115,690),Vector3(130,83,540),Vector3(165,71,400),Vector3(90,63,345)]
const OLD_PORT_TRAIL: Array[Vector3]=[Vector3(-30,1.4,-7),Vector3(-30,1.4,-4),Vector3(-60,1.4,-4),Vector3(-88,1.4,-4)]
const PLOTS: Array[Vector4]=[Vector4(-14,7,8,7),Vector4(16,20,9,7),Vector4(-18,27,11,8),Vector4(-36,4,11,9),Vector4(35,5,9,7),Vector4(25,43,10,8),Vector4(-17,49,7,6),Vector4(14,52,8,7),Vector4(-42,23,7,6),Vector4(49,22,8,7),Vector4(52,46,9,7),Vector4(71,44,7,6),Vector4(-65,43,8,7),Vector4(-64,13,7,6)]
static var terrain_noise: FastNoiseLite

static func noise(p: Vector2, scale_value: float=1.) -> float:
	if terrain_noise==null:
		terrain_noise=FastNoiseLite.new()
		terrain_noise.seed=441019
		terrain_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		terrain_noise.fractal_type=FastNoiseLite.FRACTAL_FBM
		terrain_noise.fractal_octaves=3
		terrain_noise.frequency=.014
	return terrain_noise.get_noise_2d(p.x*scale_value,p.y*scale_value)

static func plot_ground(p: Vector2) -> bool:
	for plot: Vector4 in PLOTS:
		if absf(p.x-plot.x)<plot.z*.5+2. and absf(p.y-plot.y)<plot.w*.5+2.:return true
	return false

static func coast(p: Vector2) -> Vector4:
	var nearest:=10000.;var second:=10000.;var normal:=Vector2.UP
	for i: int in LOBES.size():
		var l:=LOBES[i];var q:=(p-Vector2(l.x,l.y))/Vector2(l.z,l.w)
		var angle:=atan2(q.y,q.x)
		var edge:=1.+sin(angle*3.+float(i)*1.7)*.055+cos(angle*7.)*.025
		var dist:=(q.length()-edge)*minf(l.z,l.w)
		if dist<nearest:
			if i>=4 and i!=7: second=nearest
			nearest=dist;normal=Vector2(q.x/l.z,q.y/l.w).normalized()
		elif i>=4 and i!=7 and dist<second: second=dist
	return Vector4(nearest,normal.x,normal.y,second)

static func route_sample(p: Vector2, route: Array[Vector3]) -> Vector2:
	var result:=Vector2(10000,0)
	for i: int in route.size()-1:
		var a:=Vector2(route[i].x,route[i].z);var b:=Vector2(route[i+1].x,route[i+1].z)
		var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0.,1.)
		var d:=p.distance_to(a.lerp(b,t))
		if d<result.x: result=Vector2(d,lerpf(route[i].y,route[i+1].y,t))
	return result

static func path_at(p: Vector2) -> Vector2:
	var result:=route_sample(p,TRAIL)
	for route: Array[Vector3] in [WEST_TRAIL,EAST_TRAIL,NORTH_TRAIL,OLD_PORT_TRAIL]:
		var s:=route_sample(p,route)
		if s.x<result.x: result=s
	return result

static func height(p: Vector2) -> float:
	var c:=coast(p).x
	if c>8.: return -1.2-(c-8.)*.65
	var h:=1.25
	if p.y>70.:
		var ridge:=exp(-pow((p.x+45.)/135.,2.)-pow((p.y-340.)/190.,2.))*105.
		ridge+=exp(-pow((p.x-115.)/70.,2.)-pow((p.y-255.)/125.,2.))*48.
		ridge+=exp(-pow((p.x+115.)/65.,2.)-pow((p.y-465.)/90.,2.))*55.
		ridge+=exp(-pow((p.x+50.)/170.,2.)-pow((p.y-740.)/170.,2.))*185.
		var erosion:=sin(p.x*.033+p.y*.022)*6.+sin(p.y*.061-p.x*.045)*3.
		# Broad variation makes the mountain mass read naturally while routes stay flattened below.
		var hills:=noise(p)*5.5
		var crags:=pow(1.-absf(noise(p,1.6)),4.)*5.*smoothstep(50.,120.,ridge)
		h+=(ridge+erosion+hills+crags)*smoothstep(65.,125.,p.y)*smoothstep(8.,55.,-c)
	var trail:=path_at(p)
	h=lerpf(h,trail.y,1.-smoothstep(3.5,65.,trail.x))
	# The old watch station occupies a level, accessible clearing beside the trail.
	h=lerpf(h,38.,1.-smoothstep(16.,34.,p.distance_to(Vector2(-110,310))))
	# Coastal settlement terraces stay grounded and connected, not floating props.
	if p.y<62. and absf(p.x)<85.: h=1.25
	return lerpf(-1.2,h,smoothstep(-6.,10.,-c))

static func wrapped(p: Vector3) -> Vector3:
	return Vector3(wrapf(p.x,-WORLD_HALF,WORLD_HALF),p.y,wrapf(p.z,-WORLD_HALF,WORLD_HALF))
