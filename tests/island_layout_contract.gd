extends SceneTree
## Island layout contract: one coastline shared by collision, navigation, terrain mesh, map and shader.
## --headless --fixed-fps 60 --script res://tests/island_layout_contract.gd
const Layout=preload("res://scripts/world/archipelago_layout.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func contour(lobe: int, steps: int = 180) -> PackedVector2Array:
	var l := Layout.LOBES[lobe]
	var points := PackedVector2Array()
	for i: int in steps:
		var a := float(i) * TAU / float(steps)
		var edge := Layout.edge_factor(lobe, a)
		points.append(Vector2(l.x + cos(a) * l.z * edge, l.y + sin(a) * l.w * edge))
	return points

## Radial distance from a point to a lobe's own outline (negative inside).
func lobe_distance(p: Vector2, lobe: int) -> float:
	var l := Layout.LOBES[lobe]
	var q := (p - Vector2(l.x, l.y)) / Vector2(l.z, l.w)
	return (q.length() - Layout.edge_factor(lobe, atan2(q.y, q.x))) * minf(l.z, l.w)

func _run() -> void:
	check(Layout.REGIONS.size() == Layout.LOBES.size(), "every lobe has a region record")
	# 1. Shader include is generated from the layout and must not drift.
	var text := FileAccess.get_file_as_string("res://assets/shaders/archipelago_coast.gdshaderinc")
	var count_match := RegEx.create_from_string("const int ISLAND_COUNT=(\\d+);").search(text)
	check(count_match != null and int(count_match.get_string(1)) == Layout.LOBES.size(), "shader knows every island (%d)" % Layout.LOBES.size())
	var matches := RegEx.create_from_string("vec4\\((-?[\\d.]+),(-?[\\d.]+),(-?[\\d.]+),(-?[\\d.]+)\\)").search_all(text.substr(text.find("const vec4 ISLANDS"), text.find("const vec2 COLD_CENTER") - text.find("const vec4 ISLANDS")))
	var in_sync := matches.size() == Layout.LOBES.size()
	for i: int in mini(matches.size(), Layout.LOBES.size()):
		var l := Layout.LOBES[i]
		if not (is_equal_approx(float(matches[i].get_string(1)), l.x) and is_equal_approx(float(matches[i].get_string(2)), l.y) and is_equal_approx(float(matches[i].get_string(3)), l.z) and is_equal_approx(float(matches[i].get_string(4)), l.w)): in_sync = false
	check(in_sync, "shader island table equals Layout.LOBES (run scripts/pipeline/sync_coast_shader.py if this fails)")
	var cold := RegEx.create_from_string("COLD_CENTER=vec2\\((-?[\\d.]+),(-?[\\d.]+)\\)").search(text)
	check(cold != null and is_equal_approx(float(cold.get_string(1)), Layout.COLD_CENTER.x) and is_equal_approx(float(cold.get_string(2)), Layout.COLD_CENTER.y), "shader cold-water centre matches the layout")
	var harmonics_ok := true
	for h: Vector2 in Layout.REMOTE_HARMONICS:
		var term := RegEx.create_from_string("e\\+=([\\d.]+)\\*sin\\(" + str(int(h.x)) + "\\.\\*a\\+float\\(\\(i\\*7\\+" + str(int(h.x) * 13) + "\\)%17\\)\\*\\.37\\);").search(text)
		if term == null or not is_equal_approx(float(term.get_string(1)), h.y): harmonics_ok = false
	check(harmonics_ok, "shader outline harmonics equal Layout.REMOTE_HARMONICS")
	# 2. Distant islands stay clear of Aurora, of the world seam and of each other.
	var aurora_clear := 1e9
	var seam_safe := true
	var min_gap := 1e9
	var worst_pair := ""
	for i: int in Layout.LOBES.size():
		if Layout.is_aurora_lobe(i): continue
		for p: Vector2 in contour(i):
			if absf(p.x) > Layout.WORLD_HALF - 150. or absf(p.y) > Layout.WORLD_HALF - 150.: seam_safe = false
			for a: int in [0, 1, 2, 3, 7]: aurora_clear = minf(aurora_clear, lobe_distance(p, a))
			for j: int in Layout.LOBES.size():
				if j == i or Layout.is_aurora_lobe(j): continue
				var gap := lobe_distance(p, j)
				if gap < min_gap: min_gap = gap; worst_pair = "%s/%s" % [Layout.REGIONS[i].id, Layout.REGIONS[j].id]
	check(aurora_clear > 300., "distant islands keep a wide channel around Aurora (%.0f m)" % aurora_clear)
	check(seam_safe, "no island touches the world wrap seam")
	check(min_gap > 25., "islands never overlap and leave a navigable channel (narrowest %.0f m, %s)" % [min_gap, worst_pair])
	# 3. Outlines are irregular, not ellipses, and always star-shaped (no overhangs).
	var irregular := true
	for i: int in Layout.LOBES.size():
		if Layout.is_aurora_lobe(i): continue
		var low := 10.
		var high := 0.
		for k: int in 360:
			var e := Layout.edge_factor(i, float(k) * TAU / 360.)
			low = minf(low, e); high = maxf(high, e)
		if high - low < .12 or low < .6: irregular = false
	check(irregular, "every distant island has a varied outline (spread 0.12+, never pinched below 0.6)")
	# 4. Terrain mesh, collision contour and navigation agree about where land ends.
	var world := preload("res://scripts/world/coastal_world.gd").new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	for frame: int in range(4): await physics_frame
	check(world.remote_island_count == Layout.LOBES.size() - 5, "every distant island was built")
	var worst_shore := 0.
	var worst_inland := 1e9
	for i: int in Layout.LOBES.size():
		if Layout.is_aurora_lobe(i): continue
		var l := Layout.LOBES[i]
		var biome := str(Layout.REGIONS[i].biome)
		for k: int in 12:
			var a := float(k) * TAU / 12.
			var rim: Vector2 = world._island_offset(i, Vector2(l.z, l.w), a, 1. / world.SHORE_PAD)
			var h: float = world._island_height(rim.x, rim.y, 1. / world.SHORE_PAD, false, biome, i)
			worst_shore = maxf(worst_shore, absf(h))
			var inland: Vector2 = world._island_offset(i, Vector2(l.z, l.w), a, .45)
			# Lakes and streams are deliberate low spots; solid-land sampling skips them.
			if world._near_water(inland.x, inland.y, i, 2.8): continue
			worst_inland = minf(worst_inland, world._island_height(inland.x, inland.y, .45, false, biome, i))
	check(worst_shore < .05, "mesh waterline sits exactly on the coast contour (worst %.3f m)" % worst_shore)
	check(worst_inland > 2.5, "every island is solid land at 45%% radius (lowest %.1f m)" % worst_inland)
	var land_ok := true
	for i: int in Layout.LOBES.size():
		var l := Layout.LOBES[i]
		if not world.is_land(Vector3(l.x, 0, l.y)): land_ok = false
		if world.is_land(Vector3(l.x + l.z * 1.8, 0, l.y + l.w * 1.8)) and i == 16: land_ok = false
	check(land_ok, "navigation treats island centres as land and open water beside them as sea")
	print("ISLAND LAYOUT %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
