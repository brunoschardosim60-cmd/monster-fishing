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
var glow: MeshInstance3D
var glow_material: ShaderMaterial
const BEAM_LENGTH: float=800.
const BEAM_HALF_ANGLE: float=3.4
func _ready() -> void:
	var stone:=M.surface("lime_plaster",Color("ded9c3"),.7)
	var metal:=G.material(Color("31484d"),.34);metal.metallic=.6
	G.cylinder(self,Vector3(0,.3,0),3.,.6,stone,3.,48)
	G.cylinder(self,Vector3(0,7.,0),2.25,13.4,stone,1.5,48)
	for y: float in [1.1,7.8,12.8]:G.cylinder(self,Vector3(0,y,0),lerpf(2.25,1.5,y/14.)+.08,.22,metal,-1.,48)
	G.box(self,Vector3(0,1.3,-2.19),Vector3(1.1,2.1,.12),M.surface("weathered_wood",Color("695743"),2.))
	for y: float in [4.,8.,11.]:G.box(self,Vector3(0,y,-lerpf(2.25,1.5,y/14.)),Vector3(.45,.85,.12),metal)
	G.cylinder(self,Vector3(0,13.6,0),2.5,.3,metal,2.5,48)
	for i: int in 32:
		var a:=float(i)*TAU/32.;var b:=float(i+1)*TAU/32.
		G.beam(self,Vector3(cos(a)*2.3,13.75,sin(a)*2.3),Vector3(cos(a)*2.3,14.7,sin(a)*2.3),.035,metal)
		G.beam(self,Vector3(cos(a)*2.3,14.7,sin(a)*2.3),Vector3(cos(b)*2.3,14.7,sin(b)*2.3),.045,metal)
	for i: int in 8:
		var a:=float(i)*TAU/8.;G.cylinder(self,Vector3(cos(a)*1.4,14.9,sin(a)*1.4),.05,2.3,metal,-1.,12)
	G.cylinder(self,Vector3(0,16.3,0),1.9,1.1,metal,.08,48)
	G.cylinder(self,Vector3(0,17.1,0),.035,1.,metal,-1.,12)
	rotor=Node3D.new();rotor.position.y=14.9;add_child(rotor)
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
		beam_materials.append(mat)
	elapsed=phase
	preload("res://scripts/world/static_batch.gd").build(self,[rotor])
	# Added after batching so the flare is never merged into the tower mesh.
	glow_material=ShaderMaterial.new();glow_material.shader=preload("res://assets/shaders/lighthouse_glow.gdshader");glow_material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
	glow=G.mesh_node(self,QuadMesh.new(),glow_material,Vector3(0,14.9,0));glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	for mat: ShaderMaterial in beam_materials:mat.set_shader_parameter("strength",night*haze)
	var flash:=0.
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:
		var to_camera: Vector3=(camera.global_position-rotor.global_position).normalized()
		for arm: Node3D in arms:flash=maxf(flash,pow(maxf(0.,(-arm.global_basis.z).dot(to_camera)),40.))
	lens.emission_energy_multiplier=(2.+flash*18.)*night
	glow_material.set_shader_parameter("intensity",night*(.16+flash*1.5)*(1.+(haze-1.)*.5))
