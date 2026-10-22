extends Node3D
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
func _ready() -> void:
	var teak:=M.surface("teak",Color("b39369"),2.)
	var steel:=G.material(Color("aab6b4"),.24);steel.metallic=.78
	var rope:=M.surface("fabric",Color("b0a484"),5.)
	var rubber:=G.material(Color("24363c"),.8)
	var fender:=G.material(Color("d5d6c8"),.45)
	# Deck insets, seams, fittings and a padded stern bench leave the helm lane clear.
	for i: int in range(-6,7):
		G.box(self,Vector3(i*.19,1.125,2.12),Vector3(.182,.025,2.55),teak)
	for x: float in [-1.42,1.42]:
		for z: float in [1.25,2.65]:
			G.beam(self,Vector3(x,1.35,z),Vector3(x*1.12,.9,z),.018,rope)
			G.cylinder(self,Vector3(x*1.12,.6,z),.135,.6,fender,.135,24)
			G.sphere(self,Vector3(x*1.12,.3,z),Vector3(.135,.14,.135),fender,16)
			G.sphere(self,Vector3(x*1.12,.9,z),Vector3(.135,.14,.135),fender,16)
		for z: float in [-2.1,3.1]:
			G.box(self,Vector3(x,1.46,z),Vector3(.16,.06,.32),steel)
			G.beam(self,Vector3(x,1.48,z-.18),Vector3(x,1.48,z+.18),.028,steel)
		# Raised aft rails follow the gunwale and move with the wave-following hull.
		for z: float in [1.2,2.2,3.2]:G.beam(self,Vector3(x,1.38,z),Vector3(x,1.95,z),.026,steel)
		G.beam(self,Vector3(x,1.95,1.2),Vector3(x,1.95,3.2),.029,steel)
		G.beam(self,Vector3(x,1.65,1.2),Vector3(x,1.65,3.2),.018,steel)
		G.cylinder(self,Vector3(x*.9,1.64,2.8),.055,.4,steel,.055,16).rotation.x=.3
	for i: int in 5:
		var ring:=TorusMesh.new();ring.inner_radius=.15+i*.022;ring.outer_radius=.168+i*.022;ring.rings=32;ring.ring_segments=6
		G.mesh_node(self,ring,rope,Vector3(-.85,1.17,2.9))
	G.box(self,Vector3(0,1.38,3.25),Vector3(2.25,.42,.48),teak)
	G.box(self,Vector3(0,1.62,3.25),Vector3(2.2,.12,.46),rubber)
	for x: float in [-.75,.75]:G.box(self,Vector3(x,1.27,3.25),Vector3(.1,.35,.38),steel)
	var chest:=G.box(self,Vector3(-1.04,1.32,1.55),Vector3(.42,.36,.7),rubber)
	G.box(self,chest.position+Vector3(0,.2,0),Vector3(.45,.06,.73),teak)
	for z: float in [1.34,1.76]:G.box(self,Vector3(-.81,1.44,z),Vector3(.025,.08,.06),steel)
	preload("res://scripts/world/static_batch.gd").build(self,[])
