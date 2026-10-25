extends Node3D
## Phase 1: one seamless playable coast and a navigable ocean.
const G = preload("res://scripts/world/geometry.gd")
const OCEAN = preload("res://assets/shaders/ocean.gdshader")
const Materials = preload("res://scripts/visuals/materials.gd")
const Details = preload("res://scripts/world/coastal_details.gd")
const Waves = preload("res://scripts/world/wave_field.gd")
var ocean_material: ShaderMaterial
var environment: Environment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D
var ocean: Node3D
var terrain_materials: Array[ShaderMaterial]=[]
var shore_rocks: Array[Vector3]=[]
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const NatureLib=preload("res://scripts/world/nature_library.gd")
const Flora=preload("res://scripts/world/biome_flora.gd")
const Life=preload("res://scripts/world/island_life.gd")
var region: Node3D
var village: Node3D
var water_root: Node3D
var life: Node3D
var traffic: Node3D
var lighthouse: Node3D
var harbor_lighthouse: Node3D

var rng := RandomNumberGenerator.new()
var gulls: Array[Node3D] = []
var buoys: Array[Node3D] = []
var remote_island_count: int = 0
var elapsed: float = 0.0
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var cream: StandardMaterial3D
var teal: StandardMaterial3D
var leaf: StandardMaterial3D
var leaf_light: StandardMaterial3D
var rock: StandardMaterial3D

func _ready() -> void:
	rng.seed = 241019
	wood = Materials.surface("weathered_wood", Color("dcae78"), 1.1)
	dark_wood = Materials.surface("weathered_wood", Color("7d5b3e"), 1.5)
	cream = Materials.surface("paint", Color("eee2c3"), 1.8)
	teal = Materials.surface("paint", Color("2f8c92"), 1.4)
	leaf = G.material(Color("345e49"))
	leaf_light = G.material(Color("527959"))
	rock = Materials.surface("granite", Color("b3ab99"), 1.2)
	_make_lighting()
	_make_ocean()
	region=preload("res://scripts/world/island_region.gd").new();region.world=self;region.name="AuroraIsland";add_child(region)
	for i: int in range(4,Layout.LOBES.size()):
		if i==7: continue # This small lobe belongs to Aurora's old port terrain.
		var island:=Layout.LOBES[i]
		var region_data:=Layout.region_for_lobe(i)
		_make_island(Vector3(island.x,0,island.y),Vector2(island.z,island.w),false,str(region_data.get("biome","verdant")),str(region_data.get("id","island")),i)
	_make_dock()
	village=preload("res://scripts/world/harbor_village.gd").new();village.world=self;village.name="VilaDaAurora";add_child(village)
	_make_lighthouse(Vector3(-65,Layout.height(Vector2(-65,490)),490))
	harbor_lighthouse=preload("res://scripts/world/navigation_lighthouse.gd").new();harbor_lighthouse.world=self;harbor_lighthouse.position=Vector3(174,Layout.height(Vector2(174,96)),96);harbor_lighthouse.name="FarolDaEntrada";harbor_lighthouse.period=8.;harbor_lighthouse.tint=Color("ffd9a0");add_child(harbor_lighthouse)
	_make_sign()
	for p: Vector3 in [Vector3(-17, 0, -36), Vector3(24, 0, -60), Vector3(-40, 0, -98), Vector3(59, 0, -114)]:
		_make_buoy(p)
	trail_walkers=_make_trail_walkers()
	var dynamic_roots: Array[Node3D] = []
	dynamic_roots.append_array(gulls)
	dynamic_roots.append_array(buoys)
	dynamic_roots.append(region);dynamic_roots.append(village);dynamic_roots.append(trail_walkers);dynamic_roots.append(lighthouse);dynamic_roots.append(harbor_lighthouse)
	preload("res://scripts/world/static_batch.gd").build(self, dynamic_roots)
	ocean=preload("res://scripts/ocean/ocean_environment.gd").new()
	ocean.world=self; ocean.name="OceanEnvironment"; add_child(ocean)
	traffic=preload("res://scripts/world/maritime_traffic.gd").new();traffic.name="TrafegoMaritimo";add_child(traffic)
	life=preload("res://scripts/world/coastal_life.gd").new();life.world=self;life.name="CoastalLife";add_child(life)

func safe_spawn() -> Vector3:
	return Vector3(0.0, 1.55, -17.0)

func is_land(pos: Vector3) -> bool:
	if ocean!=null and ocean.is_ice(pos): return true
	if Layout.coast(Vector2(pos.x,pos.z)).x< -1.5: return true
	return absf(pos.x) < 1.8 and pos.z > -26.5 and pos.z < -7.0

func _make_lighting() -> void:
	get_viewport().use_occlusion_culling=true
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	environment=env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_material=sky_mat
	sky_mat.shader = preload("res://assets/shaders/coastal_sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", load("res://assets/textures/cloud_noise.png"))
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode=Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.22
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.5
		env.ssr_enabled = true
		env.ssr_max_steps = 20
		env.glow_enabled = true
		env.glow_intensity = 0.35
		env.glow_bloom = 0.0
	else:
		env.adjustment_contrast = 1.04
		env.ambient_light_energy = .8
	env.fog_enabled = true
	env.fog_light_color = Color("93cfd6")
	env.fog_light_energy = 0.7
	env.fog_density = 0.0023
	env.fog_sky_affect = 0.04
	env_node.environment = env
	add_child(env_node)
	sun = DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-17, 145, 0)
	sun.light_color = Color("ffd4a0")
	sun.light_energy = 1.25
	sun.light_angular_distance = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.10
	add_child(sun)
	sky_mat.set_shader_parameter("sun_direction", sun.global_basis.z.normalized())

func _make_ocean() -> void:
	water_root=Node3D.new();water_root.name="FollowingOceanGrid";add_child(water_root)
	var plane := PlaneMesh.new()
	plane.size = Vector2(480, 480)
	plane.subdivide_width = 480
	plane.subdivide_depth = 480
	var mat := ShaderMaterial.new()
	mat.shader = OCEAN
	ocean_material = mat
	mat.set_shader_parameter("normal_tex", load("res://assets/textures/water_normal.png"))
	mat.set_shader_parameter("foam_tex", load("res://assets/textures/foam_noise.png"))
	var water := G.mesh_node(water_root, plane, mat, Vector3.ZERO)
	water.name = "Ocean"
	water.custom_aabb=AABB(Vector3(-240,-8,-240),Vector3(480,16,480))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Four coarse horizon strips avoid doubling the fine mesh under the bay.
	for data: Vector4 in [Vector4(0,-6120,24000,11760),Vector4(0,6120,24000,11760),Vector4(-6120,0,11760,480),Vector4(6120,0,11760,480)]:
		var far_mesh := PlaneMesh.new()
		far_mesh.size = Vector2(data.z, data.w)
		far_mesh.subdivide_width = 32
		far_mesh.subdivide_depth = 32
		var far_water := G.mesh_node(water_root, far_mesh, mat, Vector3(data.x,0,data.y))
		far_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _biome_palette(biome: String) -> Dictionary:
	match biome:
		"tropical": return {"ground":Color("3d7b4c"),"sand":Color("d8c488"),"tint":Vector3(1.04,1.12,.92),"snow":0.,"ash":0.,"trees":36}
		"frost": return {"ground":Color("9ebec0"),"sand":Color("d9e2dd"),"tint":Vector3(.88,.98,1.08),"snow":1.,"ash":0.,"trees":24}
		"volcanic": return {"ground":Color("4c302d"),"sand":Color("63473c"),"tint":Vector3(.78,.60,.54),"snow":0.,"ash":.72,"trees":18}
		"mountain": return {"ground":Color("456247"),"sand":Color("aaa37f"),"tint":Vector3(.92,1.03,.92),"snow":.12,"ash":0.,"trees":30}
		"desert": return {"ground":Color("a9854c"),"sand":Color("d5ad65"),"tint":Vector3(1.16,.89,.61),"snow":0.,"ash":0.,"trees":22}
		"mystic": return {"ground":Color("365d58"),"sand":Color("8ca17e"),"tint":Vector3(.72,1.06,1.05),"snow":0.,"ash":0.,"trees":26}
		"shadow": return {"ground":Color("2d2a40"),"sand":Color("57536b"),"tint":Vector3(.72,.68,.92),"snow":0.,"ash":.38,"trees":22}
		"storm": return {"ground":Color("334650"),"sand":Color("6b7472"),"tint":Vector3(.68,.77,.87),"snow":0.,"ash":.28,"trees":20}
		_: return {"ground":Color("506c4d"),"sand":Color("a99b76"),"tint":Vector3.ONE,"snow":0.,"ash":0.,"trees":14}

## The mesh outline is pushed out by this factor so that the waterline (height 0) lands exactly on the
## Layout.coast contour that navigation, fishing, the map and the ocean shader all use.
const SHORE_PAD: float = 1.07
## Fraction of the raw biome relief that is kept (1 = the old tall cones).
## How strongly each biome repaints its turf, how rocky its flat ground is, and its second colour.
const BIOME_PAINT: Dictionary={
	"tropical":{"paint":.45,"rock":.05,"accent":Color("8fb84a")},
	"frost":{"paint":.85,"rock":.35,"accent":Color("e4eef0")},
	"volcanic":{"paint":.95,"rock":.8,"accent":Color("2a1f1f")},
	"mountain":{"paint":.55,"rock":.5,"accent":Color("7c8a63")},
	"desert":{"paint":.9,"rock":.2,"accent":Color("b98a52")},
	"mystic":{"paint":.75,"rock":.25,"accent":Color("3fa89c")},
	"shadow":{"paint":.9,"rock":.45,"accent":Color("55407a")},
	"storm":{"paint":.8,"rock":.6,"accent":Color("4f6b70")},
}
const RELIEF: Dictionary={"tropical":.3,"frost":.42,"volcanic":.38,"mountain":.4,"desert":.26,"mystic":.32,"storm":.32,"shadow":.34}

## World-space offset from an island centre for a normalised radius (0 centre, 1 mesh rim) and angle.
func _island_offset(lobe: int, size: Vector2, angle: float, radius: float) -> Vector2:
	var edge:=Layout.edge_factor(lobe,angle) if lobe>=0 else 1.
	return Vector2(cos(angle)*size.x,sin(angle)*size.y)*radius*edge*SHORE_PAD

func _make_island(center: Vector3, size: Vector2, playable: bool, biome: String="verdant", region_id: String="island", lobe: int=-1) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var palette:=_biome_palette(biome)
	if not playable and lobe>=0:_plan_water(lobe,size,biome)
	const RINGS: int = 48
	const SEGMENTS: int = 128
	for ring: int in range(RINGS + 1):
		var radius := float(ring) / float(RINGS)
		for segment: int in range(SEGMENTS):
			var angle := float(segment) / float(SEGMENTS) * TAU
			var offset:=_island_offset(lobe,size,angle,radius)
			var x:=offset.x;var z:=offset.y
			var height := _island_height(x,z,radius,playable,biome,lobe)
			vertices.append(center + Vector3(x, height, z))
			var variation := rng.randf_range(-0.035, 0.035)
			var col: Color=palette["sand"]
			var shoreline:=1./SHORE_PAD-.02+Layout.noise(Vector2(center.x+x,center.z+z),2.)*.03
			if radius < shoreline-.06:
				col=palette["ground"]
			col = col.lightened(variation) if variation > 0 else col.darkened(-variation)
			col.a=0. if radius>=shoreline-.06 else 1.
			colors.append(col)
	for ring: int in range(RINGS):
		for segment: int in range(SEGMENTS):
			var a := ring * SEGMENTS + segment
			var b := ring * SEGMENTS + (segment + 1) % SEGMENTS
			var c := (ring + 1) * SEGMENTS + segment
			var d := (ring + 1) * SEGMENTS + (segment + 1) % SEGMENTS
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var mesh := G.polygon_mesh(vertices, indices, colors)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/terrain.gdshader")
	mat.set_shader_parameter("meadow_tex",load("res://assets/textures/meadow_color.jpg"))
	mat.set_shader_parameter("floor_tex",load("res://assets/textures/forest_floor_color.jpg"))
	mat.set_shader_parameter("ground_normal",load("res://assets/textures/forest_floor_normal.jpg"))
	terrain_materials.append(mat)
	mat.set_shader_parameter("sand_color", load("res://assets/textures/sand_color.png"))
	mat.set_shader_parameter("sand_normal", load("res://assets/textures/sand_normal.png"))
	mat.set_shader_parameter("noise_tex", load("res://assets/textures/cloud_noise.png"))
	mat.set_shader_parameter("rock_tex",load("res://assets/textures/granite_color.png"))
	mat.set_shader_parameter("rock_normal",load("res://assets/textures/granite_normal.png"))
	mat.set_shader_parameter("biome_tint",palette["tint"])
	mat.set_shader_parameter("biome_snow",palette["snow"])
	mat.set_shader_parameter("biome_ash",palette["ash"])
	if not playable:
		var paint: Dictionary=BIOME_PAINT.get(biome,{"paint":.25,"rock":.0,"accent":Color("6f8c4c")})
		mat.set_shader_parameter("biome_land",1.)
		mat.set_shader_parameter("biome_paint",paint["paint"])
		mat.set_shader_parameter("biome_rock",paint["rock"])
		var ground_c: Color=(palette["ground"] as Color).srgb_to_linear();var accent_c: Color=(paint["accent"] as Color).srgb_to_linear()
		mat.set_shader_parameter("biome_ground",Vector3(ground_c.r,ground_c.g,ground_c.b))
		mat.set_shader_parameter("biome_accent",Vector3(accent_c.r,accent_c.g,accent_c.b))
	var island := G.mesh_node(self, mesh, mat, Vector3.ZERO)
	island.name = "HomeIsland" if playable else "Island_"+region_id
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = mesh.create_trimesh_shape()
	body.add_child(col)
	island.add_child(body)
	if not playable:
		_decorate_remote_island(center,size,biome,palette,lobe)
		remote_island_count+=1

func _island_height(x: float,z: float,radius: float,playable: bool,biome: String="verdant",lobe: int=-1) -> float:
	var h:=1.25
	if playable:
		# The harbor, market and cabins retain their original flat circulation area.
		var ridge:=exp(-pow((x+10.)/13.,2.)-pow((z-15.)/13.,2.))*14.
		ridge+=exp(-pow((x-12.)/9.,2.)-pow((z-22.)/11.,2.))*10.
		var erosion:=1.+sin(x*.57+z*.22)*.11+sin(z*.61-x*.2)*.08
		ridge=ridge*erosion+sin(x*1.3+z*.7)*.65+sin(z*1.1-x*.8)*.4
		var stratum:=ridge/2.8
		ridge=lerpf(ridge,(floorf(stratum)+smoothstep(.55,.95,fposmod(stratum,1.)))*2.8,.55)
		h+=ridge*smoothstep(4.,14.,z)*(1.-smoothstep(.72,.98,radius))
	else:
		var core:=pow(maxf(0.,1.-radius/.87),.93)
		var variation:=Layout.noise(Vector2(x+37.,z-11.),1.7)
		var crags:=pow(1.-absf(Layout.noise(Vector2(x,z),1.5)),3.)
		var peak_scale:=14.
		match biome:
			"tropical": h+=core*(30.+variation*13.+crags*16.)+exp(-pow((x-45.)/75.,2.)-pow((z+25.)/65.,2.))*22.;peak_scale=16.
			"frost": h+=core*(72.+variation*22.+crags*26.);peak_scale=34.
			"volcanic": h+=core*(76.+variation*17.)+exp(-pow((radius-.28)/.12,2.))*34.-exp(-pow(radius/.13,2.))*25.;peak_scale=8.
			"mountain": h+=core*(112.+variation*30.+crags*48.);peak_scale=46.
			"desert": h+=core*(35.+variation*10.+sin(x*.05+z*.04)*8.);peak_scale=12.
			"mystic": h+=core*(70.+variation*28.+crags*48.);peak_scale=32.
			"storm": h+=core*(57.+variation*24.+crags*34.);peak_scale=26.
			"shadow": h+=core*(64.+variation*26.+crags*40.);peak_scale=30.
			_: h+=core*(24.+variation*10.+crags*8.)
		if lobe>=0:
			# Off-centre ridges: every island gets two shoulders at fixed angles so it is no longer a single cone.
			var angle:=atan2(z,x)
			for k: int in 2:
				var a0:=float((lobe*5+k*4)%13)*.48
				var r0:=.34+float((lobe*3+k*2)%5)*.07
				var lobe_shape:=pow(.5+.5*cos(angle-a0),2.)
				h+=peak_scale*exp(-pow((radius-r0)/.2,2.))*lobe_shape*(.7+variation*.5)
	if playable:
		if radius>.84:
			h=lerpf(h,-.8,smoothstep(.84,1.,radius))
	else:
		# Islands are broad and low like the world-map art; only glacier and mountain islands keep real relief.
		h=1.25+(h-1.25)*float(RELIEF.get(biome,.35))
		h=_carve_water(h,x,z,lobe)
		# Land fades to exactly sea level on the contour shared with Layout.coast, then drops to the shelf.
		var shore:=1./SHORE_PAD
		h*=1.-smoothstep(.78,shore,radius)
		if radius>shore: h=-.8*smoothstep(shore,1.,radius)
	return h

func _decorate_remote_island(center: Vector3,size: Vector2,biome: String,palette: Dictionary,lobe: int=-1) -> void:
	# Headlands make every island readable from the water; foliage density stays bounded for large-world performance.
	for j: int in [0,1,3,4,5,6,7]:
		var a:=float(j)*TAU/8.
		var rim:=_island_offset(lobe,size,a,1./SHORE_PAD)
		_make_rock(center+Vector3(rim.x,-.05,rim.y),Vector3(2.8,2.1,3.5))
	_plant_remote_flora(center,size,biome,palette,lobe)
	_build_water(center,size,biome,lobe)
	_scatter_ground_cover(center,size,biome,lobe)
	_populate_wildlife(center,size,biome,lobe)
	if biome=="volcanic":
		var magma:=G.material(Color("ff5e2d"));magma.emission_enabled=true;magma.emission=Color("ff3716");magma.emission_energy_multiplier=1.8
		G.cylinder(self,center+Vector3(0,_island_height(0,0,0.,false,biome,lobe)+.55,0),8.,.5,magma,5.6,24)
	elif biome=="mystic" or biome=="storm" or biome=="shadow":
		var glow_color:=Color("54d7d3") if biome=="mystic" else Color("b56cff")
		var glow:=G.material(glow_color);glow.emission_enabled=true;glow.emission=glow_color;glow.emission_energy_multiplier=1.25
		for i: int in 4:
			var a:=float(i)*TAU/4.+.3;var off:=_island_offset(lobe,size,a,.22)
			var p:=center+Vector3(off.x,_island_height(off.x,off.y,.22,false,biome,lobe)+1.,off.y)
			G.sphere(self,p,Vector3(1.2,2.8,1.2),glow,12)

## Flora mix per biome: [kind, weight]. Kinds starting with "glb" use the imported meshes, the rest are procedural.
const FLORA_MIX: Dictionary={
	"tropical":[["glb2",.34],["glb3",.26],["shrub",.28],["reed",.12]],
	"frost":[["snowpine",.55],["glb0",.2],["shrub",.1],["dead",.15]],
	"mountain":[["pine",.55],["glb0",.2],["windpine",.15],["shrub",.1]],
	"desert":[["cactus",.38],["agave",.4],["dead",.22]],
	"volcanic":[["charred",.7],["dead",.12],["agave",.18]],
	"storm":[["windpine",.55],["dead",.25],["shrub",.2]],
	"shadow":[["twisted_violet",.6],["dead",.25],["reed",.15]],
	"mystic":[["twisted_teal",.6],["glb1",.15],["reed",.25]],
}

## Lakes and streams. Each water-bearing island gets one pond (an oasis in the desert) and, on every other island, a
## stream running from it to the coast. The terrain is carved here and the water surface is built in _build_water.
var pond_info: Dictionary={}
func _plan_water(lobe: int,size: Vector2,biome: String) -> void:
	if biome in ["volcanic","frost"]:return
	var angle:=fposmod(float(lobe)*2.39996,TAU)
	var pc:=_island_offset(lobe,size,angle,.33)
	var radius:=clampf(minf(size.x,size.y)*.07,14.,34.)*(.55 if biome=="desert" else 1.)
	var out:=pc.normalized()
	pond_info[lobe]={"c":pc,"r":radius,"dir":out,"river":lobe%2==0 and biome!="desert"}

func _carve_water(h: float,x: float,z: float,lobe: int) -> float:
	if lobe<0 or not pond_info.has(lobe):return h
	var info: Dictionary=pond_info[lobe]
	var rel:=Vector2(x,z)-(info["c"] as Vector2);var rad: float=info["r"]
	var d:=rel.length()
	h=lerpf(h,1.6,smoothstep(rad*2.6,rad*1.4,d))
	h=lerpf(h,.45,smoothstep(rad*1.15,rad*.7,d))
	if info["river"]:
		var dir: Vector2=info["dir"]
		var t:=rel.dot(dir);var perp:=absf(rel.dot(Vector2(-dir.y,dir.x)))
		h-=smoothstep(rad*.6,rad*1.5,t)*smoothstep(5.5,1.8,perp)*1.7
	return h

func _build_water(center: Vector3,size: Vector2,biome: String,lobe: int) -> void:
	if lobe<0 or not pond_info.has(lobe):return
	var info: Dictionary=pond_info[lobe];var pc: Vector2=info["c"];var rad: float=info["r"]
	var ground:=_island_height(pc.x,pc.y,0.,false,biome,lobe)
	var lake:=G.cylinder(self,center+Vector3(pc.x,1.0,pc.y),rad*1.02,.04,Life.water_material(),-1.,28)
	lake.name="Lagoa";lake.add_to_group("lagoa");lake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not info["river"]:return
	var dir: Vector2=info["dir"];var side:=Vector2(-dir.y,dir.x)
	var verts:=PackedVector3Array();var level:=1.0;var steps:=0
	var t:=rad*.9
	while t<rad*9. and steps<80:
		var c:=pc+dir*t
		var bed:=_island_height(c.x,c.y,0.,false,biome,lobe)
		if bed+.5<.28:break
		level=minf(level,bed+.5)
		for sgn: float in [-1.,1.]:
			var q:=c+side*sgn*3.4
			verts.append(center+Vector3(q.x,level,q.y))
		t+=6.;steps+=1
	if steps<3:return
	var idx:=PackedInt32Array()
	for i: int in steps-1:
		var a:=i*2;idx.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
	var mesh:=G.polygon_mesh(verts,idx)
	var ribbon:=G.mesh_node(self,mesh,Life.water_material(),Vector3.ZERO);ribbon.name="Riacho";ribbon.add_to_group("riacho");ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _near_water(x: float,z: float,lobe: int,margin: float) -> bool:
	if lobe<0 or not pond_info.has(lobe):return false
	var info: Dictionary=pond_info[lobe];var rel:=Vector2(x,z)-(info["c"] as Vector2)
	if rel.length()<float(info["r"])*margin:return true
	if info["river"]:
		var dir: Vector2=info["dir"];var t:=rel.dot(dir)
		return t>0. and absf(rel.dot(Vector2(-dir.y,dir.x)))<5. and t<float(info["r"])*9.
	return false

func _scatter_ground_cover(center: Vector3,size: Vector2,biome: String,lobe: int) -> void:
	var style: Array=Life.GRASS_STYLE.get(biome,Life.GRASS_STYLE["verdant"])
	var area:=PI*size.x*size.y*.5
	var count:=int(minf(area/1000.*float(style[2])*5.,6000.))
	var points: Array[Vector3]=[]
	var clusters: Array[Vector2]=[]
	for c: int in 14:clusters.append(Vector2(rng.randf()*TAU,rng.randf_range(.15,.6)))
	for i: int in count:
		var cl:=clusters[i%clusters.size()]
		var angle:=cl.x+rng.randfn(0.,.28);var r:=clampf(cl.y+rng.randfn(0.,.07),.08,.64)
		if i%5==0:angle=rng.randf()*TAU;r=rng.randf_range(.1,.62)
		var o:=_island_offset(lobe,size,angle,r)
		var g:=_island_height(o.x,o.y,r,false,biome,lobe)
		if g<1.3 or _near_water(o.x,o.y,lobe,1.2):continue
		points.append(center+Vector3(o.x,g-.05,o.y))
	Life.plant_grass(self,biome,points,rng)
	var rocks:int={"mountain":34,"storm":28,"volcanic":30,"frost":22,"desert":18,"shadow":20}.get(biome,12)
	for i: int in rocks:
		var angle:=rng.randf()*TAU;var r:=rng.randf_range(.12,.64)
		var o:=_island_offset(lobe,size,angle,r)
		var g:=_island_height(o.x,o.y,r,false,biome,lobe)
		if g<1.6 or _near_water(o.x,o.y,lobe,1.3):continue
		var w:=rng.randf_range(1.2,4.6)
		_make_rock(center+Vector3(o.x,g-.3,o.y),Vector3(w,w*rng.randf_range(.5,.9),w*rng.randf_range(.8,1.3)))

## Finds a flat spot (|slope| small over 3 m) on dry land within the radius band; Vector3.INF if none is found.
func _flat_spot(center: Vector3,size: Vector2,biome: String,lobe: int,rmin: float,rmax: float,wet: float=0.) -> Vector3:
	# Gentle slopes are fine for grazing animals; the search widens over attempts so every herd finds a spot.
	for attempt: int in 60:
		var angle:=rng.randf()*TAU;var r:=rng.randf_range(rmin,rmax)
		var o:=_island_offset(lobe,size,angle,r)
		var g:=_island_height(o.x,o.y,r,false,biome,lobe)
		if g<1.25 or _near_water(o.x,o.y,lobe,1.2):continue
		var limit:=.5 if attempt<30 else 1.4
		var flat:=true
		for d: Vector2 in [Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
			if absf(_island_height(o.x+d.x,o.y+d.y,r,false,biome,lobe)-g)>limit:flat=false
		if flat:return center+Vector3(o.x,g,o.y)
	return Vector3.INF

func _populate_wildlife(center: Vector3,size: Vector2,biome: String,lobe: int) -> void:
	var holder:=Node3D.new();holder.name="Fauna";add_child(holder)
	var span:=minf(size.x,size.y)
	var high:=38.
	if biome in ["mountain","frost","mystic","storm"]:high=85.
	var flocks:Array=[]
	match biome:
		"tropical":flocks=[["papagaio",7],["gaivota",9]]
		"mystic":flocks=[["papagaio",6],["gaivota",5]]
		"mountain":flocks=[["corvo",5],["gaivota",6]]
		"desert":flocks=[["urubu",5]]
		"shadow","storm":flocks=[["corvo",9]]
		"volcanic":flocks=[["corvo",5]]
		"frost":flocks=[["gaivota",9]]
		_:flocks=[["gaivota",11],["corvo",3]]
	for f: Array in flocks:
		Life.make_birds(holder,str(f[0]),center+Vector3(0,high,0),span*.8,int(f[1]),rng)
	var herd: Array=[]
	match biome:
		"tropical":herd=[["capivara",5,.2,.55],["caranguejo",12,.58,.68]]
		"mountain":herd=[["cabra",9,.2,.55]]
		"frost":herd=[["pinguim",12,.56,.68]]
		"storm":herd=[["cabra",4,.2,.5]]
		"desert":herd=[["lagarto",9,.15,.6]]
		"mystic":herd=[["cervo_mistico",5,.2,.55]]
		"volcanic","shadow":herd=[]
		_:herd=[["cabra",4,.2,.55],["cervo",4,.2,.55],["capivara",3,.2,.5]]
	for h: Array in herd:
		var spots: Array[Vector3]=[]
		# Animals of one kind graze in a loose group: the first spot is the anchor, the rest are drawn near it.
		for i: int in int(h[1]):
			var spot:=_flat_spot(center,size,biome,lobe,float(h[2]),float(h[3]))
			if spot!=Vector3.INF:spots.append(spot)
		Life.make_animals(holder,str(h[0]),spots,rng)

func _plant_remote_flora(center: Vector3,size: Vector2,biome: String,palette: Dictionary,lobe: int) -> void:
	var mix: Array=FLORA_MIX.get(biome,[["glb1",.45],["glb0",.2],["shrub",.25],["reed",.1]])
	var count:=int(float(palette["trees"])*clampf(size.x*size.y/90000.,.6,4.5)*4.0)
	var groups: Dictionary={}
	var clusters: Array[Vector2]=[]
	for c: int in 5:clusters.append(Vector2(rng.randf()*TAU,rng.randf_range(.2,.5)))
	for i: int in count:
		# Two thirds of the plants gather in groves, the rest scatter, so islands read as meadows and woods rather than noise.
		var angle:=rng.randf()*TAU;var r:=rng.randf_range(.1,.6)
		if i%3!=0:
			var cl:=clusters[i%clusters.size()]
			angle=cl.x+rng.randfn(0.,.35);r=clampf(cl.y+rng.randfn(0.,.09),.08,.64)
		var offset:=_island_offset(lobe,size,angle,r)
		var ground:=_island_height(offset.x,offset.y,r,false,biome,lobe)
		if ground<1.4:continue
		var roll:=rng.randf();var pick:=""
		for entry: Array in mix:
			roll-=float(entry[1])
			if roll<=0.:pick=str(entry[0]);break
		if pick=="":pick=str(mix[0][0])
		var scale_value:=rng.randf_range(.85,1.5)
		var at:=center+Vector3(offset.x,ground-.12,offset.y)
		var basis:=Basis(Vector3.UP,rng.randf()*TAU)
		if pick.begins_with("glb"):
			basis=basis.scaled(Vector3.ONE*scale_value*.68)
		else:
			basis=basis.scaled(Vector3(scale_value*rng.randf_range(.9,1.1),scale_value,scale_value*rng.randf_range(.9,1.1)))
		if not groups.has(pick):groups[pick]=[] as Array[Transform3D]
		(groups[pick] as Array[Transform3D]).append(Transform3D(basis,at))
	for pick: String in groups:
		if pick.begins_with("glb"):NatureLib.grove(self,int(pick.substr(3)),groups[pick])
		else:Flora.plant(self,pick,groups[pick],rng)

func home_surface_height(x: float,z: float) -> float:
	return Layout.height(Vector2(x,z))

func _make_dock() -> void:
	G.box(self, Vector3(0, 1.2, -17), Vector3(3.6, 0.3, 18), dark_wood, true)
	G.box(self,Vector3(0,1.2,-5),Vector3(3.6,.3,6),dark_wood,true)
	for i: int in range(45):
		var plank := G.box(self, Vector3(0, 1.365, -8.2 - i * 0.4), Vector3(3.6, 0.055, 0.37), wood if i % 3 else cream)
		plank.material_override = wood
		plank.rotation.y = rng.randf_range(-.004,.004)
	for z: float in [-9.0, -14.0, -19.0, -25.0]:
		for x: float in [-1.65, 1.65]:
			G.cylinder(self, Vector3(x, 0.4, z), 0.16, 3.5, dark_wood, 0.13)
			G.cylinder(self, Vector3(x, 1.97, z), 0.19, 0.12, wood)
	for x: float in [-1.65, 1.65]:
		G.beam(self, Vector3(x, 1.85, -9), Vector3(x, 1.85, -19), 0.035, cream)
		G.beam(self, Vector3(x, 1.7, -9), Vector3(x, 1.7, -19), 0.025, cream)
	# Open boarding gap at the end of the pier.
	G.box(self, Vector3(-1.1, 1.65, -22), Vector3(0.7, 0.55, 1), teal, true)
	G.box(self, Vector3(-1.1, 1.95, -22), Vector3(0.76, 0.08, 1.06), cream)
	_make_lamp(Vector3(-1.55, 1.35, -25))
	_make_lamp(Vector3(1.55, 1.35, -10))

func _make_lamp(pos: Vector3) -> void:
	G.cylinder(self, pos + Vector3(0, 1.15, 0), 0.07, 2.3, dark_wood)
	G.box(self, pos + Vector3(0, 2.4, 0), Vector3(0.28, 0.48, 0.28), dark_wood)
	var glow := G.material(Color("ffd286"))
	glow.emission_enabled = true
	glow.emission = Color("ffc276")
	glow.emission_energy_multiplier = 0.8
	G.box(self, pos + Vector3(0, 2.4, -0.15), Vector3(0.19, 0.31, 0.025), glow)
	G.cylinder(self, pos + Vector3(0, 2.7, 0), 0.25, 0.2, dark_wood, 0.04)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 2.35, 0)
	light.light_color = Color("ffc385")
	light.light_energy = 0.6
	light.omni_range = 6
	add_child(light)

func _make_cabin(pos: Vector3, angle: float, main: bool) -> void:
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = angle
	add_child(house)
	G.box(house, Vector3(0, 0.14, 0), Vector3(6.4, 0.28, 5), rock, true)
	G.box(house, Vector3(0, 1.65, 0), Vector3(5.8, 3.0, 4.6), teal, true)
	for y: float in [0.45, 0.85, 1.25, 1.65, 2.05, 2.45, 2.85]:
		G.box(house, Vector3(0, y, -2.32), Vector3(5.86, 0.035, 0.05), dark_wood)
	for x: float in [-2.95, 2.95]:
		G.box(house, Vector3(x, 1.7, -2.35), Vector3(0.14, 3.1, 0.14), cream)
	var roof_vertices := PackedVector3Array([Vector3(-3.5, 3.1, -2.9), Vector3(3.5, 3.1, -2.9), Vector3(0, 4.8, -2.9), Vector3(-3.5, 3.1, 2.9), Vector3(3.5, 3.1, 2.9), Vector3(0, 4.8, 2.9)])
	var roof_mat := Materials.surface("weathered_wood",Color("947c70") if main else Color("7a8887"),1.8)
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	G.mesh_node(house, G.polygon_mesh(roof_vertices, PackedInt32Array([0,2,1,3,4,5,0,3,5,0,5,2,2,5,4,2,4,1])), roof_mat, Vector3.ZERO)
	# Clad gables and timber siding give the existing footprint construction scale.
	for x_index: int in range(-6,7):
		var x:=float(x_index)*.46
		var height:=1.7*(1.-absf(x)/3.5)
		for z: float in [-2.92,2.92]:
			G.box(house,Vector3(x,3.1+height*.5,z),Vector3(.43,height,.045),teal)
	for y: float in [.45,.85,1.25,1.65,2.05,2.45,2.85]:
		for x: float in [-2.92,2.92]:
			G.box(house,Vector3(x,y,0),Vector3(.04,.035,4.62),dark_wood)
	for z_index: int in range(15):
		var z:=-2.8+z_index*.4
		G.beam(house,Vector3(-3.5,3.12,z),Vector3(0,4.82,z),.018,roof_mat)
		G.beam(house,Vector3(0,4.82,z),Vector3(3.5,3.12,z),.018,roof_mat)
	for z: float in [-2.95, 2.95]:
		G.beam(house, Vector3(-3.5, 3.1, z), Vector3(0, 4.8, z), 0.095, cream)
		G.beam(house, Vector3(0, 4.8, z), Vector3(3.5, 3.1, z), 0.095, cream)
	G.box(house, Vector3(0, 1.2, -2.38), Vector3(1.05, 2.1, 0.1), dark_wood)
	G.sphere(house, Vector3(0.34, 1.15, -2.46), Vector3(0.055, 0.055, 0.055), cream)
	var warm := G.material(Color("ffcf86"))
	warm.emission_enabled = true
	warm.emission = Color("e3a454")
	warm.emission_energy_multiplier = 0.5
	for x: float in [-1.8, 1.8]:
		G.box(house, Vector3(x, 1.9, -2.39), Vector3(1.2, 1.35, 0.12), cream)
		G.box(house, Vector3(x, 1.9, -2.47), Vector3(1.0, 1.12, 0.05), warm)
		G.box(house, Vector3(x, 1.9, -2.51), Vector3(0.06, 1.12, 0.05), dark_wood)
		G.box(house, Vector3(x, 1.9, -2.51), Vector3(1.0, 0.06, 0.05), dark_wood)
		G.box(house, Vector3(x, 1.15, -2.6), Vector3(1.3, 0.15, 0.42), wood)
		for side: float in [-1.,1.]:
			G.box(house,Vector3(x+side*.78,1.9,-2.40),Vector3(.25,1.3,.07),wood)
	G.box(house, Vector3(1.9, 4.15, 1.3), Vector3(0.6, 2.0, 0.6), rock)
	G.box(house, Vector3(1.9, 5.15, 1.3), Vector3(0.8, 0.15, 0.8), cream)
	G.box(house, Vector3(0, 0.1, -3.1), Vector3(5.6, 0.2, 1.6), wood)
	if main:
		G.label(house, "CABANA DO FAROLEIRO", Vector3(0, 2.8, -2.5), 19)
	_make_lamp(pos + Vector3(-3.6, 0, -3.0))

func _make_market() -> void:
	var stall := Node3D.new()
	stall.position = Vector3(6, 1.25, -3.0)
	add_child(stall)
	G.box(stall, Vector3(0, 0.52, 0), Vector3(3.7, 1.04, 1.45), dark_wood, true)
	for x: float in [-1.6,-0.8,0.0,0.8,1.6]:
		G.box(stall, Vector3(x, 0.52, -0.74), Vector3(0.75, 1.0, 0.08), wood)
	G.box(stall, Vector3(0, 1.06, 0), Vector3(4.1, 0.16, 1.7), cream)
	for x: float in [-1.8, 1.8]:
		G.cylinder(stall, Vector3(x, 1.65, 0.5), 0.09, 3.3, dark_wood)
	var canvas := Materials.surface("fabric",Color("b7a383"),5.)
	G.box(stall, Vector3(0, 3.2, 0), Vector3(4.6, 0.12, 2.5), canvas).rotation.x = 0.12
	G.box(stall, Vector3(0, 2.94, -1.22), Vector3(4.6, 0.4, 0.07), teal)
	var label := G.label(stall, "MERCADO  ·  PEIXE FRESCO", Vector3(0, 2.95, -1.28), 24)
	label.rotation.y = PI
	# Labels face toward the approach from the pier.
	label.rotation.y = PI
	G.box(stall, Vector3(-0.8, 1.22, 0), Vector3(1.4, 0.2, 0.9), teal)
	for i: int in range(4):
		var fish := G.sphere(stall, Vector3(-1.25 + i * 0.3, 1.4, -0.1), Vector3(0.12, 0.1, 0.3), G.material(Color("8caaa4")))
		fish.rotation.y = 0.25
	var vendor=preload("res://scripts/player/imported_angler.gd").new()
	vendor.position=Vector3(6.7,1.25,-1.5);add_child(vendor)
	_make_barrel(Vector3(8.7, 1.25, -2.4))
	_make_barrel(Vector3(9.2, 1.25, -1.3))

func _make_barrel(pos: Vector3) -> void:
	G.cylinder(self, pos + Vector3(0,0.5,0), 0.43, 1.0, wood, 0.39, 12)
	for y: float in [0.15,0.8]:
		G.cylinder(self, pos + Vector3(0,y,0), 0.44, 0.08, dark_wood, 0.44, 12)

func _make_foliage() -> void:
	for i: int in range(30):
		var x := rng.randf_range(-21,21)
		var z := rng.randf_range(0,42)
		if absf(x) < 4.0 or Vector2(x + 12, z - 7).length() < 7.2 or Vector2(x - 13,z - 16).length() < 7.0:
			continue
		if Vector2(x / 29, (z - 18) / 32).length() > 0.74:
			continue
		_make_tree(Vector3(x,home_surface_height(x,z),z), rng.randf_range(0.75,1.35))
	for i: int in range(23):
		var angle := rng.randf() * TAU
		var pos := Vector3(cos(angle) * 25.0,0.8,sin(angle) * 28.0 + 18.0)
		if absf(pos.x) < 5.0 and pos.z < 0:
			continue
		_make_rock(pos, Vector3(rng.randf_range(0.65,1.7),rng.randf_range(0.5,1.2),rng.randf_range(0.7,1.9)))
	for i: int in range(45):
		var pos := Vector3(rng.randf_range(-22,22),1.22,rng.randf_range(-2,41))
		if Vector2(pos.x / 29,(pos.z - 18) / 32).length() > 0.77 or absf(pos.x) < 4:
			continue
		if Vector2(pos.x + 12, pos.z - 7).length() < 5.5 or Vector2(pos.x - 13,pos.z - 16).length() < 5.5:
			continue
		pos.y=home_surface_height(pos.x,pos.z)
		Details.shrub(self,pos,rng)

func _make_tree(pos: Vector3, tree_scale: float) -> void:
	var kind:=rng.randi_range(0,3)
	if pos.z<80. and absf(pos.x)<110.:kind=2 if rng.randf()<.65 else 1
	preload("res://scripts/world/nature_library.gd").plant(self,kind,pos,tree_scale*.65,rng.randf()*TAU)

func _make_rock(pos: Vector3, dimensions: Vector3) -> void:
	if pos.y<1.5:
		var c:=Waves.coast(Vector2(pos.x,pos.z))
		shore_rocks.append(pos+Vector3(c.y,0,c.z)*maxf(dimensions.x,dimensions.z)*1.05)
	var node := Details.stone(self, pos, dimensions, rock, rng.randi())
	node.rotation.y = rng.randf() * TAU

## People on the long trails plus a keeper at each lighthouse. They walk the authored paths the player uses,
## out and back, staggered so the island does not feel empty outside the village.
var trail_walkers: Node3D
func _make_trail_walkers() -> Node3D:
	var holder:=Node3D.new();holder.name="Caminhantes";add_child(holder)
	var Resident:=preload("res://scripts/world/village_resident.gd")
	var specs:=[[Layout.TRAIL,0,1.15],[Layout.TRAIL,7,.95],[Layout.WEST_TRAIL,2,1.05],[Layout.EAST_TRAIL,1,.9],[Layout.NORTH_TRAIL,3,1.0],[Layout.OLD_PORT_TRAIL,0,.85]]
	for i: int in specs.size():
		var points: Array=specs[i][0];var start: int=specs[i][1]
		var out_and_back: Array[Vector3]=[]
		for p: Vector3 in points:out_and_back.append(p)
		for k: int in range(points.size()-2,0,-1):out_and_back.append(points[k])
		var walker:=Resident.new();walker.route.assign(out_and_back);walker.speed=float(specs[i][2]);walker.look_id=14+i
		holder.add_child(walker)
		walker.target_index=mini(start,out_and_back.size()-1);walker.position=out_and_back[walker.target_index]
	for keeper_spec: Array in [[Vector3(170.2,0,99.6),2.4],[Vector3(-61.,0,494.5),2.1]]:
		var keeper:=Resident.new();keeper.look_id=20+(0 if keeper_spec[0].x>0. else 1)
		var at: Vector3=keeper_spec[0];at.y=Layout.height(Vector2(at.x,at.z))+.08
		keeper.position=at;keeper.rotation.y=float(keeper_spec[1]);holder.add_child(keeper)
	return holder

func _make_lighthouse(pos: Vector3) -> void:
	lighthouse=preload("res://scripts/world/navigation_lighthouse.gd").new();lighthouse.world=self;lighthouse.position=pos;lighthouse.name="FarolDaAurora";lighthouse.period=16.;lighthouse.beam_angles=[0.,26.];lighthouse.phase=4.;lighthouse.tint=Color("f6f3e6");add_child(lighthouse)

func _make_wildlife() -> void:
	var white := G.material(Color("eee6cf"))
	for i: int in range(7):
		var gull := Node3D.new()
		add_child(gull)
		var vertices := PackedVector3Array([Vector3(0,0,-0.25),Vector3(-0.9,0.1,0.18),Vector3(-0.4,0.03,0.05),Vector3(0,0,0.15),Vector3(0.9,0.1,0.18),Vector3(0.4,0.03,0.05)])
		var mat := white.duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		G.mesh_node(gull,G.polygon_mesh(vertices,PackedInt32Array([0,1,2,0,2,3,0,3,5,0,5,4])),mat,Vector3.ZERO)
		gulls.append(gull)

func _make_buoy(pos: Vector3) -> void:
	var buoy := Node3D.new()
	buoy.position = pos
	add_child(buoy)
	G.sphere(buoy,Vector3(0,0,0),Vector3(0.55,0.2,0.55),teal)
	G.cylinder(buoy,Vector3(0,0.55,0),0.18,1.1,cream,0.14)
	G.cylinder(buoy,Vector3(0,1.15,0),0.23,0.25,G.material(Color("c87147")),0.0)
	buoys.append(buoy)

func _make_sign() -> void:
	G.cylinder(self,Vector3(-3.5,2.1,-5),0.09,1.7,dark_wood)
	G.box(self,Vector3(-3.5,2.8,-5),Vector3(3,0.6,0.12),teal)
	G.label(self,"ENSEADA DA AURORA",Vector3(-3.5,2.82,-5.08),20)

func _process(delta: float) -> void:
	elapsed += delta
	preload("res://scripts/world/nature_library.gd").wind(Waves.time,Waves.wind,Waves.direction)
	for i: int in range(gulls.size()):
		var phase := elapsed * (0.14 + i * 0.006) + i * 1.8
		gulls[i].position = Vector3(cos(phase) * (20 + i * 4), 13 + i * 1.8 + sin(elapsed * 0.5 + i), -25 + sin(phase) * (18 + i * 4))
		gulls[i].rotation.y = -phase
		gulls[i].rotation.z = sin(elapsed * 2.0 + i) * 0.08
	for i: int in range(buoys.size()):
		buoys[i].position.y = Waves.height_at(buoys[i].global_position)
		buoys[i].rotation.z = sin(elapsed + i) * 0.05
