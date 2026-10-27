extends Node3D
## An accessible room, with a real doorway, ramp, furnishings and simple collision.
@export var title: String="Casa"
@export var width: float=7.
@export var depth: float=6.
@export var tint: Color=Color("71928b")
@export var use: String="home"
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")
const Props=preload("res://scripts/world/cc0_props.gd")
var entry: Marker3D
var service: Marker3D
var lamps: Array[OmniLight3D]=[]
var windows: StandardMaterial3D
## Fishing shops only: the furnished sales floor and the shopkeeper behind the counter.
var interior: Node3D
var keeper: Node3D

func _ready() -> void:
	var stone:=M.surface("granite",Color("afb2a6"),1.)
	var wall:=M.surface("lime_plaster",Color.WHITE.lerp(tint,.18),.35)
	var trim:=M.surface("weathered_wood",Color("d6ccb2"),2.)
	var wood:=M.surface("teak",Color("b7a180"),1.2)
	var dark:=M.surface("weathered_wood",Color("544d3c"),1.5)
	var half:=width*.5;var back:=depth*.5
	var ground_low:=position.y
	for x: float in [-half,half]:
		for z: float in [-back,back]:
			var corner:=Basis(Vector3.UP,rotation.y)*Vector3(x,0,z)
			ground_low=minf(ground_low,preload("res://scripts/world/archipelago_layout.gd").ground(Vector2(position.x+corner.x,position.z+corner.z)))
	var foundation:=maxf(.3,position.y-ground_low+.25)
	G.box(self,Vector3(0,-foundation*.5,0),Vector3(width+.5,foundation,depth+.5),stone,true)
	G.box(self,Vector3(0,.04,0),Vector3(width,.08,depth),wood,true)
	# Walls are separate segments. The central 1.8 m opening has no collision.
	for x: float in [-half,half]: G.box(self,Vector3(x,1.65,0),Vector3(.18,3.3,depth),wall,true)
	G.box(self,Vector3(0,1.65,back),Vector3(width,3.3,.18),wall,true)
	for side: float in [-1.,1.]: G.box(self,Vector3(side*(half+.9)*.5,1.65,-back),Vector3(half-.9,3.3,.18),wall,true)
	G.box(self,Vector3(0,2.94,-back),Vector3(1.8,.72,.18),wall,true)
	var front:=Basis(Vector3.UP,rotation.y)*Vector3(0,0,-back-4.)
	var approach: float=preload("res://scripts/world/archipelago_layout.gd").ground(Vector2(position.x+front.x,position.z+front.z))
	var rise_to_door:=position.y+.08-approach
	var ramp:=G.box(self,Vector3(0,.03-rise_to_door*.5,-back-2.),Vector3(2.,.1,sqrt(16.+rise_to_door*rise_to_door)),wood,true);ramp.rotation.x=-atan2(rise_to_door,4.);ramp.name="Rampa"
	entry=Marker3D.new();entry.name="Entry";entry.position=Vector3(0,.1,-back-1.);add_child(entry)
	service=Marker3D.new();service.name="Service";service.position=Vector3(0,.1,.55 if use=="shop" else -.5);add_child(service)
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
	G.box(self,Vector3(0,2.95,-back-.2),Vector3(maxf(2.5,float(title.length())*.13+.5),.48,.12),dark)
	G.label(self,title,Vector3(0,2.96,-back-.28),18)
	if use=="shop":
		# Fishing shops hang a painted wooden fish over the door so they read from the street.
		G.beam(self,Vector3(half-.2,2.35,-back-.1),Vector3(half-.2,2.35,-back-1.5),.04,dark)
		var fish_sign:=Node3D.new();fish_sign.position=Vector3(half-.2,1.92,-back-1.1);add_child(fish_sign)
		for k: float in [-.25,.25]:G.beam(fish_sign,Vector3(0,.43,k),Vector3(0,.18,k),.012,dark)
		G.ellipsoid(fish_sign,Vector3.ZERO,Vector3(.1,.42,1.05),M.surface("teak",Color("3f7f9e"),1.),14)
		var tail:=G.box(fish_sign,Vector3(0,0,.62),Vector3(.08,.38,.28),M.surface("teak",Color("3f7f9e"),1.));tail.rotation.x=PI*.25
		G.ellipsoid(fish_sign,Vector3(0,.07,-.32),Vector3(.12,.08,.08),G.material(Color("f2efe4")),8)
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
	elif use=="shop":_furnish_shop(half,back,depth)
	else:
		G.box(self,Vector3(0,.53,back-1.2),Vector3(width-2.,1.06,1.1),wood,true)
		G.box(self,Vector3(0,1.1,back-1.2),Vector3(width-1.8,.12,1.3),trim)
	if use!="shop":
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


## Fishing shop sales floor: a counter with a lure case, scale and till; a pegboard of lures and reels
## behind it, a rack of rods on the left wall, an ice chest of the day's fish and a live-bait tank by
## the door, tackle shelves, a net with floats under the ceiling, and a shopkeeper behind the counter.
## The doorway, the aisle to the counter and the service spot stay clear.
func _furnish_shop(half: float,back: float,depth: float) -> void:
	interior=Node3D.new();interior.name="InteriorLoja";add_child(interior)
	var wood:=M.surface("teak",Color("a88762"),1.2)
	var dark:=M.surface("weathered_wood",Color("4f4434"),1.5)
	var board:=M.surface("weathered_wood",Color("8a6d4c"),1.)
	var iron:=G.material(Color("3a3f44"),.45);iron.metallic=.5
	var brass:=G.material(Color("b58d3f"),.35);brass.metallic=.7
	var glass:=G.material(Color(.75,.9,.95,.22),.05);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var water:=G.material(Color(.25,.58,.62,.55),.05);water.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var ice:=G.material(Color("dcecf0"),.25)
	var net_mat:=G.material(Color("6f8d7c"),.9)
	var cork:=G.material(Color("c79a5e"),.9)
	var colors: Array[Color]=[Color("d8432f"),Color("f1c232"),Color("3d85c6"),Color("6aa84f"),Color("e69138"),Color("f3f3f3"),Color("a64d79")]
	var paints: Array[StandardMaterial3D]=[]
	for c: Color in colors:paints.append(G.material(c,.4))
	# Counter across the back third, solid so the shopkeeper stays behind it.
	var counter_z:=back-1.55;var counter_w:=width-3.4
	G.box(interior,Vector3(0,.5,counter_z),Vector3(counter_w,1.,.75),dark,true)
	G.box(interior,Vector3(0,1.03,counter_z),Vector3(counter_w+.2,.06,.9),wood)
	for x: float in range(-int(counter_w*.5)+0,int(counter_w*.5)+1):G.box(interior,Vector3(float(x),.5,counter_z-.39),Vector3(.05,.9,.03),wood)
	# Lure case on the counter: glass box with lures lying in rows.
	var case_x:=-counter_w*.5+.9
	G.box(interior,Vector3(case_x,1.08,counter_z),Vector3(1.4,.04,.62),dark)
	G.box(interior,Vector3(case_x,1.26,counter_z),Vector3(1.4,.34,.62),glass)
	for i: int in 12:
		var lure:=G.ellipsoid(interior,Vector3(case_x-.55+float(i%6)*.22,1.13,counter_z-.15+float(i/6)*.3),Vector3(.13,.045,.05),paints[i%paints.size()],8)
		lure.rotation.y=float(i)*.4
	# Till and scale.
	G.box(interior,Vector3(counter_w*.5-.6,1.19,counter_z+.1),Vector3(.5,.26,.4),iron)
	G.box(interior,Vector3(counter_w*.5-.6,1.35,counter_z+.2),Vector3(.44,.12,.12),brass)
	G.box(interior,Vector3(.4,1.12,counter_z),Vector3(.26,.12,.22),brass)
	G.cylinder(interior,Vector3(.4,1.25,counter_z),.03,.14,brass,.03,8)
	G.cylinder(interior,Vector3(.4,1.33,counter_z),.17,.03,brass,.15,16)
	# Pegboard behind the counter: hanging lures, reels and spools of line.
	G.box(interior,Vector3(0,2.15,back-.13),Vector3(width-1.8,1.5,.04),board)
	for row: int in 3:
		for col: int in 9:
			var x:=-(width-2.6)*.5+float(col)*(width-2.6)/8.;var y:=2.7-float(row)*.48
			G.beam(interior,Vector3(x,y,back-.15),Vector3(x,y,back-.3),.012,iron)
			match (row+col)%3:
				0:G.ellipsoid(interior,Vector3(x,y-.12,back-.28),Vector3(.06,.16,.04),paints[(row*9+col)%paints.size()],8)
				1:
					var reel:=G.cylinder(interior,Vector3(x,y-.12,back-.26),.08,.07,iron,.08,12);reel.rotation.x=PI*.5
				_:G.cylinder(interior,Vector3(x,y-.1,back-.26),.05,.12,paints[(col+2)%paints.size()],.05,10)
	var sign_board:=G.box(interior,Vector3(0,2.78,counter_z),Vector3(2.6,.42,.05),dark)
	G.beam(interior,Vector3(-1.1,3.05,counter_z),Vector3(-1.1,2.99,counter_z),.015,iron)
	G.beam(interior,Vector3(1.1,3.05,counter_z),Vector3(1.1,2.99,counter_z),.015,iron)
	G.label(interior,"ISCAS · VARAS · REDES",Vector3(0,2.78,counter_z-.04),20)
	# Rod rack on the left wall: eight rods standing in a two-rail rack.
	for y: float in [.3,1.55]:G.box(interior,Vector3(-half+.22,y,.9),Vector3(.12,.08,3.),dark)
	for i: int in 8:
		var z:=-.45+float(i)*.39
		var base:=Vector3(-half+.3,.1,z);var tip:=Vector3(-half+.18,2.85,z+.05)
		G.beam(interior,base,base.lerp(tip,.25),.03,cork)
		G.beam(interior,base.lerp(tip,.25),tip,.014,paints[i%paints.size()] if i%2==0 else iron)
		var reel:=G.cylinder(interior,base.lerp(tip,.2)+Vector3(.09,0,0),.07,.06,iron,.07,10);reel.rotation.z=PI*.5
	# Ice chest with the day's fish, by the door on the left.
	var chest:=Vector3(-half+.85,0,-back+1.15)
	G.box(interior,chest+Vector3(0,.3,0),Vector3(1.1,.6,.85),wood,true)
	G.box(interior,chest+Vector3(0,.62,0),Vector3(1.,.05,.75),ice)
	# The day's catch on crushed ice: silver mackerel, a red snapper and a striped bass.
	var catch_colors: Array[Color]=[Color("8fa9b5"),Color("c1382f"),Color("8fa9b5"),Color("6e7a52"),Color("d9c46c")]
	for i: int in 5:
		var fish_mat:=G.material(catch_colors[i],.3);fish_mat.metallic=.35
		var fish:=Node3D.new();fish.name="PeixeNoGelo%d"%i;fish.position=chest+Vector3(-.36+float(i)*.18,.69,-.05+float(i%2)*.12);fish.rotation.y=float(i%3-1)*.15;interior.add_child(fish)
		G.ellipsoid(fish,Vector3.ZERO,Vector3(.12,.07,.46),fish_mat,10)
		var tail:=G.box(fish,Vector3(0,0,.27),Vector3(.02,.1,.09),fish_mat);tail.rotation.x=PI*.25
		G.ellipsoid(fish,Vector3(.045,.015,-.17),Vector3(.025,.025,.025),G.material(Color("141414"),.2),6)
	G.label(interior,"PEIXE DO DIA",chest+Vector3(0,1.05,0),14).billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	# Live-bait tank on a stand, by the door on the right, with sardines and a worm bucket.
	var tank:=Vector3(half-.55,0,-back+1.35)
	G.box(interior,tank+Vector3(0,.38,0),Vector3(.7,.76,1.4),dark,true)
	G.box(interior,tank+Vector3(0,1.06,0),Vector3(.64,.58,1.32),glass)
	G.box(interior,tank+Vector3(0,1.,0),Vector3(.6,.44,1.28),water)
	var silver:=G.material(Color("c9d3d6"),.3);silver.metallic=.6
	for i: int in 7:
		var bait:=G.ellipsoid(interior,tank+Vector3(-.15+float(i%3)*.15,.9+float(i%2)*.14,-.45+float(i)*.15),Vector3(.03,.035,.13),silver,6)
		bait.rotation.y=float(i)*.9
	for i: int in 2:
		var bucket:=tank+Vector3(-.7,0,-.3+float(i)*.6)
		G.cylinder(interior,bucket+Vector3(0,.2,0),.2,.4,paints[2-i],.22,12)
		G.cylinder(interior,bucket+Vector3(0,.39,0),.19,.02,G.material(Color("4a3426")),.19,12)
	G.label(interior,"ISCA VIVA",tank+Vector3(0,1.55,0),14).billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	# Tackle shelves on the right wall, clear of the windows.
	for y: float in [.55,1.15,1.75]:
		G.box(interior,Vector3(half-.3,y,0),Vector3(.5,.05,2.2),dark)
		for k: int in 4:G.box(interior,Vector3(half-.32,y+.12,-.8+float(k)*.53),Vector3(.38,.2,.4),paints[(k+int(y*3.))%paints.size()])
	G.box(interior,Vector3(half-.3,.9,-1.1),Vector3(.5,1.8,.05),dark);G.box(interior,Vector3(half-.3,.9,1.1),Vector3(.5,1.8,.05),dark)
	# Net with cork floats sagging under the ceiling, over the front-left of the room.
	for i: int in 7:
		var x:=-half+.6+float(i)*.45
		var a:=Vector3(x,3.05,-back+.5);var mid:=Vector3(x,2.55,-back+1.6);var b:=Vector3(x,3.05,-back+2.7)
		G.beam(interior,a,mid,.008,net_mat);G.beam(interior,mid,b,.008,net_mat)
	for j: int in 5:
		var t:=float(j)/4.;var z:=-back+.5+t*2.2;var y:=3.05-sin(t*PI)*.5
		G.beam(interior,Vector3(-half+.6,y,z),Vector3(-half+3.3,y,z),.008,net_mat)
		if j%2==0:
			for k: int in 3:G.ellipsoid(interior,Vector3(-half+.9+float(k)*1.1,y-.05,z),Vector3(.1,.1,.1),paints[4],8)
	# Life ring and crossed oars beside the door.
	var ring:=TorusMesh.new();ring.inner_radius=.22;ring.outer_radius=.34;ring.rings=24;ring.ring_segments=8
	var buoy:=G.mesh_node(interior,ring,paints[0],Vector3(1.6,2.25,-back+.16));buoy.rotation.x=PI*.5
	for s: float in [-1.,1.]:
		var oar_a:=Vector3(-1.6-s*.45,1.3,-back+.16);var oar_b:=Vector3(-1.6+s*.45,2.9,-back+.16)
		G.beam(interior,oar_a,oar_b,.03,wood)
		G.box(interior,oar_a+Vector3(0,.15,0),Vector3(.16,.38,.03),wood)
	# Rope barrel and a runner rug from the door to the counter.
	Props.spawn(interior,"Barrel",Vector3(half-.7,0,back-.7),1.,.5)
	for r: int in 3:G.cylinder(interior,Vector3(half-.7,1.05+float(r)*.07,back-.7),.2,.06,cork,.2,12)
	G.box(interior,Vector3(0,.09,-1.),Vector3(1.4,.012,3.6),G.material(Color("7b3b2e"),.95))
	# Warm light over the counter and two lanterns hanging by the shelves.
	var warm:=G.material(Color("ffe1a6"));warm.emission_enabled=true;warm.emission=Color("ffc477");warm.emission_energy_multiplier=1.6
	for x: float in [-2.2,2.2]:
		G.beam(interior,Vector3(x,3.08,.3),Vector3(x,2.6,.3),.012,iron)
		G.cylinder(interior,Vector3(x,2.45,.3),.1,.28,warm,.08,10)
	var counter_light:=OmniLight3D.new();counter_light.position=Vector3(0,2.6,counter_z-.4);counter_light.light_color=Color("ffcf8a");counter_light.omni_range=6.;counter_light.light_energy=1.1
	counter_light.set_meta("interior",true);add_child(counter_light);lamps.append(counter_light)
	# The shopkeeper paces behind the counter.
	keeper=preload("res://scripts/world/village_resident.gd").new();keeper.name="Lojista";keeper.look_id=46+absi(title.hash())%5;keeper.speed=.45;keeper.follow_terrain=false;keeper.hide_backpack=true;keeper.idle_pose="ual/Counter";keeper.rest_yaw=0.
	keeper.route.assign([Vector3(-counter_w*.5+.6,.08,back-.72),Vector3(counter_w*.5-.6,.08,back-.72)])
	add_child(keeper)
