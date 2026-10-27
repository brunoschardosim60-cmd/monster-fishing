extends Node3D
## Storm cells: local storms that live somewhere on the map, can be seen coming and avoided or crossed.
##  · roaming cells form upwind in open water, drift with the wind across the sea for ten minutes or so,
##    build up, rage and die out;
##  · anchored cells never leave the storm regions (Ilhas Adversas, Círculo da Tempestade, Dentes do Mar);
##    they breathe stronger and weaker over a few minutes.
## Each cell is a dark cloud deck with a curtain of rain under it and lightning, visible from kilometres.
## Inside a cell the swell rises and sharpens (wave_field.gd / ocean_common storm_factor), the wind blows hard,
## rain closes the view and waves hit the hull (fishing_boat.gd). Small boats run for shelter from it.
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Waves=preload("res://scripts/world/wave_field.gd")
var world: Node3D
var cells: Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
var _spawn_clock: float=25.
var _warned: bool=false
var _deck_mesh: CylinderMesh
var _rain_mesh: CylinderMesh
var _deck_mat: ShaderMaterial
var _rain_mat: ShaderMaterial

func _ready() -> void:
	_rng.seed=6061
	_deck_mat=ShaderMaterial.new();_deck_mat.shader=preload("res://assets/shaders/storm_cloud.gdshader")
	_rain_mat=ShaderMaterial.new();_rain_mat.shader=preload("res://assets/shaders/storm_rain.gdshader")
	_deck_mesh=CylinderMesh.new();_deck_mesh.top_radius=1.;_deck_mesh.bottom_radius=.82;_deck_mesh.height=1.;_deck_mesh.radial_segments=48;_deck_mesh.rings=4
	_rain_mesh=CylinderMesh.new();_rain_mesh.top_radius=.8;_rain_mesh.bottom_radius=.9;_rain_mesh.height=1.;_rain_mesh.radial_segments=48;_rain_mesh.rings=1;_rain_mesh.cap_top=false;_rain_mesh.cap_bottom=false
	for i: int in Layout.LOBES.size():
		var region: Dictionary=Layout.region_for_lobe(i)
		if str(region.get("biome",""))!="storm" or not bool(region.get("map_visible",false)):continue
		var l: Vector4=Layout.LOBES[i]
		_add(Vector2(l.x,l.y),Vector2.ZERO,maxf(l.z,l.w)*1.7,.85,INF,true)

func _add(at: Vector2,velocity: Vector2,radius: float,peak: float,life: float,anchored: bool) -> Dictionary:
	var node:=Node3D.new();node.name="Tempestade_%d"%cells.size();add_child(node)
	var deck:=MeshInstance3D.new();deck.mesh=_deck_mesh;deck.material_override=_deck_mat;deck.scale=Vector3(radius*1.05,420.,radius*1.05);deck.position.y=380.
	deck.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;deck.extra_cull_margin=radius;node.add_child(deck)
	var rain:=MeshInstance3D.new();rain.mesh=_rain_mesh;rain.material_override=_rain_mat;rain.scale=Vector3(radius*.85,200.,radius*.85);rain.position.y=100.
	rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rain.extra_cull_margin=radius;node.add_child(rain)
	var flash:=OmniLight3D.new();flash.omni_range=900.;flash.light_energy=0.;flash.light_color=Color("dfe8ff");flash.position.y=250.;flash.shadow_enabled=false;node.add_child(flash)
	var bolt:=MeshInstance3D.new();bolt.visible=false;node.add_child(bolt)
	var cell:={"pos":at,"vel":velocity,"radius":radius,"peak":peak,"intensity":0. if not anchored else peak,"age":0.,"life":life,"anchored":anchored,
		"node":node,"deck":deck,"rain":rain,"flash":flash,"bolt":bolt,"strike":_rng.randf_range(2.,6.),"flash_t":0.,"phase":_rng.randf()*TAU}
	node.position=Vector3(at.x,0,at.y)
	cells.append(cell)
	return cell

## Dev / scripted: a storm right here, already at full strength.
func spawn_at(at: Vector3) -> String:
	var c:=_add(Vector2(at.x,at.z),Vector2.from_angle(_rng.randf()*TAU)*3.,520.,1.,420.,false)
	c.age=60.
	return "Uma tempestade se forma sobre você!"

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var eye:=Vector2(camera.global_position.x,camera.global_position.z)
	_spawn_clock-=delta
	var roaming:=cells.filter(func(c: Dictionary) -> bool:return not c.anchored).size()
	if _spawn_clock<=0. and roaming<2:
		_spawn_clock=_rng.randf_range(90.,200.)
		_spawn_roaming(eye)
	var wind_dir:=Waves.direction
	for c: Dictionary in cells.duplicate():
		c.age=float(c.age)+delta
		if c.anchored:
			c.intensity=float(c.peak)*(.65+.35*sin(float(c.age)*.012+float(c.phase)))
		else:
			c.vel=(c.vel as Vector2).lerp(wind_dir*6.,delta*.02)
			c.pos=(c.pos as Vector2)+(c.vel as Vector2)*delta
			var life: float=c.life
			c.intensity=float(c.peak)*smoothstep(0.,70.,float(c.age))*(1.-smoothstep(life-90.,life,float(c.age)))
			if float(c.age)>life or (c.pos as Vector2).length()>Layout.WORLD_HALF*1.2:
				(c.node as Node3D).queue_free();cells.erase(c);continue
		var node: Node3D=c.node;node.position=Vector3((c.pos as Vector2).x,0,(c.pos as Vector2).y)
		var k: float=c.intensity
		(c.deck as MeshInstance3D).set_instance_shader_parameter("intensity",k)
		(c.rain as MeshInstance3D).set_instance_shader_parameter("intensity",k)
		_lightning(c,delta,eye)
	# The four cells nearest the camera shape the sea; the camera's own storm drives the weather.
	cells.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return (a.pos as Vector2).distance_squared_to(eye)<(b.pos as Vector2).distance_squared_to(eye))
	var shaped: Array[Vector4]=[]
	for c: Dictionary in cells.slice(0,4):shaped.append(Vector4((c.pos as Vector2).x,(c.pos as Vector2).y,float(c.radius),float(c.intensity)))
	Waves.storm_cells=shaped
	var here:=Waves.storm_factor(eye)
	if world!=null and world.ocean!=null:world.ocean.weather.local_storm=here
	_warn(eye,here)

func _spawn_roaming(eye: Vector2) -> void:
	for attempt: int in 20:
		var upwind:=-Waves.direction.rotated(_rng.randf_range(-.9,.9))
		var at:=eye+upwind*_rng.randf_range(1400.,2600.)
		if Layout.coast(at).x<200. or absf(at.x)>Layout.WORLD_HALF-300. or absf(at.y)>Layout.WORLD_HALF-300.:continue
		_add(at,Waves.direction*_rng.randf_range(4.,7.),_rng.randf_range(380.,620.),_rng.randf_range(.75,1.),_rng.randf_range(480.,780.),false)
		return

func _warn(eye: Vector2,here: float) -> void:
	var game=get_tree().get_first_node_in_group("game")
	if game==null or not game.started:return
	if here>.12 and not _warned:
		_warned=true
		game.hud.notify("Você entrou numa tempestade: vento forte e ondas batendo no casco. Atravesse rápido ou volte para o abrigo.")
	elif here<.03:_warned=false

## Nearest storm to a point: [distance to its edge in metres, heading Vector2, intensity] or [] if none.
func nearest(at: Vector2) -> Array:
	var best: Array=[];var best_d:=INF
	for c: Dictionary in cells:
		var d:=(c.pos as Vector2).distance_to(at)-float(c.radius)
		if d<best_d and float(c.intensity)>.2:best_d=d;best=[d,((c.pos as Vector2)-at).normalized(),float(c.intensity)]
	return best

func _lightning(c: Dictionary,delta: float,eye: Vector2) -> void:
	var flash: OmniLight3D=c.flash;var bolt: MeshInstance3D=c.bolt
	c.flash_t=maxf(0.,float(c.flash_t)-delta)
	flash.light_energy=float(c.flash_t)/.25*14. if float(c.flash_t)>0. else 0.
	bolt.visible=float(c.flash_t)>.08
	if float(c.intensity)<.45:return
	c.strike=float(c.strike)-delta
	if float(c.strike)>0.:return
	c.strike=_rng.randf_range(3.,9.)/float(c.intensity)
	var r: float=c.radius
	var local:=Vector3(_rng.randf_range(-r,r)*.6,0,_rng.randf_range(-r,r)*.6)
	flash.position=local+Vector3(0,240,0);c.flash_t=.25
	bolt.mesh=_bolt_mesh(_rng.randi());bolt.position=local;bolt.visible=true
	var at: Vector3=(c.node as Node3D).global_position+local
	if eye.distance_to(Vector2(at.x,at.z))<3000. and world!=null and world.ocean!=null and world.ocean.has_signal("thunder"):world.ocean.thunder.emit(at)

static var _bolt_mat: StandardMaterial3D
func _bolt_mesh(seed_value: int) -> ArrayMesh:
	if _bolt_mat==null:
		_bolt_mat=StandardMaterial3D.new();_bolt_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;_bolt_mat.albedo_color=Color("eef3ff")
		_bolt_mat.emission_enabled=true;_bolt_mat.emission=Color("dfe8ff");_bolt_mat.emission_energy_multiplier=6.
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p:=Vector3(0,300,0)
	while p.y>0.:
		var q:=p+Vector3(rng.randf_range(-22.,22.),-rng.randf_range(18.,40.),rng.randf_range(-22.,22.));q.y=maxf(q.y,0.)
		var side:=(q-p).cross(Vector3(0,0,1)).normalized()*1.4
		for v: Vector3 in [p-side,p+side,q+side,p-side,q+side,q-side]:st.add_vertex(v)
		p=q
	st.set_material(_bolt_mat)
	return st.commit()
