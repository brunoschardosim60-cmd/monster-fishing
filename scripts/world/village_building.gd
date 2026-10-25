extends Node3D
## An accessible room, with a real doorway, ramp, furnishings and simple collision.
@export var title: String="Casa"
@export var width: float=7.
@export var depth: float=6.
@export var tint: Color=Color("71928b")
@export var use: String="home"
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
var entry: Marker3D
var service: Marker3D
var lamps: Array[OmniLight3D]=[]
var windows: StandardMaterial3D

func _ready() -> void:
	var stone:=M.surface("granite",Color("afb2a6"),1.)
	var wall:=M.surface("lime_plaster",Color.WHITE.lerp(tint,.18),.35)
	var trim:=M.surface("weathered_wood",Color("d6ccb2"),2.)
	var wood:=M.surface("teak",Color("b7a180"),1.2)
	var dark:=M.surface("weathered_wood",Color("544d3c"),1.5)
	var half:=width*.5;var back:=depth*.5
	var ground_low:=position.y
	for x: float in [-half,half]:
		for z: float in [-back,back]:ground_low=minf(ground_low,preload("res://scripts/world/archipelago_layout.gd").height(Vector2(position.x+x,position.z+z)))
	var foundation:=maxf(.3,position.y-ground_low+.25)
	G.box(self,Vector3(0,-foundation*.5,0),Vector3(width+.5,foundation,depth+.5),stone,true)
	G.box(self,Vector3(0,.04,0),Vector3(width,.08,depth),wood,true)
	# Walls are separate segments. The central 1.8 m opening has no collision.
	for x: float in [-half,half]: G.box(self,Vector3(x,1.65,0),Vector3(.18,3.3,depth),wall,true)
	G.box(self,Vector3(0,1.65,back),Vector3(width,3.3,.18),wall,true)
	for side: float in [-1.,1.]: G.box(self,Vector3(side*(half+.9)*.5,1.65,-back),Vector3(half-.9,3.3,.18),wall,true)
	G.box(self,Vector3(0,2.94,-back),Vector3(1.8,.72,.18),wall,true)
	var approach: float=preload("res://scripts/world/archipelago_layout.gd").height(Vector2(position.x,position.z-back-4.))-.0
	var rise_to_door:=position.y+.08-approach
	var ramp:=G.box(self,Vector3(0,.03-rise_to_door*.5,-back-2.),Vector3(2.,.1,sqrt(16.+rise_to_door*rise_to_door)),wood,true);ramp.rotation.x=-atan2(rise_to_door,4.)
	entry=Marker3D.new();entry.name="Entry";entry.position=Vector3(0,.1,-back-1.);add_child(entry)
	service=Marker3D.new();service.name="Service";service.position=Vector3(0,.1,-.5);add_child(service)
	# A swung open timber door communicates access without covering the entrance.
	var door:=G.box(self,Vector3(-.94,1.25,-back+.6),Vector3(.1,2.5,1.2),dark,true)
	for y: float in [.5,.9,1.3,1.7,2.1,2.5,2.9]:
		for side: float in [-1.,1.]: G.box(self,Vector3(side*(half+.9)*.5,y,-back-.11),Vector3(half-.9,.035,.04),trim)
	for x: float in [-half,half,-.94,.94]:G.box(self,Vector3(x,1.65,-back-.13),Vector3(.12,3.3,.12),trim)
	var roof:=M.surface("weathered_wood",Color("865f4a") if use!="workshop" else Color("526b70"),1.5)
	var rise:=1.7;var slope:=atan2(rise,half+.5);var roof_len:=sqrt(pow(half+.5,2)+rise*rise)
	for side: float in [-1.,1.]:
		var panel:=G.box(self,Vector3(side*(half+.5)*.5,3.3+rise*.5,0),Vector3(roof_len,.15,depth+1.2),roof,true)
		panel.rotation.z=-side*slope
	G.box(self,Vector3(0,5.08,0),Vector3(.24,.16,depth+1.4),trim)
	var details: Node3D=preload("res://assets/environment/architecture/coastal_house_details.glb").instantiate()
	details.name="ModeledCoastalArchitecture";details.scale=Vector3(width/8.,1.,depth/7.);add_child(details)
	for part: MeshInstance3D in details.find_children("*","MeshInstance3D",true,false):
		if str(part.name).begins_with("Individual curved"):
			part.material_override=M.surface("lime_plaster",Color("915c3c").lerp(Color("79554a"),float(absi(title.hash())%4)*.15),.8)
	var gable_mat:=wall.duplicate() as StandardMaterial3D;gable_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	for z: float in [-back,back]:
		G.mesh_node(self,G.polygon_mesh(PackedVector3Array([Vector3(-half,3.3,z),Vector3(half,3.3,z),Vector3(0,5.,z)]),PackedInt32Array([0,1,2])),gable_mat,Vector3.ZERO)
		G.beam(self,Vector3(-half-.5,3.3,z+signf(z)*.63),Vector3(0,5.,z+signf(z)*.63),.085,trim)
		G.beam(self,Vector3(0,5.,z+signf(z)*.63),Vector3(half+.5,3.3,z+signf(z)*.63),.085,trim)
	# Open timber veranda: a shaded human-scale threshold and visible beams.
	if use in ["home","cabin","inn","warehouse"]:
		for side: float in [-1.,1.]:
			G.box(self,Vector3(side*(half-.3),1.35,-back-1.15),Vector3(.16,2.7,.16),dark,true)
			G.beam(self,Vector3(side*(half-.3),2.,-back-1.15),Vector3(side*(half-1.),2.65,-back-1.15),.06,trim)
		var porch:=G.box(self,Vector3(0,2.77,-back-.85),Vector3(width+.35,.12,1.9),roof);porch.rotation.x=.13
		G.box(self,Vector3(0,2.6,-back-1.7),Vector3(width+.3,.18,.18),trim)
	# Recessed framed windows and shutters give the facade human scale.
	var glass:=G.material(Color("49737a"),.22);glass.metallic=.3
	windows=glass;windows.emission_enabled=true;windows.emission=Color("ffb968");windows.emission_energy_multiplier=0.
	for x: float in [-half*.62,half*.62]:
		G.box(self,Vector3(x,1.75,-back-.15),Vector3(1.25,1.4,.1),trim)
		G.box(self,Vector3(x,1.75,-back-.21),Vector3(1.03,1.18,.025),glass)
		G.box(self,Vector3(x,1.75,-back-.24),Vector3(.06,1.2,.03),trim)
		G.box(self,Vector3(x,1.75,-back-.24),Vector3(1.05,.06,.03),trim)
		G.box(self,Vector3(x,1.,-back-.35),Vector3(1.4,.15,.48),wood)
	for side: float in [-1.,1.]:
		for z: float in [-back*.52,back*.52]:
			G.box(self,Vector3(side*(half+.12),1.8,z),Vector3(.12,1.45,1.22),trim)
			G.box(self,Vector3(side*(half+.19),1.8,z),Vector3(.04,1.23,1.),glass)
			G.box(self,Vector3(side*(half+.22),1.8,z),Vector3(.04,1.25,.05),trim)
			G.box(self,Vector3(side*(half+.22),1.8,z),Vector3(.04,.06,1.03),trim)
		G.box(self,Vector3(side*half,3.15,0),Vector3(.3,.18,depth+.3),trim)
	G.box(self,Vector3(half-.8,4.5,back-1),Vector3(.65,2.1,.65),stone)
	G.box(self,Vector3(half-.8,5.6,back-1),Vector3(.85,.15,.85),stone)
	G.box(self,Vector3(0,2.95,-back-.2),Vector3(2.5,.48,.12),dark)
	G.label(self,title,Vector3(0,2.96,-back-.28),18)
	# Furniture occupies the sides and back, leaving the doorway and centre clear.
	if use in ["home","cabin","inn"]:
		G.box(self,Vector3(-half+1.15,.4,back-1.2),Vector3(1.7,.65,2.),dark,true)
		var linen:=M.surface("fabric",Color("c4ae7f"),5.)
		var blanket:=M.surface("fabric",Color("4e7379"),5.)
		G.mesh_node(self,preload("res://scripts/visuals/sculpt.gd").rounded_box(Vector3(1.65,.2,1.95),.08),linen,Vector3(-half+1.15,.8,back-1.2))
		G.box(self,Vector3(-half+1.15,.93,back-1.55),Vector3(1.64,.08,1.25),blanket)
		G.sphere(self,Vector3(-half+1.15,.99,back-.55),Vector3(.55,.12,.28),linen)
		for y: float in [.65,.9,1.15]:G.box(self,Vector3(-half+1.15,y,back-.14),Vector3(1.8,.15,.12),wood)
		G.box(self,Vector3(half-1.3,.8,.7),Vector3(1.8,.12,1.3),wood,true)
		for x: float in [half-2.,half-.6]: G.box(self,Vector3(x,.4,.7),Vector3(.13,.8,1.1),dark)
		_chair(Vector3(half-1.3,0,-.5),wood)
		G.cylinder(self,Vector3(half-1.3,.89,.7),.23,.035,trim,.23,20)
		G.cylinder(self,Vector3(half-.85,1.,.9),.085,.2,trim,.085,16)
		G.box(self,Vector3(0,.09,.4),Vector3(1.8,.015,2.6),blanket)
	else:
		G.box(self,Vector3(0,.53,back-1.2),Vector3(width-2.,1.06,1.1),wood,true)
		G.box(self,Vector3(0,1.1,back-1.2),Vector3(width-1.8,.12,1.3),trim)
	for y: float in [.7,1.4,2.1]:
		G.box(self,Vector3(half-.35,y,1.),Vector3(.6,.07,2.6),dark)
		for z: float in [.1,.8,1.5]: G.cylinder(self,Vector3(half-.35,y+.18,z),.11,.3,trim,.09,12)
	G.box(self,Vector3(-half+.45,.5,-.5),Vector3(.7,1.,1.),wood,true)
	# Timber verandas, garden pots and side siding follow each house frontage.
	for x: float in [-half+.35,half-.35]:
		G.cylinder(self,Vector3(x,.28,-back-.65),.32,.55,stone,.38,16)
		var plant:=G.sphere(self,Vector3(x,.68,-back-.65),Vector3(.43,.4,.43),G.material(Color("4c6a3b")),12)
	for y: float in [.45,.85,1.25,1.65,2.05,2.45,2.85]:
		for side: float in [-1.,1.]:G.box(self,Vector3(side*(half+.1),y,0),Vector3(.035,.025,depth),trim)
	if use in ["shop","market","inn"]:
		var awning:=G.box(self,Vector3(0,2.65,-back-.9),Vector3(width+.1,.08,1.6),M.surface("fabric",Color("ab9d77"),3.));awning.rotation.x=.14
		for x: float in [-half+.15,half-.15]:G.cylinder(self,Vector3(x,1.3,-back-1.6),.07,2.6,dark)
	if use in ["home","cabin","inn"]:_decorate_interior(half,back);_furnish_room(half,back,depth)
	var light:=OmniLight3D.new();light.position=Vector3(0,2.7,0);light.light_color=Color("ffd08a");light.omni_range=9.;light.light_energy=1.4;light.set_meta("interior",true);add_child(light);lamps.append(light)
	var lamp_mat:=G.material(Color("ffe1a6"));lamp_mat.emission_enabled=true;lamp_mat.emission=Color("ffcb80")
	G.sphere(self,Vector3(0,2.75,0),Vector3(.15,.23,.15),lamp_mat,12)
	G.beam(self,Vector3(0,2.9,0),Vector3(0,3.2,0),.02,dark)
	for z: float in [-back+1.,back-1.]:G.box(self,Vector3(0,3.08,z),Vector3(width,.22,.22),wood)
	# Occluders match opaque walls; the doorway remains an actual opening.
	for data: Array in [[Vector3(-half,1.6,0),Vector3(.14,3.2,depth)],[Vector3(half,1.6,0),Vector3(.14,3.2,depth)],[Vector3(0,1.6,back),Vector3(width,3.2,.14)],[Vector3(0,3.26,0),Vector3(width,.1,depth)]]:
		var occluder:=OccluderInstance3D.new();var shape:=BoxOccluder3D.new();shape.size=data[1];occluder.occluder=shape;occluder.position=data[0];add_child(occluder)

func _chair(p: Vector3,material: Material) -> void:
	G.box(self,p+Vector3(0,.5,0),Vector3(.62,.1,.62),material,true)
	for x: float in [-.25,.25]:
		for z: float in [-.25,.25]:G.cylinder(self,p+Vector3(x,.25,z),.035,.5,material)
	for x: float in [-.25,.25]:G.cylinder(self,p+Vector3(x,.85,-.27),.03,.7,material)
	for y: float in [.85,1.1]:G.box(self,p+Vector3(0,y,-.27),Vector3(.6,.12,.06),material)

## Fishing-village details inside homes: a net and rods on the walls, a galley counter with a pot, tackle crates by the door,
## framed sea charts and a coiled rope. Everything sits against walls or in corners so the doorway and the centre stay clear.
func _decorate_interior(half: float,back: float) -> void:
	var dark:=M.surface("weathered_wood",Color("544d3c"),1.5)
	var wood:=M.surface("teak",Color("b7a180"),1.2)
	var twine:=G.material(Color("c9b48a"),.95)
	var net_mat:=G.material(Color("5e7f7a"),.9)
	var cloth:=G.material(Color("e5dcc2"),.9)
	var sea:=G.material(Color("2f6f86"),.6)
	var iron:=G.material(Color("3a3f44"),.5)
	var red:=G.material(Color("b3493c"),.8)
	# Fishing net hung on the back wall, above the bed.
	var wall_z:=back-.12
	for i: int in 5:
		var x:=-half+1.1+float(i)*.45
		G.beam(self,Vector3(x,2.9,wall_z),Vector3(x,1.9,wall_z),.012,net_mat)
	for j: int in 4:
		var y:=1.9+float(j)*.33
		G.beam(self,Vector3(-half+.8,y,wall_z),Vector3(-half+3.1,y,wall_z),.012,net_mat)
	G.box(self,Vector3(-half+.8,2.92,wall_z),Vector3(2.4,.04,.04),dark)
	# Two fishing rods leaning in the front-left corner.
	for k: int in 2:
		var base:=Vector3(-half+.25+float(k)*.22,.3,-back+.3)
		G.beam(self,base,base+Vector3(.35,2.4,-.2),.03,dark)
		G.beam(self,base+Vector3(.35,2.4,-.2),base+Vector3(.5,2.6,-.3),.008,twine)
	# Tackle crates by the door, one stacked on the other.
	G.box(self,Vector3(-half+.55,.35,-back+.7),Vector3(.8,.7,.6),wood,true)
	G.box(self,Vector3(-half+.55,1.0,-back+.7),Vector3(.7,.55,.5),wood)
	G.box(self,Vector3(-half+.55,1.0,-back+.7),Vector3(.72,.08,.52),red)
	# Galley counter in the front-right corner with a stove top and a pot.
	var galley_x:=half-.55;var galley_z:=-back+1.05
	G.box(self,Vector3(galley_x,.5,galley_z),Vector3(.7,1.0,1.5),dark,true)
	G.box(self,Vector3(galley_x,1.02,galley_z),Vector3(.75,.06,1.56),wood)
	G.cylinder(self,Vector3(galley_x-.1,1.12,galley_z),.2,.18,iron,.2,14)
	G.cylinder(self,Vector3(galley_x-.1,1.25,galley_z),.14,.12,red,.14,12)
	# Framed sea chart and a coiled rope on the left wall, away from the bed.
	G.box(self,Vector3(-half+.1,1.9,1.2),Vector3(.04,.7,.9),dark)
	G.box(self,Vector3(-half+.13,1.9,1.2),Vector3(.02,.6,.8),sea)
	G.box(self,Vector3(-half+.13,1.9,1.55),Vector3(.02,.1,.2),cloth)
	for r: int in 3:
		G.cylinder(self,Vector3(-half+.5+float(r)*.15,.2,back-.4),.12,.06,twine,.12,12)

## Room finish and the rest of the furniture: a wood wainscot on the side walls, a wardrobe in the back-right corner,
## a bedside table with a lamp, and a framed sea painting above the wardrobe.
func _furnish_room(half: float,back: float,depth: float) -> void:
	var wood:=M.surface("teak",Color("9c7f5c"),1.2)
	var dark:=M.surface("weathered_wood",Color("544d3c"),1.5)
	var panel:=M.surface("teak",Color("c7a977"),1.2)
	var iron:=G.material(Color("3a3f44"),.5)
	var frame:=G.material(Color("d6ccb2"),.8)
	var sea:=G.material(Color("2c6f8c"),.5)
	var warm:=G.material(Color("ffe1a6"));warm.emission_enabled=true;warm.emission=Color("ffcb80");warm.emission_energy_multiplier=1.4
	# Wainscot: vertical boards on the side walls, 0.9 m high, with a cap rail.
	for side: float in [-1.,1.]:
		G.box(self,Vector3(side*(half-.11),.45,0),Vector3(.03,.9,depth-.5),panel)
		G.box(self,Vector3(side*(half-.11),.92,0),Vector3(.05,.05,depth-.5),wood)
		for z_index: int in 6:
			var z:=-back+.5+float(z_index)*(depth-1.)/5.
			G.box(self,Vector3(side*(half-.1),.45,z),Vector3(.05,.9,.03),wood)
	# Wardrobe in the back-right corner: carcass, two doors and a top cornice.
	var wardrobe_z:=back-.75
	G.box(self,Vector3(half-.4,1.05,wardrobe_z),Vector3(.8,2.1,1.1),dark,true)
	G.box(self,Vector3(half-.8,1.05,wardrobe_z-.27),Vector3(.04,1.9,.5),wood)
	G.box(self,Vector3(half-.8,1.05,wardrobe_z+.27),Vector3(.04,1.9,.5),wood)
	G.box(self,Vector3(half-.8,1.05,wardrobe_z),Vector3(.05,.12,.06),iron)
	G.box(self,Vector3(half-.4,2.2,wardrobe_z),Vector3(.9,.12,1.2),wood)
	# Bedside table with a small lamp, next to the bed's foot.
	var table_z:=back-2.6
	G.box(self,Vector3(-half+.45,.35,table_z),Vector3(.5,.6,.5),wood)
	G.cylinder(self,Vector3(-half+.45,.72,table_z),.035,.28,iron,.035,6)
	G.cylinder(self,Vector3(-half+.45,.92,table_z),.14,.2,warm,.1,10)
	# Framed sea painting on the right wall, above the wardrobe level.
	G.box(self,Vector3(half-.1,2.5,back-1.6),Vector3(.04,.7,.9),frame)
	G.box(self,Vector3(half-.12,2.5,back-1.6),Vector3(.02,.6,.8),sea)

