extends SceneTree
## Balance probe (not part of the suite): simulates fights with two bot anglers against every species and
## gear level, and the wait for a bite under typical conditions. Prints landing rate and fight length.
## --headless --script res://tests/balance_probe.gd
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
const DT: float=1./30.

## skilled: reads the cues (lets a run go, eases at the red zone, reels the rest); casual: only watches tension.
func _fight(f: Node,species: Resource,weight: float,skilled: bool) -> Array:
	f.state=Fishing.State.IDLE;f.hook_external(species,weight,"coast")
	var react:=0.;var want:=false;var t:=0.
	var reaction: float=.25 if skilled else .4
	while f.state==Fishing.State.REELING and t<400.:
		var target: bool
		if skilled:target=f.tension<(.62 if f.fight_phase in ["calm","jump"] else .45) and f.fight_phase!="run"
		else:target=f.tension<.85
		if target!=want:
			react+=DT
			if react>=reaction:want=target;react=0.
		else:react=0.
		f.set_reeling(want);f.advance(DT);t+=DT
	return [f.state==Fishing.State.CAUGHT,t]

func _initialize() -> void:
	var f: Node=Fishing.new();root.add_child(f)
	var rows: Array[String]=[]
	for lvl: int in [0,1,2,3]:
		f.rod_bonus=lvl*.15;f.line_bonus=lvl*.15;f.hook_bonus=lvl*.08
		rows.append("== gear level %d (capacity %.0f kg)"%[lvl,f.tackle_capacity()])
		for sp: Resource in Fishing.SPECIES:
			if not sp.capture_allowed:continue
			var line:="%-16s"%str(sp.id)
			for skilled: bool in [true,false]:
				var ok:=0;var time:=0.;var n:=40
				for k: int in n:
					var w: float=randf_range(float(sp.min_weight),float(sp.max_weight))
					var r: Array=_fight(f,sp,w,skilled)
					if r[0]:ok+=1;time+=float(r[1])
				line+="  %s %3d%% %5.1fs"%["hab" if skilled else "cas",ok*100/n,time/maxf(1.,ok)]
			rows.append(line)
	# Waiting time for a bite at a few typical rates.
	for rate: float in [.25*.4,.75,1.,1.6,3.,4.8]:
		f.conditions={"rate":rate,"depth":10.,"hour":12.};f.bait_bonus=0.;f.feed_bonus=0.
		var total:=0.
		for k: int in 200:
			f.state=Fishing.State.WAITING;f.state_time=0.;var t:=0.
			while f.state==Fishing.State.WAITING and t<600.:f.advance(.1);t+=.1
			total+=t
		rows.append("wait at rate %.2f: %.1f s"%[rate,total/200.])
	for r: String in rows:print(r)
	quit()
