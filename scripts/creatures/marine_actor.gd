extends Node3D
## Species-driven presentation/AI hook, usable with GLB or the functional fish fallback.
signal observed(species: Resource)
signal capture_requested(species: Resource)
@export var species: Resource
@export_enum("rest","swim") var behavior: String="swim"
@export var roaming_radius: float=8.
var visual: Node3D
var origin:=Vector3.ZERO
var elapsed: float=0.
var discovered: bool=false
func _ready() -> void:
	origin=position
	if species==null:return
	if species.visual_scene!=null:visual=species.visual_scene.instantiate()
	else:
		visual=preload("res://scripts/fishing/catch_display.gd").new();add_child(visual);visual.show_catch({"species_id":species.id,"color":species.color.to_html()});visual.set_process(false);return
	add_child(visual)
func _process(delta: float) -> void:
	elapsed+=delta
	if visual==null:return
	if behavior=="swim":
		var phase: float=elapsed*float(species.swim_speed)/maxf(roaming_radius,1.)
		position=origin+Vector3(cos(phase)*roaming_radius,sin(phase*2.)*.4,sin(phase)*roaming_radius)
		rotation.y=-phase
	else:visual.scale.y=1.+sin(elapsed*.8)*.004
func observe() -> void:
	if discovered:return
	discovered=true;observed.emit(species)
func request_capture() -> bool:
	if species==null or not species.capture_allowed:return false
	capture_requested.emit(species);return true
