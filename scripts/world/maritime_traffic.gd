extends Node3D
const ROUTE: Array[Vector3]=[Vector3(20,0,-140),Vector3(320,0,-140),Vector3(440,0,200),Vector3(450,0,800),Vector3(70,0,1170),Vector3(-530,0,1030),Vector3(-530,0,540),Vector3(-340,0,-140)]
var vessels: Array[CharacterBody3D]=[]
func _ready() -> void:
	for i: int in 3:
		var ship:=preload("res://scripts/boats/traffic_vessel.gd").new()
		ship.name=["PesqueiroItinerante","RebocadorCosteiro","NavioDeApoio"][i];ship.route.assign(ROUTE);ship.waypoint=[1,4,6][i]
		ship.length_m=[12.,21.,30.][i];ship.cruise_speed=[4.4,3.8,5.2][i]
		if i>0:ship.asset_path="res://assets/boats/tugboat.glb"
		add_child(ship);vessels.append(ship)
func set_player_boat(boat: Node3D) -> void:
	for ship: CharacterBody3D in vessels:ship.player_boat=boat
