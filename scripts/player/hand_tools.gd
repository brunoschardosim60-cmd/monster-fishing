extends RefCounted
## Simple hand tools for working NPCs, modelled along +Y from the grip (the hand bone's finger axis).
const G=preload("res://scripts/world/geometry.gd")
## Orientation of a tool in the working hand (found by rendering the UAL chop and hammer cycles).
const GRIP: Transform3D=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO)

static func axe() -> Node3D:
	var root:=Node3D.new();root.name="Machado"
	var wood:=G.material(Color("8a6239"),.8);var steel:=G.material(Color("9aa3a8"),.35);steel.metallic=.7
	G.cylinder(root,Vector3(0,.25,0),.022,.85,wood,.02,8)
	G.box(root,Vector3(.07,.62,0),Vector3(.16,.12,.025),steel)
	G.box(root,Vector3(.15,.62,0),Vector3(.03,.17,.02),steel)
	return root

static func hammer() -> Node3D:
	var root:=Node3D.new();root.name="Martelo"
	var wood:=G.material(Color("9b7146"),.8);var steel:=G.material(Color("4d5357"),.4);steel.metallic=.6
	G.cylinder(root,Vector3(0,.12,0),.016,.36,wood,.014,8)
	G.box(root,Vector3(0,.3,0),Vector3(.16,.05,.05),steel)
	return root
