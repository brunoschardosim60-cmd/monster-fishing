extends RefCounted
## Wind responds first; the swell retains its energy after a front passes.
enum State { CALM, BREEZE, ROUGH, STORM, AFTERMATH }
const LABELS := ["MAR CALMO", "BRISA", "MAR AGITADO", "TEMPESTADE", "ONDULAÇÃO RESIDUAL"]
const PRESETS := [Vector4(.09,0.,.18,.0004), Vector4(.32,0.,.32,.00065), Vector4(.68,.35,.72,.002), Vector4(1.,1.,1.,.006), Vector4(.22,.08,.42,.0012)]
const DURATIONS := [100.,150.,100.,85.,130.]
var state: int = State.BREEZE
var automatic: bool = true
var age: float = 0.
var clock: float = 0.
var wind: float = .32
var rain: float = 0.
var cloud: float = .32
var fog: float = .00065
var energy: float = .40
var heading: float = .45
## 0..1: how deep the camera is inside a local storm cell (storms.gd). It overrides the regional weather.
var local_storm: float = 0.
var local_fog: float = 0.
var _base:=Vector4(.32,0.,.32,.00065)

func choose(index: int) -> void:
	automatic=index<0
	if index>=0: state=clampi(index,0,4)
	age=0.

func advance(delta: float) -> void:
	clock+=delta; age+=delta
	if automatic and age>DURATIONS[state]:
		# Storms are local cells now (storms.gd); the background cycle only goes as far as rough seas.
		state=(state+1)%5; age=0.
		if state==State.STORM: state=State.AFTERMATH
	var target: Vector4=PRESETS[state]
	var blend:=1.-exp(-delta/18.)
	var gust:=1.+sin(clock*.19)*.07+sin(clock*.071)*.06
	_base.x=lerpf(_base.x,target.x*gust,blend)
	_base.y=lerpf(_base.y,target.y,blend)
	_base.z=lerpf(_base.z,target.z,blend*.75)
	_base.w=lerpf(_base.w,target.w,blend)
	var s:=clampf(local_storm,0.,1.)
	wind=lerpf(_base.x,1.*gust,s*.95)
	rain=lerpf(_base.y,1.,smoothstep(.15,.7,s))
	cloud=lerpf(_base.z,1.,smoothstep(0.,.5,s))
	fog=lerpf(_base.w,.0045,smoothstep(.3,1.,s))
	fog=maxf(fog,local_fog)
	var desired:=wind*.95
	energy=lerpf(energy,desired,1.-exp(-delta/(30. if desired>energy else 115.)))
	heading=lerp_angle(heading,.45+sin(clock*.009)*.38,1.-exp(-delta/40.))

func settle(index: int) -> void:
	## Deterministic scenario setup only. The player always uses choose().
	choose(index)
	var p: Vector4=PRESETS[state]
	wind=p.x; rain=p.y; cloud=p.z; fog=p.w; _base=p
	energy=.8 if index==State.AFTERMATH else p.x*.95
