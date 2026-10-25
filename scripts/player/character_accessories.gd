extends RefCounted
## Procedural headwear for NPCs, authored in the same model space as fisher_cap.glb so the existing
## head-bone attachment in imported_angler.gd carries it. Heads are ~0.14 m in radius around y 1.70.
const G=preload("res://scripts/world/geometry.gd")

static func headwear(kind: String, tint: Color) -> Node3D:
	var root:=Node3D.new()
	var cloth:=G.material(tint,.95)
	match kind:
		"beanie":
			G.sphere(root,Vector3(0,1.715,.0),Vector3(.152,.135,.158),cloth,20)
			G.cylinder(root,Vector3(0,1.655,.0),.158,.045,G.material(tint.darkened(.2),.95),.158,20)
			G.sphere(root,Vector3(0,1.845,.0),Vector3(.032,.032,.032),cloth,10)
		"straw":
			var straw:=G.material(Color("d9bd77"),.9)
			G.cylinder(root,Vector3(0,1.755,.0),.30,.018,straw,.30,28)
			G.cylinder(root,Vector3(0,1.76,.0),.135,.115,straw,.118,24)
			G.cylinder(root,Vector3(0,1.775,.0),.139,.03,cloth,.139,24)
		"bandana":
			G.cylinder(root,Vector3(0,1.72,.0),.152,.07,cloth,.152,20)
	return root
