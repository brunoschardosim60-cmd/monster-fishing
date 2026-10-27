extends Node3D
## Each region gets a landmark you can recognise from the water and a story to find there:
##   storm     — a galleon driven onto the rocks;            shadow  — an abandoned lighthouse in the fog;
##   desert    — ruins of an amber temple;                   tropical — a village of huts on stilts;
##   mystic    — a ring of standing stones with glowing runes; volcanic — a smoking crater;
##   mountain  — an old watchtower on the heights;           frost   — an arch of blue ice;
##   reef      — a sandbar with coral heads around it.
## Reaching one tells part of the archipelago's legend (and a hint about its monsters), pays a little and is
## remembered (village.discovered). Some regions also have their own sea: fog banks around the mystic and
## shadow islands.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
const G=preload("res://scripts/world/geometry.gd")
const LORE: Dictionary={
	"storm":"O casco do Albatroz Real ainda range nas pedras. No diário do capitão: \"o mar girou sem vento e as cordas foram puxadas para baixo\".",
	"shadow":"O Farol da Sombra está apagado há trinta anos. A última anotação do faroleiro: \"à noite, uma sombra maior que a ilha passa sob a luz\".",
	"desert":"Nas colunas do Templo de Âmbar, entalhes mostram uma serpente que atravessa o mar seguindo o sol, sempre de dia.",
	"tropical":"Os pescadores das palafitas contam: quem joga ração ao entardecer vê os cardumes grandes subirem. E nunca saem com tempestade no horizonte.",
	"mystic":"As runas do Círculo dos Ecos brilham quando o sonar toca. Dizem que algumas leituras do fundo respondem a quem não está lá.",
	"volcanic":"A cratera fumega dia e noite. Ao redor da Coroa, a água é quente e os redemoinhos aparecem quando o mar engrossa.",
	"mountain":"Da torre de vigia via-se o Trono do Leviatã. Os vigias acendiam fogueiras quando as ondas cresciam sem vento.",
	"frost":"Sob o arco de gelo, um baú congelado e uma frase riscada: \"o kraken odeia luz — atravesse a fossa às escuras\".",
	"reef":"No banco de areia, um velho pescador: \"o fundo do recife esconde naufrágios. Com máscara e cilindro, você alcança os baús\"."}
var game_ref: Node
var marks: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed=8008
	await get_tree().physics_frame
	await get_tree().physics_frame
	var done: Dictionary={}
	for i: int in Layout.LOBES.size():
		var region: Dictionary=Layout.region_for_lobe(i)
		if not bool(region.get("map_visible",false)) or Layout.is_aurora_lobe(i):continue
		var id: String=region.get("id","");var biome: String=region.get("biome","")
		if done.has(id) or not LORE.has(biome) and id!="reef":continue
		done[id]=true
		var kind:="reef" if id=="reef" else biome
		_build(i,id,kind)

## A point on land near the shore of a lobe facing `angle`, from a physics ray (terrain colliders).
func _shore_point(lobe: int,angle: float,inland: float) -> Vector3:
	var l: Vector4=Layout.LOBES[lobe];var dir:=Vector2.from_angle(angle);var p:=Vector2(l.x,l.y)
	for step: int in 800:
		if Layout.coast(p+dir*2.).x>-inland:break
		p+=dir*2.
	var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,500.,p.y),Vector3(p.x,-60.,p.y));q.collision_mask=1
	var hit:=get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3(p.x,0.,p.y) if hit.is_empty() else hit.position

func _build(lobe: int,id: String,kind: String) -> void:
	var l: Vector4=Layout.LOBES[lobe]
	var facing:=(Vector2(0,300)-Vector2(l.x,l.y)).angle()  # towards the home waters
	var root:=Node3D.new();root.name="Marco_"+id;add_child(root)
	var at: Vector3
	match kind:
		"storm":
			at=_shore_point(lobe,facing+.6,4.)
			var hull:=MeshInstance3D.new();hull.mesh=load("res://assets/models/imported/sailing_ship.res")
			var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/imported_model.gdshader");hull.material_override=mat
			hull.scale=Vector3.ONE*42.;hull.set_instance_shader_parameter("model_scale",42.);hull.set_instance_shader_parameter("wreck",.6)
			hull.set_instance_shader_parameter("hull_paint",Color("2a2018"));hull.rotation=Vector3(.12,_rng.randf()*TAU,.42);hull.position=Vector3(0,-1.5,0)
			root.add_child(hull)
			for k: int in 6:
				var a:=float(k)*1.1;var spire:=G.cylinder(root,Vector3(cos(a)*30.+10.,6.,sin(a)*24.),3.+float(k%3),14.+float(k%4)*5.,G.material(Color("3d4044"),.9),.4+float(k%2),7)
				spire.rotation.z=(float(k%3)-1.)*.1
		"shadow":
			at=_shore_point(lobe,facing,22.)
			var tower:=preload("res://scripts/world/navigation_lighthouse.gd").new();tower.style="pedra";tower.tower_height=30.;tower.abandoned=true
			tower.world=get_parent();tower.scale=Vector3.ONE*1.3;tower.rotation=Vector3(.04,0,.03);root.add_child(tower)
			var dead:=G.material(Color("2b2622"),.95)
			for k: int in 7:
				var a:=float(k)*.9;var trunk:=G.cylinder(root,Vector3(cos(a)*18.,3.,sin(a)*18.+8.),.35,6.+float(k%3)*2.,dead,.12,6)
				trunk.rotation.z=(float(k%4)-1.5)*.15
		"desert":
			at=_shore_point(lobe,facing,40.)
			var stone:=G.material(Color("d2a86a"),.85);var dark:=G.material(Color("a87e48"),.9)
			for k: int in 10:
				var a:=float(k)*TAU/10.;var h:=9. if k%3!=0 else 3.5+float(k%2)*2.
				G.cylinder(root,Vector3(cos(a)*14.,h*.5,sin(a)*14.),1.1,h,stone,1.,10)
				G.box(root,Vector3(cos(a)*14.,.4,sin(a)*14.),Vector3(3.,.8,3.),dark)
			G.box(root,Vector3(0,9.4,-14.),Vector3(10.,1.4,2.6),stone);G.box(root,Vector3(0,1.,0),Vector3(5.,2.,3.),dark)
		"tropical":
			at=_shore_point(lobe,facing-.4,-6.);at.y=0.
			var wood:=G.material(Color("7a5a38"),.9);var thatch:=G.material(Color("c9a86a"),.95)
			for k: int in 5:
				var o:=Vector3(float(k)*9.-18.,0,float(k%2)*7.)
				for c: Vector2 in [Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]:G.cylinder(root,o+Vector3(c.x,.5,c.y),.18,5.,wood,.18,6)
				G.box(root,o+Vector3(0,3.,0),Vector3(5.,.3,5.),wood);G.box(root,o+Vector3(0,4.4,0),Vector3(4.4,2.6,4.4),G.material(Color("b08a5a"),.9))
				var roof:=G.cylinder(root,o+Vector3(0,6.5,0),4.,2.4,thatch,0.,4);roof.rotation.y=PI*.25
			G.box(root,Vector3(0,3.,-6.),Vector3(44.,.25,1.6),wood)
		"mystic":
			at=_shore_point(lobe,facing,35.)
			var rune:=G.material(Color("54d7d3"));rune.emission_enabled=true;rune.emission=Color("54d7d3");rune.emission_energy_multiplier=2.2
			for k: int in 9:
				var a:=float(k)*TAU/9.
				var stone2:=G.box(root,Vector3(cos(a)*12.,3.,sin(a)*12.),Vector3(1.6,6.+float(k%3),1.),G.material(Color("5a6066"),.9));stone2.rotation.y=-a
				G.sphere(root,Vector3(cos(a)*11.4,4.,sin(a)*11.4),Vector3(.4,.9,.2),rune,8)
			G.cylinder(root,Vector3(0,.6,0),2.4,1.2,G.material(Color("3e4448"),.9),2.4,16)
			var light:=OmniLight3D.new();light.light_color=Color("54d7d3");light.omni_range=26.;light.light_energy=1.6;light.position.y=4.;root.add_child(light)
		"volcanic":
			at=_shore_point(lobe,facing,999.)
			var smoke:=CPUParticles3D.new();smoke.amount=60;smoke.lifetime=16.;smoke.preprocess=16.;smoke.direction=Vector3.UP;smoke.spread=12.
			smoke.initial_velocity_min=4.;smoke.initial_velocity_max=7.;smoke.gravity=Vector3(1.5,.2,0);smoke.scale_amount_min=10.;smoke.scale_amount_max=26.
			smoke.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;smoke.emission_sphere_radius=8.
			# Soft round puffs (radial gradient billboards), not polygon balls.
			var puff:=GradientTexture2D.new();puff.fill=GradientTexture2D.FILL_RADIAL;puff.fill_from=Vector2(.5,.5);puff.fill_to=Vector2(1.,.5)
			var g:=Gradient.new();g.set_color(0,Color(1,1,1,1));g.set_color(1,Color(1,1,1,0));puff.gradient=g;puff.width=64;puff.height=64
			var pm:=QuadMesh.new();pm.size=Vector2(2.,2.)
			var sm:=StandardMaterial3D.new();sm.albedo_texture=puff;sm.albedo_color=Color(.5,.48,.47,.22);sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;sm.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;sm.vertex_color_use_as_albedo=true;sm.albedo_color=Color(1,1,1,1)
			var ramp:=Gradient.new();ramp.set_color(0,Color(.45,.43,.42,0.));ramp.set_color(1,Color(.62,.6,.6,0.));ramp.add_point(.15,Color(.4,.38,.37,.32));ramp.add_point(.6,Color(.55,.53,.52,.2))
			smoke.color_ramp=ramp;pm.material=sm;smoke.mesh=pm;smoke.position.y=4.;smoke.visibility_aabb=AABB(Vector3(-150,0,-150),Vector3(300,300,300));root.add_child(smoke)
			var glow:=OmniLight3D.new();glow.light_color=Color("ff5a2a");glow.omni_range=60.;glow.light_energy=3.;glow.position.y=6.;root.add_child(glow)
		"mountain":
			at=_shore_point(lobe,facing,999.)
			var stone3:=G.material(Color("8a8678"),.9)
			G.cylinder(root,Vector3(0,9.,0),4.,18.,stone3,4.6,12);G.cylinder(root,Vector3(0,19.,0),5.,2.,stone3,5.,12)
			for k: int in 8:var a2:=float(k)*TAU/8.;G.box(root,Vector3(cos(a2)*4.6,20.6,sin(a2)*4.6),Vector3(1.4,1.2,1.4),stone3)
			var fire:=OmniLight3D.new();fire.light_color=Color("ffae5a");fire.omni_range=30.;fire.light_energy=2.;fire.position.y=21.;root.add_child(fire)
		"frost":
			at=_shore_point(lobe,facing,2.)
			var ice:=G.material(Color("bfe9ff"),.15);ice.metallic_specular=.9;ice.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ice.albedo_color.a=.85
			var arch:=MeshInstance3D.new();var tm:=TorusMesh.new();tm.inner_radius=10.;tm.outer_radius=15.;tm.rings=32;tm.ring_segments=10;arch.mesh=tm;arch.material_override=ice
			arch.rotation.x=PI*.5;arch.position.y=-2.;root.add_child(arch)
			for k: int in 5:G.sphere(root,Vector3(float(k)*14.-28.,1.,22.+float(k%2)*8.),Vector3(8.,6.+float(k%3)*3.,7.),ice,10)
		"reef":
			at=_shore_point(lobe,facing,-30.);at.y=0.
			G.ellipsoid(root,Vector3(0,-.3,0),Vector3(26.,1.2,14.),G.material(Color("f0e2b8"),.95),16)
			var palm:=G.cylinder(root,Vector3(2,4.,0),.3,8.,G.material(Color("8a6a46"),.9),.22,6);palm.rotation.z=.15
			G.sphere(root,Vector3(3.2,8.,0),Vector3(4.,1.2,4.),G.material(Color("3f8a3a"),.8),8)
			for k: int in 14:
				var a3:=float(k)*.45;var col:Color=[Color("ff7a8a"),Color("ffb04a"),Color("b07aff"),Color("6ad6c4")][k%4]
				G.sphere(root,Vector3(cos(a3)*(20.+float(k%3)*6.),-1.6,sin(a3)*(12.+float(k%3)*5.)),Vector3(2.,1.6,2.),G.material(col,.7),8)
	root.position=at
	root.rotation.y=-facing+PI*.5 if kind!="tropical" else 0.
	marks.append({"id":"marco_"+id,"kind":kind,"pos":at,"lobe":lobe,"name":str(Layout.region_for_lobe(lobe).get("name",id))})

func _process(_delta: float) -> void:
	var game=get_tree().get_first_node_in_group("game")
	if game==null:return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var eye:=camera.global_position
	# Fog banks around the mystic and shadow islands.
	var fog:=0.
	for m: Dictionary in marks:
		if m.kind in ["mystic","shadow"]:
			var l: Vector4=Layout.LOBES[m.lobe]
			var d:=Vector2(eye.x-l.x,eye.z-l.y).length()/maxf(l.z,l.w)
			fog=maxf(fog,(.0045 if m.kind=="mystic" else .0032)*(1.-smoothstep(1.2,2.6,d)))
	game.world.ocean.weather.local_fog=fog
	if not game.started:return
	var p: Vector3=game.player.global_position if not game.player.in_boat else game.boat.global_position
	for m: Dictionary in marks:
		if game.world.village.discovered.has(m.id):continue
		if p.distance_to(m.pos)<70.:
			game.world.village.discovered[m.id]=str(m.name)+" — "+{"storm":"navio encalhado","shadow":"farol abandonado","desert":"Templo de Âmbar","tropical":"palafitas","mystic":"Círculo dos Ecos","volcanic":"cratera fumegante","mountain":"torre de vigia","frost":"arco de gelo","reef":"banco de areia"}.get(m.kind,"marco")
			game.inventory.money+=25;game.inventory.changed.emit()
			game.hud.notify("%s · %s (+25 moedas)"%[m.name,LORE.get(m.kind,"")])
			game.audio.cue("mission")
