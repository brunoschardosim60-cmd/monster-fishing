extends Node3D
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var route: Array[Vector3]=[]
var target_index: int=0
var speed: float=1.15
var visual: Node3D
var wait: float=0.
func _ready() -> void:
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	if not route.is_empty(): position=route[0]
func _process(delta: float) -> void:
	if route.size()<2: return
	var camera:=get_viewport().get_camera_3d()
	visual.visible=camera!=null and camera.global_position.distance_squared_to(global_position)<3600.
	wait=maxf(0.,wait-delta)
	var target:=route[target_index];var diff:=target-position;diff.y=0.
	var moving:=wait<=0. and diff.length()>.25
	if moving:
		position+=diff.normalized()*minf(speed*delta,diff.length());position.y=Layout.height(Vector2(position.x,position.z))+.08
		rotation.y=lerp_angle(rotation.y,atan2(-diff.x,-diff.z),delta*4.)
	elif wait<=0.: target_index=(target_index+1)%route.size();wait=2.5
	if visual.visible:visual.update_animation(speed if moving else 0.,false,delta)
	visual._rod.visible=false
