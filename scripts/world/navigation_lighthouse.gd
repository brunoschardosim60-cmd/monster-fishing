extends Node3D
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
var world: Node3D
var rotor: Node3D
var lens: StandardMaterial3D
var elapsed: float=0.
## Each lighthouse has its own light character so sailors can tell them apart: sweep period in seconds,
## beam headings in degrees around the rotor (two beams close together read as a double flash), and a start phase.
var period: float=12.
var beam_angles: Array=[0.]
var phase: float=0.
var tint: Color=Color("ffe7af")
var arms: Array[Node3D]=[]
var spots: Array[SpotLight3D]=[]
var beam_materials: Array[ShaderMaterial]=[]
var cones: Array[MeshInstance3D]=[]
var _trim_frame: int=0
var glow: MeshInstance3D
var glow_material: ShaderMaterial
const BEAM_LENGTH: float=800.
const BEAM_HALF_ANGLE: float=3.4
## Tower height to the gallery floor (m) and paint scheme: faixas (red/white), preto (black/white),
## pedra (bare granite), amarelo (yellow with a dark lantern). A keeper's house stands at the foot.
var tower_height: float=30.
var style: String="faixas"
var keeper_house: bool=true
func _ready() -> void:
	var top:=_build_tower()
	rotor=Node3D.new();rotor.position.y=top+1.25;add_child(rotor)
	lens=G.material(Color("fff0bc"));lens.emission_enabled=true; lens.emission=Color("ffedbd");lens.emission_energy_multiplier=5.
	for y: int in 9:
		var ring:=TorusMesh.new();ring.inner_radius=.37;ring.outer_radius=.48;ring.rings=32;ring.ring_segments=6;G.mesh_node(rotor,ring,lens,Vector3(0,(y-4)*.13,0))
	# Every beam is a real spotlight plus a matching visible shaft of the same cone.
	var radius:=tan(deg_to_rad(BEAM_HALF_ANGLE))*BEAM_LENGTH
	for angle_value: Variant in beam_angles:
		var angle:=float(angle_value)
		var arm:=Node3D.new();arm.rotation=Vector3(-.03,deg_to_rad(angle),0.);rotor.add_child(arm);arms.append(arm)
		var spot:=SpotLight3D.new();spot.spot_range=BEAM_LENGTH;spot.spot_angle=BEAM_HALF_ANGLE+1.;spot.light_energy=12.;spot.light_color=tint;arm.add_child(spot);spots.append(spot)
		var shaft:=CylinderMesh.new();shaft.top_radius=radius;shaft.bottom_radius=.15;shaft.height=BEAM_LENGTH;shaft.radial_segments=32;shaft.rings=1;shaft.cap_top=false;shaft.cap_bottom=false
		var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/lighthouse_beam.gdshader");mat.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
		var cone:=G.mesh_node(arm,shaft,mat,Vector3(0,0,-BEAM_LENGTH*.5));cone.rotation.x=-PI*.5;cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam_materials.append(mat);cones.append(cone)
	elapsed=phase
	preload("res://scripts/world/static_batch.gd").build(self,[rotor])
	# Added after batching so the flare is never merged into the tower mesh.
	glow_material=ShaderMaterial.new();glow_material.shader=preload("res://assets/shaders/lighthouse_glow.gdshader");glow_material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
	glow=G.mesh_node(self,QuadMesh.new(),glow_material,Vector3(0,rotor.position.y,0));glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.custom_aabb=AABB(Vector3(-300,-300,-300),Vector3(600,600,600));glow.visibility_range_end=7000.
func _process(delta: float) -> void:
	elapsed+=delta;rotor.rotation.y=fposmod(elapsed*TAU/period,TAU)
	var darkness: float=1. if world.ocean==null else 1.-world.ocean.daylight
	var night:=smoothstep(.08,.55,darkness)
	# Rain, fog and cloud scatter more light, so the shaft is easier to see in bad weather.
	var haze:=1.
	if world.ocean!=null:haze=1.+clampf(world.ocean.weather.rain,0.,1.)*1.1+clampf(world.ocean.weather.fog*320.,0.,1.2)+world.ocean.weather.cloud*.3
	rotor.visible=night>.01;glow.visible=rotor.visible
	for spot: SpotLight3D in spots:spot.light_energy=12.*night
	if rotor.visible:_trim_beams()
	for mat: ShaderMaterial in beam_materials:mat.set_shader_parameter("strength",night*haze)
	var flash:=0.
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:
		var to_camera: Vector3=(camera.global_position-rotor.global_position).normalized()
		for arm: Node3D in arms:flash=maxf(flash,pow(maxf(0.,(-arm.global_basis.z).dot(to_camera)),40.))
	lens.emission_energy_multiplier=(2.+flash*18.)*night
	glow_material.set_shader_parameter("intensity",night*(.16+flash*1.5)*(1.+(haze-1.)*.5))

## The shaft and its spotlight stop at the first solid thing in their way (a house, a cliff, a hull),
## so the light never passes through walls.
func _trim_beams() -> void:
	_trim_frame+=1
	if _trim_frame%2!=0:return
	var space:=get_world_3d().direct_space_state
	var origin:=rotor.global_position;var reach:=BEAM_LENGTH*global_basis.x.length()
	for i: int in arms.size():
		var dir:=-(arms[i].global_basis.z.normalized())
		var q:=PhysicsRayQueryParameters3D.create(origin+dir*3.*global_basis.x.length(),origin+dir*reach);q.collision_mask=1
		var hit:=space.intersect_ray(q)
		var d:=reach if hit.is_empty() else origin.distance_to(hit.position)
		var k:=clampf(d/reach,.02,1.)
		cones[i].scale=Vector3(k,k,k);cones[i].position=Vector3(0,0,-BEAM_LENGTH*.5*k)
		spots[i].spot_range=BEAM_LENGTH*k

## Tapered, banded tower with a gallery, glazed lantern room, dome and vent; returns the gallery height.
func _build_tower() -> float:
	var h:=tower_height
	var plaster:=M.surface("lime_plaster",Color("f2efe6"),.7)
	var stone:=M.surface("granite",Color("b9b6a8"),1.)
	var metal:=G.material(Color("2a3a3f"),.34);metal.metallic=.6
	var colours: Array[Material]
	match style:
		"preto":colours=[plaster,G.material(Color("1d1f22"),.6)]
		"pedra":colours=[stone,stone]
		"amarelo":colours=[M.surface("lime_plaster",Color("f2c84b"),.7),M.surface("lime_plaster",Color("f2c84b"),.7)]
		_:colours=[plaster,M.surface("lime_plaster",Color("c0392b"),.7)]
	G.cylinder(self,Vector3(0,.6,0),4.2,1.2,stone,4.4,48)
	var bands:=8
	for i: int in bands:
		var y0:=1.2+(h-1.2)*float(i)/bands;var y1:=1.2+(h-1.2)*float(i+1)/bands
		var r0:=lerpf(3.2,2.,float(i)/bands);var r1:=lerpf(3.2,2.,float(i+1)/bands)
		G.cylinder(self,Vector3(0,(y0+y1)*.5,0),r1,y1-y0+.02,colours[i%2],r0,40)
	G.box(self,Vector3(0,2.,-3.15),Vector3(1.3,2.6,.3),M.surface("teak",Color("5a3e2a"),1.2))
	for i: int in 5:
		var y:=4.+float(i)*(h-8.)/4.
		var r:=lerpf(3.2,2.,(y-1.2)/(h-1.2))
		G.box(self,Vector3(0,y,-r-.02),Vector3(.5,1.,.1),G.material(Color("26343d"),.2))
	# Gallery and railing.
	G.cylinder(self,Vector3(0,h+.15,0),3.2,.3,metal,3.,48)
	for i: int in 36:
		var a:=float(i)*TAU/36.;var b:=float(i+1)*TAU/36.
		G.beam(self,Vector3(cos(a)*3.,h+.3,sin(a)*3.),Vector3(cos(a)*3.,h+1.3,sin(a)*3.),.035,metal)
		G.beam(self,Vector3(cos(a)*3.,h+1.3,sin(a)*3.),Vector3(cos(b)*3.,h+1.3,sin(b)*3.),.045,metal)
	# Lantern room: glass between thin mullions, a copper dome, a ventilator ball and a lightning rod.
	var glass:=G.material(Color("cfe8ee"),.05);glass.metallic=.2;glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color.a=.35
	G.cylinder(self,Vector3(0,h+.55,0),1.75,.5,metal,1.75,32)
	G.cylinder(self,Vector3(0,h+1.95,0),1.6,2.3,glass,1.6,32)
	for i: int in 10:
		var a:=float(i)*TAU/10.
		G.cylinder(self,Vector3(cos(a)*1.6,h+1.95,sin(a)*1.6),.045,2.3,metal,-1.,8)
	var copper:=G.material(Color("3f6b5a"),.5);copper.metallic=.4
	G.cylinder(self,Vector3(0,h+3.5,0),1.9,.8,copper,.25,32)
	G.sphere(self,Vector3(0,h+4.05,0),Vector3.ONE*.42,copper,16)
	G.cylinder(self,Vector3(0,h+4.9,0),.03,1.4,metal,-1.,8)
	if keeper_house:
		var rng:=RandomNumberGenerator.new();rng.seed=int(absf(position.x)+absf(position.z))
		var house:=preload("res://scripts/world/town_house.gd").build("costeira",6.5,5.,rng,1.)
		house.position=Vector3(-7.5,0.,-3.5);house.rotation.y=PI*.5;add_child(house)
	return h
