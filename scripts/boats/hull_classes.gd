extends RefCounted
## Player hull classes: geometry the physics, deck walking, helm and anchor need for each boat the player
## can own. "tripo" is the imported fishing launch (Aurora, Veloz, Expedição, Traineira share it at
## different scales); the others are built by vessel_models.gd and have their own proportions.
##   length/beam: waterline size (collision, wave sampling)   mass: kg (heave and roll response)
##   deck: walkable box in hull space (y = deck height, x = half width, z0..z1 bow..stern) plus blocks,
##         rectangles (x, z, width, depth) the player walks around: cabins, masts, hatches.
##   helm: where the skipper stands; wheel: [position, radius, tilt, turns lock-to-lock (negative = tiller)]
##   roofs: walkable cabin tops reached by a ladder: {"rect": Rect2 (x,z,w,d), "y": roof height,
##          "ladder": deck point at the ladder's foot, "top": roof point where it arrives}
##   crew: optional decorative sailors (unused now: the player's crew is hired, see crew_manager.gd)
##   holders: rod holders on the rail (position, yaw of the rod leaning outboard); more on bigger boats
##   immersion: how deep the hull sits at rest (m): sets its heave period (√(immersion/g)) and stiffness
##   gunwale: height of the rail edge in hull space (water above it comes aboard)
##   sails: drive per m/s of wind at full sail and best point of sail (0 = motor only)
const SPECS: Dictionary={
	"tripo":{"immersion":.6,"gunwale":1.42,"length":8.1,"beam":3.65,"mass":4200.,"draft":.1,"heave":155000.,"angular":3.8,"tilt":.32,
		"deck":{"y":1.12,"x":1.4,"z0":-3.3,"z1":3.1,"start":Vector3(0,1.12,2.4),"blocks":[Rect2(-1.13,-1.65,2.26,2.55)]},
		"helm":Vector3(0,1.12,1.25),"wheel":[Vector3(0,1.96,.85),.24,PI*.3,1.5],"bucket":Vector3(1.,1.12,2.55),"sails":0.,
		"holders":[{"at":Vector3(1.38,1.42,2.95),"yaw":-2.2},{"at":Vector3(-1.38,1.42,2.95),"yaw":2.2}],"winch":Vector3(1.05,1.12,-2.6)},
	"canoa":{"immersion":.2,"gunwale":.3,"kind":"canoa","model_length":6.2,"length":6.,"beam":.95,"mass":420.,"draft":-.12,"heave":9000.,"angular":7.,"tilt":.3,
		"deck":{"y":.1,"x":.24,"z0":-2.,"z1":2.2,"start":Vector3(0,.1,.6),"blocks":[]},
		"helm":Vector3(0,.1,2.25),"wheel":[Vector3(0,.42,2.95),0.,0.,-.15],"bucket":Vector3(0,.08,-1.1),"sails":0.,
		"holders":[{"at":Vector3(.36,.42,1.4),"yaw":-2.2}]},
	"veleiro":{"immersion":.8,"gunwale":1.38,"kind":"veleiro","model_length":11.,"length":10.4,"beam":3.5,"mass":6500.,"draft":.0,"heave":210000.,"angular":3.,"tilt":.38,
		"deck":{"y":1.1,"x":1.35,"z0":-4.5,"z1":4.6,"start":Vector3(.9,1.1,2.4),"blocks":[Rect2(-.99,-1.87,1.98,3.3)],
			"roofs":[{"rect":Rect2(-.85,-1.75,1.7,3.05),"y":1.7,"ladder":Vector3(.5,1.1,1.75),"top":Vector3(.5,1.7,1.15)}]},
		"helm":Vector3(0,1.1,4.35),"wheel":[Vector3(0,1.95,3.75),.38,PI*.3,1.5],"bucket":Vector3(-.9,1.1,2.6),"sails":.55,
		"holders":[{"at":Vector3(1.4,1.45,4.4),"yaw":-2.2},{"at":Vector3(-1.4,1.45,4.4),"yaw":2.2}]},
	"escuna":{"immersion":1.4,"gunwale":2.5,"kind":"escuna","model_length":20.,"length":19.,"beam":5.,"mass":32000.,"draft":.05,"heave":1100000.,"angular":1.9,"tilt":.24,
		"deck":{"y":2.2,"x":2.05,"z0":-8.6,"z1":8.6,"start":Vector3(1.5,2.2,-1.),"blocks":[Rect2(-1.45,3.35,2.9,3.3),Rect2(-.3,-4.3,.6,.6),Rect2(-.3,1.3,.6,.6)],
			"roofs":[{"rect":Rect2(-1.3,3.5,2.6,3.),"y":3.3,"ladder":Vector3(.8,2.2,3.05),"top":Vector3(.8,3.3,3.75)}]},
		"helm":Vector3(0,2.2,7.9),"wheel":[Vector3(0,3.15,7.25),.5,PI*.32,2.],"bucket":Vector3(-1.4,2.2,1.),"sails":.72,
		"holders":[{"at":Vector3(2.1,2.65,7.6),"yaw":-2.2},{"at":Vector3(-2.1,2.65,7.6),"yaw":2.2},{"at":Vector3(2.2,2.65,-1.5),"yaw":-1.6},{"at":Vector3(-2.2,2.65,-1.5),"yaw":1.6}],"winch":Vector3(1.3,2.2,-6.3)},
}

static func spec(model: String) -> Dictionary:
	return SPECS.get(model,SPECS.tripo)

## Pushes a deck point out of the blocks it entered, along the shallowest side.
static func resolve_blocks(p: Vector3,blocks: Array,margin: float=0.) -> Vector3:
	for b: Rect2 in blocks:
		var r:=b.grow(margin)
		if p.x>r.position.x and p.x<r.end.x and p.z>r.position.y and p.z<r.end.y:
			var exits: Array=[[p.x-r.position.x,Vector3(r.position.x,p.y,p.z)],[r.end.x-p.x,Vector3(r.end.x,p.y,p.z)],
				[p.z-r.position.y,Vector3(p.x,p.y,r.position.y)],[r.end.y-p.z,Vector3(p.x,p.y,r.end.y)]]
			exits.sort_custom(func(a: Array,c: Array) -> bool:return float(a[0])<float(c[0]))
			p=exits[0][1]
	return p
