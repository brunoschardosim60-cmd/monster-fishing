extends RefCounted
## Shared visual water surface. Gameplay collision remains level and predictable.
static var time: float = 0.0
static func height_at(p: Vector3) -> float:
	var v:=Vector2(p.x,p.z)
	var factor:=lerpf(.25,1.,smoothstep(13.,65.,v.distance_to(Vector2(0,-15))))
	var bend:=sin(v.dot(Vector2(.037,.029)))*1.7
	var h:=sin(v.dot(Vector2(1,.45).normalized())*TAU/13.-time*1.55+bend)*.42
	h+=sin(v.dot(Vector2(-.35,1).normalized())*TAU/7.1-time*1.9+bend)*.22
	h+=sin(v.dot(Vector2(.8,-.65).normalized())*TAU/3.5-time*2.4+bend)*.095
	h+=sin(v.dot(Vector2(-1.,-.2).normalized())*TAU/5.3-time*1.7+bend)*.09
	h+=sin(v.dot(Vector2(.15,1.).normalized())*TAU/2.4-time*2.7+bend)*.045
	var lod:=1.-smoothstep(185.,240.,maxf(absf(p.x),absf(p.z)))
	return h*factor*lod
