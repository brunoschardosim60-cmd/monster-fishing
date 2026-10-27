extends Node3D
## Brief hooked-fish breach. Presentation only; never changes catch probability.
const Waves=preload("res://scripts/world/wave_field.gd")
var model: Node3D
var effects: Node3D
var age: float=2.
var origin:=Vector3.ZERO

func _ready() -> void:
	model=preload("res://scripts/fishing/catch_display.gd").new()
	add_child(model); model.set_process(false); hide()

func breach(at: Vector3, species: Resource, size: float=.55) -> void:
	if species==null: return
	origin=at; age=0.
	model.show_catch({"species_id":species.id,"color":species.color.to_html()})
	model.scale=Vector3.ONE*size
	show()
	if effects!=null: effects.splash(at,.7,true)

func _process(delta: float) -> void:
	if not visible: return
	age+=delta
	var t:=clampf(age/.85,0.,1.)
	global_position=origin+Vector3(t*.6-.3,0,0)
	global_position.y=Waves.height_at(global_position)+sin(t*PI)*.85-.08
	model.rotation.z=lerpf(.85,-.85,t)
	if t>=1.:
		hide()
		if effects!=null: effects.splash(global_position,.9,true)
