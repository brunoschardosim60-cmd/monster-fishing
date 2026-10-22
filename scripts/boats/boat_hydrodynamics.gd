extends Resource
## Tunable vessel response; the sampler uses the physical beam and waterline.
@export var mass_kg: float=1200.
@export var waterline_length: float=4.6
@export var beam: float=2.05
@export var draft_offset: float=.10
@export var heave_stiffness: float=64000.
@export var damping_ratio: float=.85
@export var angular_response: float=5.5
@export var maximum_tilt: float=.38
@export var storm_drag: float=.18
