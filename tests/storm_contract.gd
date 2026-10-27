extends "res://tests/archipelago_contract.gd"
## Hull in the waves: distributed buoyancy drives heave, pitch and roll. Calm water: the hull sits at its
## waterline nearly level. Rough water: the bow lifts as a crest passes under it and drops after; small
## light hulls pitch and roll more and faster than big heavy ones; nothing explodes; a beam wind pushes the
## bow off course; the player keeps footing on deck.
## --headless --fixed-fps 60 --script res://tests/storm_contract.gd
const Waves=preload("res://scripts/world/wave_field.gd")
## Sea state driven by the test (the ocean node is paused): wind, energy, direction.
var sea:=[.08,.12,Vector2(1,0)]
func _sea(wind: float,energy: float,dir: Vector2) -> void:
	sea=[wind,energy,dir];Waves.advance(0.,wind,energy,0.,dir)
func _tick() -> void:
	Waves.advance(1./60.,sea[0],sea[1],0.,sea[2])
	await physics_frame
func _ticks(n: int) -> void:
	for i: int in n:await _tick()

## Runs `n` frames and returns motion statistics of the visual hull.
func _record(boat: CharacterBody3D,n: int) -> Dictionary:
	var st:={"float_err":0.,"pitch_max":0.,"roll_max":0.,"y_min":99.,"y_max":-99.,"corr":0.,"crossings":0,"bad":false,"jerk":0.}
	var prev_rate: float=boat.roll_rate
	var prev_v:=0.
	var sxy:=0.;var sxx:=0.;var syy:=0.
	for f: int in n:
		await _tick()
		var h: Node3D=boat._hull
		var p: float=h.rotation.x;var r: float=h.rotation.z;var y: float=h.position.y
		if is_nan(p) or is_nan(r) or is_nan(y):st.bad=true;break
		st.pitch_max=maxf(st.pitch_max,absf(p));st.roll_max=maxf(st.roll_max,absf(r))
		st.y_min=minf(st.y_min,y);st.y_max=maxf(st.y_max,y)
		st.float_err+=absf(y-(Waves.height_at(boat.global_position)-float(boat.hydrodynamics.draft_offset)))/float(n)
		var L: float=float(boat.hydrodynamics.waterline_length)*boat.size_factor
		var slope: float=Waves.height_at(boat.global_position-boat.global_basis.z*L*.45)-Waves.height_at(boat.global_position+boat.global_basis.z*L*.45)
		sxy+=slope*p;sxx+=slope*slope;syy+=p*p
		if signf(boat.heave_velocity)!=signf(prev_v) and absf(boat.heave_velocity)>.02:st.crossings+=1
		prev_v=boat.heave_velocity
		st.jerk+=absf(boat.roll_rate-prev_rate)/float(n);prev_rate=boat.roll_rate
	st.corr=sxy/sqrt(maxf(sxx*syy,1e-9))
	return st

func run() -> void:
	game=load("res://scenes/main/main.tscn").instantiate();root.add_child(game);game.begin_play();game.audio.stop_all()
	for action: StringName in InputMap.get_actions():InputMap.action_erase_events(action)
	await frames(12)
	var boat: CharacterBody3D=game.boat
	game.world.ocean.process_mode=Node.PROCESS_MODE_DISABLED
	game.world.storms.process_mode=Node.PROCESS_MODE_DISABLED
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	game.player.global_position=boat.global_position+Vector3(0,1.5,0);game.interact();await frames(5)
	# Calm.
	_sea(.08,.12,Vector2(1,0))
	await frames(120)
	var calm: Dictionary=await _record(boat,240)
	check(not calm.bad and calm.pitch_max<.06 and calm.roll_max<.06 and calm.float_err<.12,"in calm water the hull floats level at its waterline (pitch %.3f, roll %.3f, off by %.2f m)"%[calm.pitch_max,calm.roll_max,calm.float_err])
	# Rough, head sea.
	_sea(.85,.95,Vector2(0,1))
	await frames(60)
	var rough: Dictionary=await _record(boat,600)
	check(not rough.bad,"no instability in a big sea")
	check(rough.pitch_max>calm.pitch_max*3. and rough.y_max-rough.y_min>.4,"a big sea lifts and drops the hull (pitch %.2f rad, heave %.1f m)"%[rough.pitch_max,rough.y_max-rough.y_min])
	check(rough.corr>.4,"the bow rises when a crest is under it and falls after (correlation %.2f)"%rough.corr)
	check(rough.pitch_max<=float(boat.hydrodynamics.maximum_tilt)*1.5+.001,"pitch stays within the playable limit")
	# Small vs big hull in the same moderate beam sea.
	_sea(.55,.6,Vector2(1,0))
	var stats: Dictionary={}
	for id: String in ["canoa","escuna"]:
		game.inventory.owned_boats.append(id);game.inventory.boat_id=id;Economy.apply(game.inventory,boat,game.fishing)
		boat.sail_target=0.
		if boat.sail_rig!=null:boat.sail_rig.hoist=0.
		boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.;await frames(120)
		stats[id]=await _record(boat,600)
	check(stats.canoa.roll_max>stats.escuna.roll_max*1.3,"a canoe rolls more than a schooner in the same sea (%.2f vs %.2f rad)"%[stats.canoa.roll_max,stats.escuna.roll_max])
	check(stats.canoa.jerk>stats.escuna.jerk*2.,"…and is thrown about by every short wave, while the schooner's mass and length give it a slow, heavy motion (roll jerk %.4f vs %.4f)"%[stats.canoa.jerk,stats.escuna.jerk])
	# Wind on the beam pushes the bow off course without correction.
	game.inventory.boat_id="aurora";Economy.apply(game.inventory,boat,game.fishing)
	boat.global_position=Vector3(250,0,-300);boat.rotation=Vector3.ZERO;boat.speed=0.
	_sea(.9,.3,Vector2(1,0))
	await _ticks(300)
	check(boat.rotation.y<-.1,"a strong beam wind turns the bow away downwind (Δ %.2f rad)"%boat.rotation.y)
	# Footing on deck in rough water.
	_sea(.85,.95,Vector2(0,1))
	game.toggle_deck();await frames(5)
	var ok:=true;var deck: Dictionary=boat.deck_layout()
	for f: int in 300:
		await _tick()
		var local: Vector3=boat._hull.to_local(game.player.global_position)
		if absf(local.y-float(deck.y))>.6 or absf(local.x)>float(deck.x)+.05:ok=false
	check(ok,"the player keeps footing on the deck in rough water")
	print("STORM %d checks / %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
