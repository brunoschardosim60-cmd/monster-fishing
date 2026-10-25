extends Node3D
const ROUTE: Array[Vector3]=[Vector3(20,0,-140),Vector3(320,0,-140),Vector3(440,0,200),Vector3(450,0,800),Vector3(70,0,1170),Vector3(-530,0,1030),Vector3(-530,0,540),Vector3(-340,0,-140)]
var vessels: Array[CharacterBody3D]=[]
func _ready() -> void:
	# Fishing boats, a tug, a support ship and a large cargo liner share the same lanes.
	var names:=["PesqueiroItinerante","RebocadorCosteiro","NavioDeApoio","BoteDePesca","CargueiroGrande","Canoa","Petroleiro"]
	var kinds:=["pesqueiro","rebocador","apoio","bote","cargueiro","canoa","petroleiro"];var turns:=[.5,.6,.4,.9,.12,1.2,.1]
	var waypoints:=[1,4,6,2,7,3,5];var lengths:=[12.,21.,30.,7.,62.,4.5,150.];var speeds:=[4.4,3.8,5.2,5.6,3.2,2.4,2.6]
	for i: int in names.size():
		var ship:=preload("res://scripts/boats/traffic_vessel.gd").new()
		ship.name=names[i];ship.route.assign(ROUTE);ship.waypoint=waypoints[i]
		ship.length_m=lengths[i];ship.cruise_speed=speeds[i]
		ship.kind=kinds[i];ship.turn_rate=turns[i]
		add_child(ship);vessels.append(ship)
func set_player_boat(boat: Node3D) -> void:
	for ship: CharacterBody3D in vessels:ship.player_boat=boat
