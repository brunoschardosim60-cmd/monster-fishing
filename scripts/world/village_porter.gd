extends "res://scripts/world/village_resident.gd"
## A resident who carries a bundle on one leg of a route and walks back empty: fish crates from the pier
## to the market, logs from the woods to the boatyard, planks to a building site.
## `cargo` is a child node on the shoulder; it shows while the porter heads for a waypoint in `loaded_legs`.
const G=preload("res://scripts/world/geometry.gd")
var cargo: Node3D
var loaded_legs: Array[int]=[]
var deliveries: int=0
var _was_loaded: bool=false

func _init() -> void:
	hide_backpack=true

func _process(delta: float) -> void:
	super(delta)
	if cargo==null:return
	var loaded:=target_index in loaded_legs
	if _was_loaded and not loaded:deliveries+=1
	_was_loaded=loaded
	cargo.visible=loaded
	# Crates are carried in both arms in front (UAL carry walk, a slower pace); logs and planks ride on the shoulder.
	var in_arms:=cargo.name=="Caixa"
	visual.walk_clip="ual/WalkCarry" if loaded and in_arms else "ual/Walk"
	if in_arms:cargo.position=Vector3(0,1.1,-.36) if loaded else Vector3(.2,1.66,.02)
	var cap:=speed*(.62 if in_arms else .85)
	if loaded and velocity.length()>cap:velocity=velocity.normalized()*move_toward(velocity.length(),cap,delta*2.)

## Shoulder loads, built from simple shapes so they batch-free follow the porter.
static func fish_crate() -> Node3D:
	var crate:=Node3D.new();crate.name="Caixa"
	var wood:=G.material(Color("a07a4f"),.85);var ice:=G.material(Color("dbeef2"),.3)
	var scales:=G.material(Color("8fa7b0"),.35);scales.metallic=.4
	G.box(crate,Vector3.ZERO,Vector3(.56,.28,.4),wood)
	G.box(crate,Vector3(0,.13,0),Vector3(.5,.04,.34),ice)
	for i: int in 3:
		var fish:=G.ellipsoid(crate,Vector3(-.15+float(i)*.15,.17,0),Vector3(.09,.06,.32),scales,8);fish.rotation.y=float(i)*.3-.3
	crate.position=Vector3(.2,1.66,.02)
	return crate

static func log_load() -> Node3D:
	var bundle:=Node3D.new();bundle.name="Tora"
	var bark:=G.material(Color("6b4e33"),.95);var cut:=G.material(Color("c9a46a"),.8)
	var trunk:=G.cylinder(bundle,Vector3.ZERO,.14,2.6,bark,.12,10);trunk.rotation.x=PI*.5
	for z: float in [-1.3,1.3]:
		var face:=G.cylinder(bundle,Vector3(0,0,z),.13,.02,cut,.13,10);face.rotation.x=PI*.5
	bundle.position=Vector3(.22,1.6,0)
	return bundle

static func plank_load() -> Node3D:
	var bundle:=Node3D.new();bundle.name="Tabuas"
	var plank:=G.material(Color("c9a46a"),.8)
	for i: int in 3:G.box(bundle,Vector3(0,float(i)*.05,0),Vector3(.2,.04,3.),plank)
	bundle.position=Vector3(.24,1.58,0)
	return bundle
