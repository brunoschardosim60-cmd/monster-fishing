extends SceneTree
## NPC variety contract: every villager, fisher, vendor, trail walker and keeper has a distinct look.
## --headless --fixed-fps 60 --script res://tests/npc_look_contract.gd
const Look=preload("res://scripts/world/npc_look.gd")
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

func frames(n: int) -> void:
	for i: int in n: await process_frame

func signature(look: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [look.name, look.skin, look.hair, look.headwear, look.headwear_tint]

func _run() -> void:
	var seen: Dictionary = {}
	for id: int in range(1, 22): seen[signature(Look.for_id(id))] = true
	check(seen.size() == 21, "21 NPC ids give 21 distinct appearances (%d)" % seen.size())
	check(signature(Look.for_id(5)) == signature(Look.for_id(5)), "a look is deterministic for its id")
	var heights: Array = []
	for id: int in range(1, 22): heights.append(snappedf(Look.for_id(id).height, .001))
	heights.sort()
	check(heights[-1] - heights[0] > .08, "heights vary by more than 8%% (%.3f to %.3f)" % [heights[0], heights[-1]])
	var skins: Dictionary = {}
	for id: int in range(1, 22): skins[Look.for_id(id).skin] = true
	check(skins.size() >= 4, "at least four skin tones in use (%d)" % skins.size())
	var mask: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/skin_zone_mask.png"))
	var lit := 0
	for y: int in range(0, mask.get_height(), 4):
		for x: int in range(0, mask.get_width(), 4):
			if mask.get_pixel(x, y).r > .5: lit += 1
	var share := float(lit) / float((mask.get_width() / 4) * (mask.get_height() / 4))
	check(share > .003 and share < .25, "skin-zone mask covers head and hands only (%.1f%% of the atlas)" % (share * 100.))
	var world := preload("res://scripts/world/coastal_world.gd").new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	await frames(6)
	var people: Array[Node3D] = []
	people.append_array(world.village.residents)
	people.append_array(world.village.bridge_district.walkers)
	people.append_array(world.village.bridge_district.fishers)
	people.append_array(world.village.bridge_district.vendors)
	for child: Node in world.trail_walkers.get_children(): people.append(child)
	check(people.size() >= 21, "at least 21 NPCs live on the island (%d)" % people.size())
	var signatures: Dictionary = {}
	var dressed := 0
	for person: Node3D in people:
		var visual: Node3D = person if person.has_method("apply_look") else person.visual
		var body: MeshInstance3D = visual.model.find_children("*", "MeshInstance3D", true, false)[0]
		var mat: Material = body.get_surface_override_material(0)
		if mat is ShaderMaterial:
			dressed += 1
			signatures["%s|%s|%s|%s" % [mat.get_shader_parameter("cloth_hue"), mat.get_shader_parameter("skin_mul"), mat.get_shader_parameter("hair_mul"), visual.scale]] = true
	check(dressed == people.size(), "every NPC has its own outfit material (%d of %d)" % [dressed, people.size()])
	check(signatures.size() >= people.size() - 1, "no two NPCs share the same outfit, skin, hair and build (%d unique)" % signatures.size())
	var walker: Node3D = world.trail_walkers.get_child(0)
	var start: Vector3 = walker.position
	await frames(240)
	check(walker.position.distance_to(start) > 1.5, "trail walkers move along their path (%.1f m)" % walker.position.distance_to(start))
	var on_ground := true
	for child: Node in world.trail_walkers.get_children():
		if child.route.size() > 1 and absf(child.position.y - Layout.height(Vector2(child.position.x, child.position.z))) > .5: on_ground = false
	check(on_ground, "trail walkers follow the terrain")
	print("NPC LOOKS %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
