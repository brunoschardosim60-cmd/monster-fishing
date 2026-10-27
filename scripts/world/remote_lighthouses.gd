extends Node3D
## Lighthouses on the distant islands, each with its own light character (period, beam count, colour)
## and paint scheme, standing on the shore that faces the main island so sailors can find their way.
## Built after the first physics frames because their height comes from the island collision.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Lighthouse=preload("res://scripts/world/navigation_lighthouse.gd")
## lobe, style, tower height, period (s), beam angles, tint, phase
## Only two distant islands keep a light, on their highest ground, so at night a few clear marks stand
## out instead of flashes from every side. Each has its own character (period, beams, colour).
const SPECS: Array=[[12,"faixas",30.,20.,[0.],Color("fff0d0"),2.],[11,"preto",28.,26.,[0.,180.],Color("e8f0ff"),9.]]
## Towers are drawn at this scale so they read from kilometres away.
const SCALE: float=2.2
var world: Node3D
var lighthouses: Array[Node3D]=[]
func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for spec: Array in SPECS:
		var lobe: int=spec[0];var l:=Layout.LOBES[lobe]
		var centre:=Vector2(l.x,l.y);var dir:=(Vector2(0,300)-centre).normalized()
		# Highest open ground on the half of the island facing home: seen from far, never in a hollow.
		var p:=centre;var best:=-1000.
		for i: int in 900:
			var q:=centre+Vector2(fposmod(float(i)*.618,1.)*2.-1.,float(i%30)/15.-1.)*Vector2(l.z,l.w)*.8
			if (q-centre).dot(dir)<-l.z*.1 or Layout.coast(q).x>-20.:continue
			var h:=Layout.height(q)
			var slope:=absf(Layout.height(q+Vector2(3,0))-h)+absf(Layout.height(q+Vector2(0,3))-h)
			if slope>3.5:continue
			if h>best:best=h;p=q
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,420.,p.y),Vector3(p.x,-40.,p.y));query.collision_mask=1
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():continue
		var tower:=Lighthouse.new();tower.world=world;tower.name="Farol_%s"%str(Layout.REGIONS[lobe].get("id",lobe))
		tower.style=spec[1];tower.tower_height=spec[2];tower.period=spec[3];tower.beam_angles=spec[4];tower.tint=spec[5];tower.phase=spec[6]
		tower.position=(hit.position as Vector3)-Vector3(0,.3,0);tower.rotation.y=atan2(-dir.x,-dir.y);tower.scale=Vector3.ONE*SCALE
		add_child(tower);lighthouses.append(tower)
