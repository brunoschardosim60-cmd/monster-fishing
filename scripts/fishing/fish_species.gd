class_name MonsterFishSpecies
extends Resource
## Declarative species data. Add another .tres and register it in the fishing pool.

@export var id: String = ""
@export var display_name: String = ""
@export var rarity: String = "Comum"
@export var min_weight: float = 0.2
@export var max_weight: float = 1.0
@export var value_per_kg: float = 20.0
@export_range(0.0, 1.0) var difficulty: float = 0.2
@export_multiline var description: String = ""
@export var color: Color = Color(0.5, 0.8, 0.8)
@export var habitat: String = "Costa de Farol"
@export var regions: PackedStringArray = PackedStringArray(["coast"])
@export_range(0.01, 10.0) var encounter_weight: float = 1.0
@export var visual_scene: PackedScene
@export var swim_speed: float=1.5
@export var capture_allowed: bool=true
@export var preferred_depth: Vector2=Vector2(0,30)
