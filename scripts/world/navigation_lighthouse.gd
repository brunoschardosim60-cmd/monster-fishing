extends Node3D
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
var world: Node3D
var rotor: Node3D
var beacon: SpotLight3D
var lens: StandardMaterial3D
var elapsed: float=0.
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
	beacon=SpotLight3D.new();beacon.spot_range=650.;beacon.spot_angle=7.;beacon.light_energy=12.;beacon.light_color=Color("ffe7af");beacon.rotation.x=-.035;rotor.add_child(beacon)
	# Visible scattered light; the real spot independently lights nearby surfaces.
	var beam:=CylinderMesh.new();beam.top_radius=8.;beam.bottom_radius=.15;beam.height=150.;beam.radial_segments=24
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/lighthouse_beam.gdshader")
	var cone:=G.mesh_node(rotor,beam,mat,Vector3(0,0,-75));cone.rotation.x=-PI*.5;cone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preload("res://scripts/world/static_batch.gd").build(self,[rotor])
func _process(delta: float) -> void:
	elapsed+=delta;rotor.rotation.y=fposmod(elapsed*TAU/12.,TAU)
	var darkness: float=1. if world.ocean==null else 1.-world.ocean.daylight
	rotor.visible=darkness>.2;beacon.light_energy=12.*darkness
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:
		var to_camera: Vector3=(camera.global_position-rotor.global_position).normalized()
		var alignment:=maxf(0.,(-rotor.global_basis.z).dot(to_camera))
		lens.emission_energy_multiplier=(2.+pow(alignment,48.)*18.)*darkness
