extends Node3D
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
const G=preload("res://scripts/world/geometry.gd")
var district: Node3D
var visual: Node3D
var fishing: Node
var line: Node3D
var catch_model: Node3D
var caught_count: int=0
var pending: Dictionary={}
var stored: bool=false
var elapsed: float=0.
func _ready() -> void:
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	fishing=Fishing.new();add_child(fishing);fishing.rng.seed=9182+int(absf(position.x)*17.);fishing.caught.connect(_caught)
	line=preload("res://scripts/fishing/fishing_visual.gd").new();line.top_level=true;add_child(line)
	var metal:=G.material(Color("9ea89f"),.3)
	var bucket:=CylinderMesh.new();bucket.top_radius=.25;bucket.bottom_radius=.19;bucket.height=.4;bucket.cap_top=false;metal.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh_node(self,bucket,metal,Vector3(.65,.2,.15))
	catch_model=preload("res://scripts/creatures/marine_visual.gd").new();catch_model.species="mackerel";catch_model.scale=Vector3.ONE*.42;catch_model.swimming=false;add_child(catch_model);catch_model.hide()
func _process(delta: float) -> void:
	elapsed+=delta
	if fishing.state==Fishing.State.IDLE and elapsed>2.+fposmod(absf(position.x),5.):
		line.target=global_position-global_basis.z*9.;line.target.y=0.
		line.cast_start=visual.rod_tip();line.cast_elapsed=0.;pending.clear();stored=false
		fishing.start_cast("coast")
	if fishing.state==Fishing.State.BITE and fishing.state_time>.35:fishing.strike()
	if fishing.state==Fishing.State.REELING:
		# A real tension controller: residents can lose a fish, just like the player.
		fishing.set_reeling(fishing.tension<.68 if fishing._reeling else fishing.tension<.3)
	visual.fishing_state=fishing.state;visual.holding_fish=not pending.is_empty() and not stored
	visual.update_animation(0.,fishing.active(),delta)
	line.update_line(visual.rod_tip(),fishing.state,delta)
	if not pending.is_empty() and not stored:
		var t:=clampf((fishing.state_time-.75)/1.1,0.,1.)
		catch_model.global_position=visual.catch_hand_transform().origin.lerp(to_global(Vector3(.65,.23,.15)),t*t)
		catch_model.visible=true
		if t>=1.:
			district.receive_catch(pending);caught_count+=1;stored=true;catch_model.hide()
func _caught(data: Dictionary) -> void:
	pending=data.duplicate(true)
