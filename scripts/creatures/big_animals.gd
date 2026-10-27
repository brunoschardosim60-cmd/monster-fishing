extends RefCounted
## Sculpted large animals for sea events and monster lairs: whales (and the leviathan, a huge dark whale with
## glowing photophores and a spined back) and squid. Bodies are smooth lathes from creature_meshes.gd painted by
## whale_skin / kraken_skin shaders; fins and flukes are flipper blades. Head towards -Z, waterline-free (the
## caller decides depth). Each root carries metas: "fluke" (Node3D pivot that beats), "spout" (CPUParticles3D),
## "arms" (squid ShaderMaterials).
const Meshes=preload("res://scripts/creatures/creature_meshes.gd")

## Humpback-like whale `length` metres long. leviathan: darker, spined, glowing spots.
static func whale(length: float,leviathan: bool=false) -> Node3D:
	var root:=Node3D.new();root.name="Leviata" if leviathan else "Baleia"
	var L:=length
	# Profile from tail (y=0) to snout (y=L): narrow tail stock, deep chest, rounded head.
	var r:=PackedVector2Array([Vector2(0.,0.),Vector2(.035,.02),Vector2(.05,.1),Vector2(.07,.22),Vector2(.11,.36),Vector2(.15,.5),
		Vector2(.165,.62),Vector2(.16,.74),Vector2(.14,.84),Vector2(.11,.92),Vector2(.07,.97),Vector2(0.,1.)])
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/whale_skin.gdshader")
	mat.set_shader_parameter("body_length",L);mat.set_shader_parameter("beat_amp",L*.035)
	if leviathan:
		mat.set_shader_parameter("back_color",Color("10161c"));mat.set_shader_parameter("belly_color",Color("4a5560"))
		mat.set_shader_parameter("glow",1.6);mat.set_shader_parameter("beat",.6)
	var body:=MeshInstance3D.new();body.name="Corpo";body.mesh=_scaled(r,L)
	body.material_override=mat;body.rotation.x=-PI*.5;body.position.z=L*.5;body.extra_cull_margin=L*.1;root.add_child(body)
	# Body local: y along length (tail at +Z after rotation), lathe z becomes up.
	var fin_mat:=mat.duplicate() as ShaderMaterial;fin_mat.set_shader_parameter("beat_amp",0.)
	for side: float in [-1.,1.]:
		var pec:=MeshInstance3D.new();pec.mesh=Meshes.flipper("whale_pec_%d"%int(L),L*.26,L*.1,L*.08);pec.material_override=fin_mat
		pec.scale=Vector3(side,1.,1.);pec.position=Vector3(side*L*.13,-L*.06,-L*.18);pec.rotation=Vector3(0,-side*.35,-side*.45);root.add_child(pec)
	var fluke:=Node3D.new();fluke.name="Cauda";fluke.position=Vector3(0,0,L*.5);root.add_child(fluke)
	for side: float in [-1.,1.]:
		var blade:=MeshInstance3D.new();blade.mesh=Meshes.flipper("whale_fluke_%d"%int(L),L*.17,L*.09,L*.06);blade.material_override=fin_mat
		blade.scale=Vector3(side,1.,1.);blade.rotation.y=-side*.25;fluke.add_child(blade)
	root.set_meta("fluke",fluke);root.set_meta("beat",.6 if leviathan else .9);root.set_meta("beat_amp",L*.035)
	if leviathan:
		var spine:=StandardMaterial3D.new();spine.albedo_color=Color("1a2026");spine.roughness=.4
		for k: int in 9:
			var cone:=MeshInstance3D.new();var cm:=CylinderMesh.new();cm.top_radius=0.;cm.bottom_radius=L*.018;cm.height=L*(.05+.03*sin(float(k)*.7));cm.radial_segments=8
			cone.mesh=cm;cone.material_override=spine;cone.position=Vector3(0,L*.13-float(k)*L*.004,-L*.25+float(k)*L*.07);cone.rotation.x=.35;root.add_child(cone)
		var eye:=StandardMaterial3D.new();eye.albedo_color=Color("7fe6ff");eye.emission_enabled=true;eye.emission=Color("7fe6ff");eye.emission_energy_multiplier=3.
		for side: float in [-1.,1.]:
			var e:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=L*.012;sm.height=L*.024;e.mesh=sm;e.material_override=eye
			e.position=Vector3(side*L*.105,-L*.01,-L*.36);root.add_child(e)
	else:
		var spout:=CPUParticles3D.new();spout.name="Borrifo";spout.emitting=false;spout.one_shot=true;spout.amount=70;spout.lifetime=2.2;spout.explosiveness=.7
		spout.direction=Vector3.UP;spout.spread=12.;spout.initial_velocity_min=7.;spout.initial_velocity_max=11.;spout.gravity=Vector3(0,-4.5,0)
		spout.scale_amount_min=.6;spout.scale_amount_max=1.8
		var pm:=SphereMesh.new();pm.radius=.18;pm.height=.36;pm.radial_segments=6;pm.rings=3
		var sm2:=StandardMaterial3D.new();sm2.albedo_color=Color(.95,.97,1.,.5);sm2.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;sm2.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.material=sm2;spout.mesh=pm;spout.position=Vector3(0,L*.12,-L*.3);root.add_child(spout)
		root.set_meta("spout",spout)
	return root

static func _scaled(r: PackedVector2Array,L: float) -> ArrayMesh:
	var prof:=PackedVector2Array()
	for p: Vector2 in r:prof.append(Vector2(p.x*L,p.y*L))
	return Meshes.lathe("whale_body_%d"%int(L),prof,32,Vector2(1.,.82))

## A squid `length` metres long (mantle to arm tips): torpedo mantle with fins at the tip, eight arms and two
## long tentacles trailing behind and curling in the kraken_skin shader. Translucent pink-brown.
static func squid(length: float) -> Node3D:
	var root:=Node3D.new();root.name="Lula"
	var M:=length*.55
	var prof:=PackedVector2Array()
	for p: Vector2 in [Vector2(.0,0.),Vector2(.09,.03),Vector2(.12,.12),Vector2(.125,.35),Vector2(.11,.6),Vector2(.07,.82),Vector2(.03,.95),Vector2(0.,1.)]:
		prof.append(Vector2(p.x*M,p.y*M))
	var skin:=ShaderMaterial.new();skin.shader=preload("res://assets/shaders/kraken_skin.gdshader")
	skin.set_shader_parameter("hide_color",Color("b4604c"));skin.set_shader_parameter("mottle_color",Color("7a2c2a"));skin.set_shader_parameter("belly_color",Color("f0d2c4"))
	var mantle:=MeshInstance3D.new();mantle.name="Manto";mantle.mesh=Meshes.lathe("squid_mantle_%d"%int(M*10.),prof,20);mantle.material_override=skin
	mantle.rotation.x=-PI*.5;root.add_child(mantle)  # tip forward (-Z), head at origin
	for side: float in [-1.,1.]:
		var fin:=MeshInstance3D.new();fin.mesh=Meshes.flipper("squid_fin_%d"%int(M*10.),M*.22,M*.3,-M*.08);fin.material_override=skin
		fin.scale=Vector3(side,.6,1.);fin.position=Vector3(0,0,-M*.82);root.add_child(fin)
	var eye:=StandardMaterial3D.new();eye.albedo_color=Color("101010");eye.roughness=.1
	for side: float in [-1.,1.]:
		var e:=MeshInstance3D.new();var sm:=SphereMesh.new();sm.radius=M*.035;sm.height=M*.07;e.mesh=sm;e.material_override=eye
		e.position=Vector3(side*M*.1,M*.02,M*.04);root.add_child(e)
	var arms: Array[ShaderMaterial]=[]
	for k: int in 10:
		var long:=k>=8
		var a:=float(k)*TAU/8.+.2
		var arm_len:=length*(.75 if long else .4)
		var mat:=skin.duplicate() as ShaderMaterial
		mat.set_shader_parameter("tentacle",true);mat.set_shader_parameter("arm_length",arm_len)
		mat.set_shader_parameter("curl",.05/maxf(length*.3,.2));mat.set_shader_parameter("wave",.6/maxf(length*.5,.3));mat.set_shader_parameter("phase",float(k)*.8)
		var arm:=MeshInstance3D.new();arm.mesh=Meshes.tube("squid_arm_%d_%d"%[int(arm_len*10.),int(long)],arm_len,M*(.025 if long else .035),M*.005,18,8);arm.material_override=mat
		var off:=Vector3(cos(a),sin(a),0.)*M*(.04 if long else .07)
		# Tube +Y points backwards (+Z).
		arm.transform=Transform3D(Basis(Vector3(1,0,0),Vector3(0,0,1),Vector3(0,-1,0)),off+Vector3(0,0,M*.02))
		root.add_child(arm);arms.append(mat)
	root.set_meta("arms",arms)
	return root

## Keeps the fluke on the tail stock as the shader beats it (same clock as shader TIME).
static func beat_fluke(root: Node3D) -> void:
	var fluke: Node3D=root.get_meta("fluke") if root.has_meta("fluke") else null
	if fluke==null:return
	var t:=Time.get_ticks_msec()/1000.;var beat: float=root.get_meta("beat",.9);var amp: float=root.get_meta("beat_amp",.5)
	fluke.position.y=sin(t*beat)*amp
	fluke.rotation.x=-cos(t*beat)*.35
