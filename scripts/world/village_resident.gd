extends Node3D
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var route: Array[Vector3]=[]
var target_index: int=0
var speed: float=1.15
var follow_terrain: bool=true
var visual: Node3D
var wait: float=0.
var velocity:=Vector3.ZERO
var visits: int=0
var ground_sampler: Callable
func _ready() -> void:
	visual=preload("res://scripts/player/imported_angler.gd").new();add_child(visual)
	if not route.is_empty(): position=route[0]
func _process(delta: float) -> void:
	if route.size()<2: return
	var camera:=get_viewport().get_camera_3d()
	visual.visible=camera!=null and camera.global_position.distance_squared_to(global_position)<3600.
	wait=maxf(0.,wait-delta)
	var target:=route[target_index];var diff:=target-position;diff.y=0.
	var desired:=Vector3.ZERO
	if wait<=0. and diff.length()>.15:
		desired=diff.normalized()*minf(speed,sqrt(2.*1.6*diff.length()))
	elif wait<=0.:
		target_index=(target_index+1)%route.size();visits+=1
		# Pause only at a destination, instead of freezing at every bend.
		wait=1.2+fposmod(speed*3.7,1.5) if visits%route.size()==0 else 0.
	velocity=velocity.move_toward(desired,delta*1.6)
	position+=velocity*delta
	position.y=Layout.height(Vector2(position.x,position.z))+.08 if follow_terrain else target.y
	if ground_sampler.is_valid():position.y=ground_sampler.call(position)
	if velocity.length()>.08:rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),1.-exp(-delta*3.2))
	if visual.visible:visual.update_animation(velocity.length(),false,delta)
	visual._rod.visible=false
