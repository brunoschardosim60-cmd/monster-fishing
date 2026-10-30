extends RefCounted
## Cabins you can go down into (hull_classes "cabin"): an enclosed room inside the hull, panelled in
## varnished wood, lit by a hanging lantern and portholes, with the furniture a working boat carries.
##   veleiro — the saloon under the coachroof: a table between two settees, a galley with stove and sink,
##             a V-berth forward and a chart table by the companionway;
##   escuna  — the lower deck: a long mess table with benches, bunks in tiers along both sides forward,
##             the captain's desk and sea chest aft, a stove, barrels and hammocks.
## The room is built in hull space; the player walks it in 2D like the deck (cabin.rect minus blocks).
const G=preload("res://scripts/world/geometry.gd")
const M=preload("res://scripts/visuals/materials.gd")

## Builds the room under `parent` (the hull model) and returns it. Hidden until someone goes below.
static func build(parent: Node3D,spec: Dictionary,kind: String) -> Node3D:
	var root:=Node3D.new();root.name="Cabine";parent.add_child(root)
	var r: Rect2=spec.rect;var y0: float=spec.floor;var y1: float=spec.ceiling
	var teak:=M.surface("teak",Color("8a5a35"),1.2)
	var panel:=M.surface("teak",Color("c9a77c"),1.4)
	var white:=G.material(Color("efe9dc"),.8)
	var dark:=G.material(Color("3d2a1c"),.7)
	var cloth:=G.material(Color("2f5d7a"),.9)
	var brass:=G.material(Color("b08a43"),.35);brass.metallic=.7
	var cx: float=r.get_center().x;var cz: float=r.get_center().y
	var h: float=y1-y0
	var foot: Vector3=spec.foot;var hatch: Vector3=spec.hatch
	var hatch_inside: bool=r.has_point(Vector2(hatch.x,hatch.z))
	const HOLE: float=.36
	# Floor, ceiling with deck beams (open over the companionway when it comes down inside the room),
	# and the four panelled walls (thin boxes, seen from inside).
	G.box(root,Vector3(cx,y0-.03,cz),Vector3(r.size.x+.1,.06,r.size.y+.1),teak)
	if hatch_inside:
		var hz0: float=hatch.z-HOLE;var hz1: float=hatch.z+HOLE
		G.box(root,Vector3(cx,y1+.03,(r.position.y+hz0)*.5),Vector3(r.size.x+.1,.06,hz0-r.position.y+.05),white)
		G.box(root,Vector3(cx,y1+.03,(hz1+r.end.y)*.5),Vector3(r.size.x+.1,.06,r.end.y-hz1+.05),white)
		G.box(root,Vector3((r.position.x+hatch.x-HOLE)*.5,y1+.03,hatch.z),Vector3(hatch.x-HOLE-r.position.x,.06,HOLE*2.),white)
		G.box(root,Vector3((hatch.x+HOLE+r.end.x)*.5,y1+.03,hatch.z),Vector3(r.end.x-hatch.x-HOLE,.06,HOLE*2.),white)
		# The trunk of the hatch, from the beams up to the deck.
		for side: float in [-1.,1.]:
			G.box(root,Vector3(hatch.x+side*HOLE,(y1+hatch.y+.15)*.5,hatch.z),Vector3(.04,hatch.y+.15-y1,HOLE*2.),panel)
			G.box(root,Vector3(hatch.x,(y1+hatch.y+.15)*.5,hatch.z+side*HOLE),Vector3(HOLE*2.,hatch.y+.15-y1,.04),panel)
	else:
		G.box(root,Vector3(cx,y1+.03,cz),Vector3(r.size.x+.1,.06,r.size.y+.1),white)
	var beams: int=int(r.size.y/.7)
	for i: int in beams+1:
		var bz: float=r.position.y+float(i)*r.size.y/float(maxi(beams,1))
		if hatch_inside and absf(bz-hatch.z)<HOLE+.08:continue
		G.box(root,Vector3(cx,y1-.05,bz),Vector3(r.size.x,.1,.12),dark)
	var aft_door: bool=not hatch_inside and hatch.z>r.end.y
	for side: float in [-1.,1.]:
		G.box(root,Vector3(cx+side*(r.size.x*.5+.03),y0+h*.5,cz),Vector3(.06,h+.06,r.size.y+.12),panel)
		var wz: float=cz+side*(r.size.y*.5+.03)
		if side>0. and aft_door:
			# A doorway in the aft bulkhead to the companionway, which runs on under the deck to the hatch.
			var gx0: float=hatch.x-HOLE;var gx1: float=hatch.x+HOLE
			G.box(root,Vector3((r.position.x+gx0)*.5,y0+h*.5,wz),Vector3(gx0-r.position.x+.06,h+.06,.06),panel)
			G.box(root,Vector3((gx1+r.end.x)*.5,y0+h*.5,wz),Vector3(r.end.x-gx1+.06,h+.06,.06),panel)
			var run: float=hatch.z+HOLE-r.end.y
			for s2: float in [-1.,1.]:G.box(root,Vector3(hatch.x+s2*HOLE,(y0+hatch.y)*.5,r.end.y+run*.5),Vector3(.04,hatch.y-y0,run),panel)
			G.box(root,Vector3(hatch.x,(y0+hatch.y)*.5,hatch.z+HOLE),Vector3(HOLE*2.,hatch.y-y0,.04),panel)
			G.box(root,Vector3(hatch.x,y0-.03,r.end.y+run*.5),Vector3(HOLE*2.,.06,run),teak)
		else:
			G.box(root,Vector3(cx,y0+h*.5,wz),Vector3(r.size.x+.12,h+.06,.06),panel)
		# A rubbing strake and a row of portholes letting in the day.
		G.box(root,Vector3(cx+side*(r.size.x*.5-.01),y0+h*.45,cz),Vector3(.03,.08,r.size.y),dark)
		var glass:=G.material(Color("bfe3ee"));glass.emission_enabled=true;glass.emission=Color("9fd3e6");glass.emission_energy_multiplier=1.1
		for k: int in maxi(1,int(r.size.y/1.4)):
			var z: float=r.position.y+(float(k)+.5)*r.size.y/float(maxi(1,int(r.size.y/1.4)))
			var port:=G.cylinder(root,Vector3(cx+side*(r.size.x*.5-.02),y0+h*.72,z),.13,.04,glass,-1.,16);port.rotation.z=PI*.5
			var ring:=G.cylinder(root,Vector3(cx+side*(r.size.x*.5-.03),y0+h*.72,z),.17,.03,brass,-1.,16);ring.rotation.z=PI*.5
	# Companionway ladder from the hatch down to the floor.
	var steps: int=int(ceil((hatch.y-y0)/.25))
	for i: int in steps:
		var t: float=float(i+1)/float(steps+1)
		G.box(root,Vector3(foot.x,y0+t*(hatch.y-y0),lerpf(foot.z,hatch.z,t)),Vector3(.6,.04,.22),teak)
	for side: float in [-.32,.32]:G.beam(root,Vector3(foot.x+side,y0,foot.z),Vector3(foot.x+side,hatch.y,hatch.z),.03,teak)
	# Hanging lantern and its warm light.
	var lamp_at:=Vector3(cx,y1-.35,cz)
	var glow:=G.material(Color("ffd9a0"));glow.emission_enabled=true;glow.emission=Color("ffb766");glow.emission_energy_multiplier=1.6
	G.cylinder(root,lamp_at+Vector3(0,.22,0),.01,.25,brass)
	G.cylinder(root,lamp_at,.09,.2,glow,-1.,10)
	G.cylinder(root,lamp_at+Vector3(0,.12,0),.11,.04,brass,.05,10)
	var light:=OmniLight3D.new();light.position=lamp_at;light.light_color=Color("ffcf94");light.light_energy=1.4;light.omni_range=maxf(r.size.length()*.75,4.);light.shadow_enabled=false;root.add_child(light)
	var blocks: Array[Rect2]=[]
	match kind:
		"veleiro":_saloon(root,r,y0,y1,teak,cloth,white,brass,dark,blocks)
		"chalupa","galeao_sot","bergantim_sot":_captain_cabin(root,r,y0,y1,blocks)
		"porao":_hold(root,r,y0,y1,blocks,spec.foot)
		"escuna":_lower_deck(root,r,y0,y1,teak,cloth,white,brass,dark,blocks)
	# Furniture from the joinery set brings its own colliders for houses; aboard, the cabin's blocks do
	# that job, and a static body inside the boat would snag its own hull.
	for body: Node in root.find_children("*","StaticBody3D",true,false):body.queue_free()
	root.set_meta("blocks",blocks)
	root.visible=false
	return root

## The sloop's captain's cabin under the helm deck (Sea of Thieves style): entered by the door forward;
## the captain's table with the chart and chairs in the middle, the bunk along the starboard side,
## a sea chest and shelves to port, lanterns, under the stern windows a bench. The doorway stays clear.
## The hold (hull_classes "hold"): cargo stowed along both sides and lashed — crates, barrels on chocks,
## sacks, coils of rope, fish boxes on ice, nets hung from the beams and a couple of hammocks — leaving
## a gangway down the middle from the ladder.
static func _hold(root: Node3D,r: Rect2,y0: float,y1: float,blocks: Array[Rect2],foot: Vector3) -> void:
	var F=preload("res://scripts/visuals/furniture.gd")
	var rng:=RandomNumberGenerator.new();rng.seed=int(r.size.x*100.+r.size.y)
	var wood:=M.surface("weathered_wood",Color("8a6238"),1.2);var iron:=G.material(Color("2a2622"),.5)
	var sack:=G.material(Color("b9a27a"),.95);var ice:=G.material(Color("d8eef2"),.2);var net:=G.material(Color("6a7a5a"),.9)
	var lane: float=.75
	var z: float=r.position.y+.5
	while z<r.end.y-.5:
		for side: float in [-1.,1.]:
			var x: float=r.get_center().x+side*(r.size.x*.5-.55)
			if absf(z-foot.z)<1. and absf(x-foot.x)<1.:continue
			match rng.randi()%4:
				0:F.crate(root,Vector3(x,y0,z),rng.randf_range(-.2,.2),Vector3(.8,.6,.7),false)
				1:
					var b:=G.cylinder(root,Vector3(x,y0+.42,z),.34,.84,wood,.3,12)
					for hy: float in [.15,.69]:G.cylinder(root,Vector3(x,y0+hy,z),.36,.05,iron,-1.,12)
				2:
					for k: int in 3:G.sphere(root,Vector3(x+rng.randf_range(-.15,.15),y0+.2+float(k)*.22,z+rng.randf_range(-.2,.2)),Vector3(.32,.2,.26),sack,8)
				_:
					G.box(root,Vector3(x,y0+.2,z),Vector3(.9,.4,.6),wood)
					G.box(root,Vector3(x,y0+.38,z),Vector3(.8,.06,.5),ice)
			blocks.append(Rect2(x-.5,z-.45,1.,.9))
		z+=1.1
	# Nets drooping from the beams and two hammocks slung fore and aft.
	for k: int in 3:
		var nz: float=lerpf(r.position.y+.8,r.end.y-.8,float(k)/2.)
		var drape:=G.sphere(root,Vector3(r.get_center().x+(1. if k%2==0 else -1.)*(r.size.x*.5-.4),y1-.45,nz),Vector3(.25,.5,.9),net,8)
	for hz: float in [r.position.y+.6]:
		var hm:=G.box(root,Vector3(r.get_center().x,y1-.75,hz),Vector3(r.size.x-.6,.06,.7),G.material(Color("d8cfb8"),.95))
		for side: float in [-1.,1.]:G.beam(root,Vector3(r.get_center().x+side*(r.size.x*.5-.3),y1-.75,hz),Vector3(r.get_center().x+side*(r.size.x*.5-.05),y1-.1,hz),.015,net)
	F.oil_lamp(root,Vector3(r.get_center().x,y1-.4,lerpf(r.position.y,r.end.y,.3)))

static func _captain_cabin(root: Node3D,r: Rect2,y0: float,y1: float,blocks: Array[Rect2]) -> void:
	var F=preload("res://scripts/visuals/furniture.gd")
	var x0: float=r.position.x;var x1: float=r.end.x;var z0: float=r.position.y;var z1: float=r.end.y
	var cz: float=(z0+z1)*.5+.4
	F.table(root,Vector3(0,y0,cz),0.,Vector3(1.6,.78,1.0),false)
	_chart(root,Vector3(0,y0+.785,cz),Vector2(.9,.65))
	root.set_meta("chart",Vector3(0,y0,cz-1.))
	for k: int in 2:F.chair(root,Vector3(-.5+float(k),y0,cz-.85),PI)
	F.chair(root,Vector3(0,y0,cz+.85),0.)
	F.oil_lamp(root,Vector3(.5,y0+.79,cz+.25))
	blocks.append(Rect2(-.9,cz-.6,1.8,1.2))
	F.bed(root,Vector3(x1-.55,y0,z1-1.3),0.,Vector2(.95,2.0))
	blocks.append(Rect2(x1-1.05,z1-2.35,1.05,2.1))
	F.drawers(root,Vector3(x0+.3,y0,z1-.8),PI*.5,Vector3(.9,.8,.5),3)
	blocks.append(Rect2(x0,z1-1.3,.6,1.))
	# Sea chest with iron bands.
	var wood: Material=F.mat("weathered_wood",Color("6b4a2c"));var iron: Material=F.mat("flat",Color("2a2622"),.5,.5)
	G.box(root,Vector3(x0+.4,y0+.25,cz-.4),Vector3(.55,.5,.9),wood)
	for k: int in 3:G.box(root,Vector3(x0+.4,y0+.25,cz-.75+float(k)*.35),Vector3(.58,.52,.05),iron)
	blocks.append(Rect2(x0,cz-.9,.7,1.))
	F.shelf(root,Vector3(x0+.12,y0+1.5,cz),PI*.5,1.2)
	F.picture(root,Vector3(x1-.08,y0+1.55,z1-1.3),-PI*.5,Vector2(.8,.6))
	# Bench under the stern windows.
	G.box(root,Vector3(0,y0+.25,z1-.3),Vector3(r.size.x-1.3,.5,.45),wood)
	blocks.append(Rect2(x0+.6,z1-.55,r.size.x-1.2,.55))
	F.rug(root,Vector3(0,y0,cz),0.,Vector2(2.,1.4))

static func _saloon(root: Node3D,r: Rect2,y0: float,y1: float,teak: Material,cloth: Material,white: Material,brass: Material,dark: Material,blocks: Array[Rect2]) -> void:
	var x0: float=r.position.x;var x1: float=r.end.x;var z0: float=r.position.y;var z1: float=r.end.y
	# V-berth forward: a raised mattress across the bow end.
	G.box(root,Vector3((x0+x1)*.5,y0+.25,z0+.55),Vector3(r.size.x-.1,.5,1.05),teak)
	G.box(root,Vector3((x0+x1)*.5,y0+.56,z0+.55),Vector3(r.size.x-.2,.12,.95),cloth)
	for k: int in 2:G.box(root,Vector3(x0+.4+float(k)*(r.size.x-.8),y0+.68,z0+.3),Vector3(.45,.12,.3),white)
	blocks.append(Rect2(x0,z0,r.size.x,1.1))
	# Table between two settees in the middle.
	var mid_z: float=z0+1.75
	G.box(root,Vector3((x0+x1)*.5,y0+.72,mid_z),Vector3(.6,.05,1.),teak)
	G.cylinder(root,Vector3((x0+x1)*.5,y0+.36,mid_z),.05,.72,brass)
	for side: float in [-1.,1.]:
		var sx: float=(x0+x1)*.5+side*(r.size.x*.5-.25)
		G.box(root,Vector3(sx,y0+.22,mid_z),Vector3(.45,.44,1.3),teak)
		G.box(root,Vector3(sx,y0+.48,mid_z),Vector3(.43,.1,1.25),cloth)
		G.box(root,Vector3(sx+side*.19,y0+.75,mid_z),Vector3(.08,.45,1.25),cloth)
	blocks.append(Rect2((x0+x1)*.5-.35,mid_z-.55,.7,1.1))
	# Galley to port by the companionway: counter, two-burner stove with a kettle, a sink; chart table to
	# starboard with a chart and dividers.
	var gz: float=z1-.45
	G.box(root,Vector3(x0+.3,y0+.45,gz),Vector3(.55,.9,.8),teak)
	G.box(root,Vector3(x0+.3,y0+.91,gz),Vector3(.57,.04,.82),white)
	for k: int in 2:G.cylinder(root,Vector3(x0+.3,y0+.94,gz-.18+float(k)*.36),.09,.02,dark,-1.,12)
	G.cylinder(root,Vector3(x0+.3,y0+1.02,gz-.18),.07,.14,brass,.05,12)
	blocks.append(Rect2(x0,gz-.42,.6,.84))
	G.box(root,Vector3(x1-.3,y0+.4,gz),Vector3(.55,.8,.8),teak)
	G.box(root,Vector3(x1-.3,y0+.81,gz),Vector3(.57,.04,.82),teak)
	_chart(root,Vector3(x1-.3,y0+.836,gz),Vector2(.42,.55))
	root.set_meta("chart",Vector3(x1-.68,y0,gz-.15))
	blocks.append(Rect2(x1-.6,gz-.42,.6,.84))

static func _lower_deck(root: Node3D,r: Rect2,y0: float,y1: float,teak: Material,cloth: Material,white: Material,brass: Material,dark: Material,blocks: Array[Rect2]) -> void:
	var x0: float=r.position.x;var x1: float=r.end.x;var z0: float=r.position.y;var z1: float=r.end.y
	# Bunks in two tiers along both sides, forward.
	for side: float in [-1.,1.]:
		var bx: float=(x0+x1)*.5+side*(r.size.x*.5-.4)
		for k: int in 2:
			var bz: float=z0+.3+1.05+float(k)*2.15
			for tier: int in 2:
				var by: float=y0+.35+float(tier)*.85
				G.box(root,Vector3(bx,by,bz),Vector3(.75,.08,2.),teak)
				G.box(root,Vector3(bx,by+.09,bz),Vector3(.68,.1,1.9),cloth)
				G.box(root,Vector3(bx-side*.36,by+.12,bz),Vector3(.04,.18,2.),teak)
			G.box(root,Vector3(bx,y0+.85,bz-1.02),Vector3(.75,1.7,.05),teak)
		blocks.append(Rect2(bx-.4,z0+.3,.8,4.3))
	# The long mess table with benches down the middle.
	var tz: float=z0+5.6
	G.box(root,Vector3((x0+x1)*.5,y0+.75,tz),Vector3(.9,.06,3.),teak)
	for k: int in 3:G.box(root,Vector3((x0+x1)*.5,y0+.37,tz-1.2+float(k)*1.2),Vector3(.1,.74,.1),dark)
	for side: float in [-1.,1.]:
		G.box(root,Vector3((x0+x1)*.5+side*.75,y0+.42,tz),Vector3(.3,.06,2.8),teak)
		for k: int in 2:G.box(root,Vector3((x0+x1)*.5+side*.75,y0+.2,tz-1.1+float(k)*2.2),Vector3(.26,.4,.08),dark)
	# Bowls, mugs and a lantern on the table.
	for k: int in 6:G.cylinder(root,Vector3((x0+x1)*.5+(-.25 if k%2==0 else .25),y0+.81,tz-1.1+float(k/2)*1.1),.07,.06,white,.09,10)
	blocks.append(Rect2((x0+x1)*.5-.95,tz-1.55,1.9,3.1))
	# Hammocks slung between the beams aft of the table.
	var hz: float=tz+2.2
	for k: int in 2:
		var hx: float=(x0+x1)*.5+(float(k)-.5)*1.1
		var sag:=G.box(root,Vector3(hx,y1-.75,hz),Vector3(.7,.06,1.6),G.material(Color("d9cdb2"),.95));sag.rotation.x=.05
		for e: float in [-1.,1.]:G.beam(root,Vector3(hx,y1-.7,hz+e*.8),Vector3(hx,y1-.08,hz+e*1.1),.012,dark)
	# Captain's corner aft: desk with a chart and a lamp, a sea chest, barrels and the stove.
	var az: float=z1-.6
	G.box(root,Vector3(x1-.55,y0+.4,az),Vector3(.9,.8,.6),teak)
	G.box(root,Vector3(x1-.55,y0+.81,az),Vector3(.95,.04,.65),dark)
	_chart(root,Vector3(x1-.55,y0+.832,az),Vector2(.6,.4))
	root.set_meta("chart",Vector3(x1-.55,y0,az-.75))
	blocks.append(Rect2(x1-1.,az-.35,1.,.7))
	G.box(root,Vector3(x0+.45,y0+.3,az),Vector3(.8,.6,.5),dark)
	for k: int in 3:G.box(root,Vector3(x0+.45,y0+.3,az-.25+float(k)*.25),Vector3(.82,.05,.03),brass)
	blocks.append(Rect2(x0,az-.3,.9,.6))
	for k: int in 3:
		G.cylinder(root,Vector3(x0+.35,y0+.45,z1-1.6-float(k)*.65),.28,.9,M.surface("weathered_wood",Color("8a6a4a"),1.),.26,12)
	blocks.append(Rect2(x0,z1-3.2,.7,1.9))
	var stove_at:=Vector3(x1-.4,y0,z1-2.)
	G.box(root,stove_at+Vector3(0,.35,0),Vector3(.6,.7,.6),G.material(Color("2a2a2a"),.5))
	G.cylinder(root,stove_at+Vector3(0,(y1-y0)*.5+.35,0),.07,(y1-y0)-.7,G.material(Color("2a2a2a"),.5))
	var fire:=G.material(Color("ff8a3a"));fire.emission_enabled=true;fire.emission=Color("ff7a20");fire.emission_energy_multiplier=2.
	G.box(root,stove_at+Vector3(-.31,.3,0),Vector3(.02,.18,.3),fire)
	blocks.append(Rect2(x1-.75,z1-2.35,.75,.7))

## A sea chart lying on the table: the archipelago painted on parchment (islands from the layout, a
## compass rose, rhumb lines), with brass dividers on it.
static var _chart_tex: ImageTexture
static func _chart(root: Node3D,at: Vector3,size: Vector2) -> void:
	if _chart_tex==null:
		var Layout=load("res://scripts/world/archipelago_layout.gd")
		var w:=256;var h:=256;var img:=Image.create(w,h,false,Image.FORMAT_RGB8)
		var span:=11000.
		for y: int in h:
			for x: int in w:
				var n:=sin(float(x)*.31+float(y)*.17)*.02+sin(float(x*y)*.001)*.015
				img.set_pixel(x,y,Color(.86+n,.8+n,.64+n))
		for l: Vector4 in Layout.LOBES:
			var cx:=(l.x/span+.5)*float(w);var cy:=(l.y/span+.5)*float(h)
			var rx:=maxf(1.5,l.z/span*float(w)*1.2);var ry:=maxf(1.5,l.w/span*float(h)*1.2)
			for y: int in range(int(cy-ry-3),int(cy+ry+4)):
				for x: int in range(int(cx-rx-3),int(cx+rx+4)):
					if x<0 or y<0 or x>=w or y>=h:continue
					var d:=Vector2((float(x)-cx)/rx,(float(y)-cy)/ry).length()
					if d<1.:img.set_pixel(x,y,Color(.55,.62,.38) if d<.8 else Color(.78,.7,.5))
					elif d<1.35:img.set_pixel(x,y,img.get_pixel(x,y).lerp(Color(.55,.72,.78),.5))
		for k: int in 16:
			var a:=float(k)*TAU/16.
			for r: int in 120:
				var x:=int(128+cos(a)*float(r));var y:=int(128+sin(a)*float(r))
				if x>=0 and y>=0 and x<w and y<h and r%3!=0:img.set_pixel(x,y,img.get_pixel(x,y).darkened(.12))
		for r: int in 14:
			for k: int in 4:
				var a:=float(k)*PI*.5
				img.set_pixel(int(220+cos(a)*float(r)),int(36+sin(a)*float(r)),Color(.55,.12,.1))
		_chart_tex=ImageTexture.create_from_image(img)
	var mat:=StandardMaterial3D.new();mat.albedo_texture=_chart_tex;mat.roughness=.9
	var plane:=PlaneMesh.new();plane.size=size
	G.mesh_node(root,plane,mat,at)
	var brass:=G.material(Color("b8913f"),.3);brass.metallic=.8
	G.beam(root,at+Vector3(-size.x*.2,.01,size.y*.1),at+Vector3(size.x*.05,.01,-size.y*.2),.006,brass)
	G.beam(root,at+Vector3(-size.x*.2,.01,size.y*.1),at+Vector3(size.x*.15,.01,-size.y*.05),.006,brass)
