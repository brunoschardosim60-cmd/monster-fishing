extends Node3D
const Waves=preload("res://scripts/world/wave_field.gd")
const Layout=preload("res://scripts/world/archipelago_layout.gd")
const Weather=preload("res://scripts/ocean/sea_weather.gd")
const Effects=preload("res://scripts/ocean/water_effects.gd")
const G=preload("res://scripts/world/geometry.gd")
signal thunder(at: Vector3)
var world: Node3D
var weather=Weather.new()
var effects: Node3D
var rain_particles: CPUParticles3D
var shore_points: Array[Vector3]=[]
var previous_heights: Array[float]=[]
var ice: Array[Node3D]=[]
var ice_footprints: Array[Vector3]=[]
var light_clock: float=0.
var flash_clock: float=20.
var flash_remaining: float=0.
var thunder_delay: float=-1.
var underwater: bool=false
var cold: float=0.
var strike_position:=Vector3.ZERO
var seabed: MeshInstance3D
var hour: float=16.6
var day_length_seconds: float=1800.
var daylight: float=1.
var cycle_enabled: bool=true
var moon: DirectionalLight3D

func _ready() -> void:
	process_physics_priority=-30
	Waves.reset()
	moon=DirectionalLight3D.new();moon.light_color=Color("7ca5d2");moon.light_energy=.14;add_child(moon)
	effects=Effects.new(); effects.name="WaterInteractions"; add_child(effects)
	_make_rain(); _make_seabed(); _make_ice()
	# Surf emitters sit on the same contour Layout.coast describes, so splashes follow the real beaches.
	for lobe: int in Waves.ISLANDS.size():
		var island: Vector4=Waves.ISLANDS[lobe]
		for i: int in 24:
			var angle:=float(i)*TAU/24.
			var edge:=Layout.edge_factor(lobe,angle)
			shore_points.append(Vector3(island.x+cos(angle)*island.z*edge,0,island.y+sin(angle)*island.w*edge))
			previous_heights.append(0.)
	for p: Vector3 in world.shore_rocks:
		shore_points.append(p); previous_heights.append(0.)

func _make_rain() -> void:
	rain_particles=CPUParticles3D.new()
	rain_particles.name="LocalRain"; rain_particles.emitting=false
	rain_particles.amount=1000 if RenderingServer.get_current_rendering_method()=="forward_plus" else 550
	rain_particles.lifetime=.85; rain_particles.local_coords=false
	rain_particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents=Vector3(14,1,14)
	rain_particles.direction=Vector3.DOWN; rain_particles.spread=3.
	rain_particles.initial_velocity_min=18.; rain_particles.initial_velocity_max=23.
	rain_particles.gravity=Vector3(2,-4,1)
	var mesh:=QuadMesh.new(); mesh.size=Vector2(.017,.52); mesh.material=Effects.drop_material()
	rain_particles.mesh=mesh; rain_particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_particles.material_override=mesh.material
	add_child(rain_particles)

func _make_seabed() -> void:
	var plane:=PlaneMesh.new(); plane.size=Vector2(640,640)
	plane.subdivide_width=200; plane.subdivide_depth=200
	var mat:=ShaderMaterial.new(); mat.shader=preload("res://assets/shaders/seabed.gdshader")
	mat.set_shader_parameter("sand_tex",load("res://assets/textures/sand_color.png"))
	mat.set_shader_parameter("noise_tex",load("res://assets/textures/foam_noise.png"))
	var floor_mesh:=G.mesh_node(self,plane,mat,Vector3.ZERO)
	seabed=floor_mesh
	floor_mesh.custom_aabb=AABB(Vector3(-320,-200,-320),Vector3(640,201,640))
	floor_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_ice() -> void:
	var seeds: Array[int]=[419,917,1213,1511]
	for i: int in Layout.ICE_FIELDS.size():
		var field:=Layout.ICE_FIELDS[i]
		_make_ice_field(Vector2(field.x,field.y),int(field.z),seeds[i%seeds.size()])

func _make_ice_field(center: Vector2,count: int,seed_value: int) -> void:
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("a1c9cf")
	mat.roughness=.28; mat.metallic=.12
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
	for i: int in count:
		var field_angle:=float(i)*TAU/float(count)+rng.randf_range(-.24,.24)
		var field_radius:=rng.randf_range(24.,92.)
		var at:=Vector3(center.x+cos(field_angle)*field_radius,0,center.y+sin(field_angle)*field_radius)
		if Waves.coast(Vector2(at.x,at.z)).x<2.: continue
		var floe:=Node3D.new(); add_child(floe); floe.position=at
		var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim:=PackedVector3Array(); var radius:=rng.randf_range(1.1,2.5)
		for j: int in 9:
			var angle:=float(j)/9.*TAU
			rim.append(Vector3(cos(angle)*radius*rng.randf_range(.8,1.2),rng.randf_range(.05,.22),sin(angle)*radius))
		for j: int in 9:
			var a:=rim[j]; var b:=rim[(j+1)%9]
			for v: Vector3 in [Vector3(0,.36,0),b,a,a,b,b-Vector3(0,.85,0),a,b-Vector3(0,.85,0),a-Vector3(0,.85,0)]: st.add_vertex(v)
		st.generate_normals(); G.mesh_node(floe,st.commit(),mat,Vector3.ZERO)
		var body:=StaticBody3D.new(); body.collision_layer=1; body.collision_mask=0
		var shape:=CollisionShape3D.new(); var cylinder:=CylinderShape3D.new(); cylinder.radius=radius*.85; cylinder.height=1.2
		shape.shape=cylinder; body.add_child(shape); add_child(body); body.position=at
		ice.append(floe)
		ice_footprints.append(Vector3(at.x,at.z,radius))

func is_ice(at: Vector3) -> bool:
	for item: Vector3 in ice_footprints:
		if Vector2(at.x-item.x,at.z-item.y).length()<item.z: return true
	return false

func _physics_process(delta: float) -> void:
	if cycle_enabled: hour=fposmod(hour+delta*24./day_length_seconds,24.)
	weather.advance(delta)
	Waves.advance(delta,weather.wind,weather.energy,weather.rain,Vector2.from_angle(weather.heading))
	Waves.bind(world.ocean_material)
	var camera:=get_viewport().get_camera_3d()
	if camera==null: return
	var p:=camera.global_position
	Waves.ocean_center=Vector2(snappedf(p.x,2.),snappedf(p.z,2.))
	world.water_root.position=Vector3(Waves.ocean_center.x,0,Waves.ocean_center.y)
	seabed.position=world.water_root.position
	Waves.bind(world.ocean_material)
	var active_region:=Layout.region_at(Vector2(p.x,p.z))
	var regional_cold:=1. if str(active_region.get("biome",""))=="frost" else 0.
	cold=maxf(regional_cold,1.-smoothstep(60.,300.,Vector2(p.x,p.z).distance_to(Layout.COLD_CENTER)))
	underwater=p.y<Waves.height_at(p)-.08
	rain_particles.global_position=p+Vector3(0,8,0)
	rain_particles.emitting=weather.rain>.03 and not underwater and not world.village.indoors(p)
	rain_particles.color=Color(1,1,1,weather.rain*.6)
	rain_particles.gravity=Vector3(Waves.direction.x*weather.wind*8.,-4,Waves.direction.y*weather.wind*8.)
	flash_clock-=delta; flash_remaining=maxf(0.,flash_remaining-delta)
	if flash_clock<0. and weather.rain>.72:
		flash_clock=19.+fposmod(Waves.time*1.73,13.)
		flash_remaining=.18; thunder_delay=1.3
		strike_position=p+Vector3(-160,100,-220)
	if thunder_delay>=0.:
		thunder_delay-=delta
		if thunder_delay<0.: thunder.emit(strike_position)
	_update_lighting(delta)
	for floe: Node3D in ice:
		var at:=floe.global_position
		floe.position.y=Waves.height_at(at)*.85
		floe.rotation.z=atan((Waves.height_at(at+Vector3.RIGHT)-Waves.height_at(at-Vector3.RIGHT))*.5)*.5
	# Shore emitters are culled before sampling and trigger on passing crests.
	for i: int in shore_points.size():
		var at:=shore_points[i]
		if at.distance_squared_to(p)>4900.: continue
		var c:=Waves.coast(Vector2(at.x,at.z))
		var incoming:=Waves.height_at(at+Vector3(c.y,0,c.z)*5.)
		if incoming>.18 and previous_heights[i]<=.18 and weather.energy>.2:
			effects.splash(at,.45+weather.energy*.9,true)
		previous_heights[i]=incoming

func _update_lighting(delta: float) -> void:
	light_clock+=delta
	var flash:=flash_remaining/.18
	var angle: float=(hour-6.)/24.*TAU
	var elevation:=sin(angle)
	daylight=smoothstep(-.16,.22,elevation)
	world.sun.rotation=Vector3(-asin(elevation),angle*.6+1.3,0)
	world.sun.light_energy=daylight*lerpf(1.65,.23,weather.cloud)+flash*3.
	world.sun.light_color=Color("ffbd80").lerp(Color("fff0ce"),smoothstep(.12,.6,elevation)).lerp(Color("a9bfd2"),weather.cloud*.85)
	moon.rotation=Vector3(-asin(-elevation),angle*.6+1.3+PI,0);moon.light_energy=(1.-daylight)*.42*(1.-weather.cloud*.55)
	world.sky_material.set_shader_parameter("sun_direction",world.sun.global_basis.z.normalized())
	world.sky_material.set_shader_parameter("moon_direction",moon.global_basis.z.normalized())
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("8197b5").lerp(Color("c3d6e2"),daylight)
	world.environment.ambient_light_sky_contribution=lerpf(.2,.85,daylight)
	world.environment.ambient_light_energy=lerpf(.48,.55,daylight)
	world.environment.fog_density=.055 if underwater else weather.fog+cold*.012
	world.environment.fog_light_color=Color("0a5460") if underwater else Color("182d43").lerp(Color("a8bfcf").lerp(Color("6f8290"),weather.cloud),daylight)
	world.environment.fog_sky_affect=1. if underwater else .04+weather.rain*.45
	world.environment.tonemap_exposure=.72 if underwater else 1.02
	if world.ocean_material!=null:
		var ocean_mat: ShaderMaterial=world.ocean_material
		ocean_mat.set_shader_parameter("sea_glow",.04*daylight*(1.-weather.cloud*.55))
		# The water reflects the same sky the sky shader draws: pale horizon, deeper zenith,
		# warm at sunrise/sunset, dark blue at night, grey under cloud.
		var low_sun:=1.-smoothstep(.05,.35,elevation)
		var horizon:=Color(.012,.025,.05).lerp(Color(.45,.62,.75).lerp(Color(1.,.55,.3),low_sun*.7),daylight)
		var zenith:=Color(.004,.01,.03).lerp(Color(.03,.14,.38).lerp(Color(.22,.2,.36),low_sun*.5),daylight)
		horizon=horizon.lerp(Color(.42,.47,.52)*maxf(daylight,.08),weather.cloud*.8)
		zenith=zenith.lerp(Color(.30,.34,.40)*maxf(daylight,.08),weather.cloud*.8)
		ocean_mat.set_shader_parameter("sky_horizon",Vector3(horizon.r,horizon.g,horizon.b))
		ocean_mat.set_shader_parameter("sky_zenith",Vector3(zenith.r,zenith.g,zenith.b))
		var sun_light: DirectionalLight3D=world.sun
		var moon_up:=1.-daylight
		ocean_mat.set_shader_parameter("sun_dir",sun_light.global_basis.z.normalized() if daylight>.02 else moon.global_basis.z.normalized())
		var glint_color:=sun_light.light_color if daylight>.02 else Color(.55,.68,.85)
		ocean_mat.set_shader_parameter("sun_color",Vector3(glint_color.r,glint_color.g,glint_color.b))
		ocean_mat.set_shader_parameter("sun_strength",daylight*(1.-weather.cloud*.9)+moon_up*.25*(1.-weather.cloud))
	world.sky_material.set_shader_parameter("lightning",flash)
	if light_clock>.35:
		light_clock=0.
		world.sky_material.set_shader_parameter("cloud_cover",weather.cloud)
		world.sky_material.set_shader_parameter("weather_time",Waves.time)
		var caustics: float=daylight*(1.-weather.cloud*.75)
		var floor_mat:=seabed.get_active_material(0) as ShaderMaterial
		if floor_mat!=null:floor_mat.set_shader_parameter("caustic_strength",caustics)
		for mat: ShaderMaterial in world.terrain_materials:
			mat.set_shader_parameter("sea_time",Waves.time)
			mat.set_shader_parameter("caustic_strength",caustics)
			mat.set_shader_parameter("wet_weather",weather.rain)
