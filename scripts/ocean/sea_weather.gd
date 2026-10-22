extends RefCounted
## Wind responds first; the swell retains its energy after a front passes.
enum State { CALM, BREEZE, ROUGH, STORM, AFTERMATH }
const LABELS := ["MAR CALMO", "BRISA", "MAR AGITADO", "TEMPESTADE", "ONDULAÇÃO RESIDUAL"]
const PRESETS := [Vector4(.09,0.,.18,.0018), Vector4(.32,0.,.32,.0023), Vector4(.68,.35,.72,.004), Vector4(1.,1.,1.,.009), Vector4(.22,.08,.42,.003)]
const DURATIONS := [100.,150.,100.,85.,130.]
var state: int = State.BREEZE
var automatic: bool = true
var age: float = 0.
var clock: float = 0.
var wind: float = .32
var rain: float = 0.
var cloud: float = .32
var fog: float = .0023
var energy: float = .40
var heading: float = .45

func choose(index: int) -> void:
	automatic=index<0
	if index>=0: state=clampi(index,0,4)
	age=0.

func advance(delta: float) -> void:
	clock+=delta; age+=delta
	if automatic and age>DURATIONS[state]:
		state=(state+1)%5; age=0.
	var target: Vector4=PRESETS[state]
	var blend:=1.-exp(-delta/18.)
	var gust:=1.+sin(clock*.19)*.07+sin(clock*.071)*.06
	wind=lerpf(wind,target.x*gust,blend)
	rain=lerpf(rain,target.y,blend)
	cloud=lerpf(cloud,target.z,blend*.75)
	fog=lerpf(fog,target.w,blend)
	var desired:=wind*.95
	energy=lerpf(energy,desired,1.-exp(-delta/(30. if desired>energy else 115.)))
	heading=lerp_angle(heading,.45+sin(clock*.009)*.38,1.-exp(-delta/40.))

func settle(index: int) -> void:
	## Deterministic scenario setup only. The player always uses choose().
	choose(index)
	var p: Vector4=PRESETS[state]
	wind=p.x; rain=p.y; cloud=p.z; fog=p.w
	energy=.8 if index==State.AFTERMATH else p.x*.95
