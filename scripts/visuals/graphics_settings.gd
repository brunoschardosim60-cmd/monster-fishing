extends RefCounted
## Runtime quality changes; geometry, physics and progression remain the same.
const FILE: String="user://graphics.cfg"
var quality: int=2
var render_scale: float=1.
var vsync: bool=true
var game: Node3D
func configure(owner_game: Node3D) -> void:
	game=owner_game
	var config:=ConfigFile.new()
	if config.load(FILE)==OK:
		quality=clampi(int(config.get_value("graphics","quality",2)),0,3)
		render_scale=clampf(float(config.get_value("graphics","scale",1.)),.5,1.5)
		vsync=bool(config.get_value("graphics","vsync",true))
	apply(quality,render_scale,vsync,false)
func apply(level: int,scale_value: float,sync: bool,save: bool=true) -> void:
	quality=clampi(level,0,3);render_scale=clampf(scale_value,.5,1.5);vsync=sync
	var view:=game.get_viewport();var env: Environment=game.world.environment
	var forward:=RenderingServer.get_current_rendering_method()=="forward_plus"
	view.scaling_3d_scale=render_scale;view.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
	view.use_taa=forward and quality>=1
	env.ssao_enabled=forward and quality>=1;env.ssr_enabled=forward and quality>=1
	env.ssr_max_steps=[12,20,48,80][quality];env.ssil_enabled=forward and quality>=2
	env.glow_enabled=forward and quality>=1
	game.world.sun.shadow_enabled=quality>0;game.world.sun.directional_shadow_max_distance=[45.,90.,180.,300.][quality]
	game.world.sun.light_angular_distance=.6
	var distance: float=[85.,125.,220.,400.][quality]
	for node: GeometryInstance3D in game.get_tree().get_nodes_in_group("nature_near"):node.visibility_range_end=distance
	for node: GeometryInstance3D in game.get_tree().get_nodes_in_group("nature_far"):node.visibility_range_begin=distance
	for node: GeometryInstance3D in game.get_tree().get_nodes_in_group("nature_foliage"):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality>=2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node: GeometryInstance3D in game.get_tree().get_nodes_in_group("nature_shadow_proxy"):node.visible=quality<2
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if save:
		var config:=ConfigFile.new();config.set_value("graphics","quality",quality);config.set_value("graphics","scale",render_scale);config.set_value("graphics","vsync",vsync);config.save(FILE)
