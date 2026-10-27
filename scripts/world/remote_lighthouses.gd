extends Node3D
## Lighthouses on the distant islands, each with its own light character (period, beam count, colour)
## and paint scheme, standing on the shore that faces the main island so sailors can find their way.
## Built after the first physics frames because their height comes from the island collision.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Lighthouse=preload("res://scripts/world/navigation_lighthouse.gd")
## lobe, style, tower height, period (s), beam angles, tint, phase
## Only the landmark islands keep a light: fewer towers, each one a navigation mark you can name.
const SPECS: Array=[[11,"preto",30.,12.,[0.,30.,60.],Color("f6f3e6"),2.],[15,"pedra",34.,18.,[0.,24.],Color("e8f0ff"),0.],
	[13,"faixas",26.,15.,[0.],Color("fff0d0"),7.],[25,"amarelo",30.,16.5,[0.,120.,240.],Color("ffdcaa"),1.5]]
## Towers are drawn at this scale so they read from kilometres away.
const SCALE: float=1.6
var world: Node3D
var lighthouses: Array[Node3D]=[]
func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for spec: Array in SPECS:
		var lobe: int=spec[0];var l:=Layout.LOBES[lobe]
		var centre:=Vector2(l.x,l.y);var dir:=(Vector2(0,300)-centre).normalized()
		var p:=centre
		for i: int in 800:
			if Layout.coast(p+dir*2.).x>-14.:break
			p+=dir*2.
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,420.,p.y),Vector3(p.x,-40.,p.y));query.collision_mask=1
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():continue
		var tower:=Lighthouse.new();tower.world=world;tower.name="Farol_%s"%str(Layout.REGIONS[lobe].get("id",lobe))
		tower.style=spec[1];tower.tower_height=spec[2];tower.period=spec[3];tower.beam_angles=spec[4];tower.tint=spec[5];tower.phase=spec[6]
		tower.position=(hit.position as Vector3)-Vector3(0,.3,0);tower.rotation.y=atan2(-dir.x,-dir.y);tower.scale=Vector3.ONE*SCALE
		add_child(tower);lighthouses.append(tower)
