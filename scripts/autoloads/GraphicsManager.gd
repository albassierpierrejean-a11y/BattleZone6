extends Node

enum Preset { MINIMUM, LOW, MEDIUM, HIGH, ULTRA }

const PRESETS := {
	Preset.MINIMUM: {
		"shadow_size": 0, "shadow_distance": 40.0, "shadow_filter": 0,
		"sdfgi": false, "ssao": false, "ssil": false, "ssr": false,
		"aa": 0, "render_scale": 0.75, "bloom": false, "fog": false,
		"msaa": 0
	},
	Preset.LOW: {
		"shadow_size": 1024, "shadow_distance": 80.0, "shadow_filter": 0,
		"sdfgi": false, "ssao": false, "ssil": false, "ssr": false,
		"aa": 1, "render_scale": 0.85, "bloom": false, "fog": false,
		"msaa": 0
	},
	Preset.MEDIUM: {
		"shadow_size": 2048, "shadow_distance": 120.0, "shadow_filter": 1,
		"sdfgi": false, "ssao": true, "ssil": false, "ssr": false,
		"aa": 1, "render_scale": 1.0, "bloom": true, "fog": true,
		"msaa": 2
	},
	Preset.HIGH: {
		"shadow_size": 4096, "shadow_distance": 200.0, "shadow_filter": 2,
		"sdfgi": true, "ssao": true, "ssil": true, "ssr": false,
		"aa": 2, "render_scale": 1.0, "bloom": true, "fog": true,
		"msaa": 4
	},
	Preset.ULTRA: {
		"shadow_size": 4096, "shadow_distance": 300.0, "shadow_filter": 2,
		"sdfgi": true, "ssao": true, "ssil": true, "ssr": true,
		"aa": 3, "render_scale": 1.0, "bloom": true, "fog": true,
		"msaa": 8
	},
}

var current_preset: int = Preset.HIGH
var fov: float = 75.0
var vsync: bool = true
var max_fps: int = 0

func _ready() -> void:
	apply_preset(Preset.HIGH)

func apply_preset(preset: int) -> void:
	current_preset = preset
	var cfg: Dictionary = PRESETS.get(preset, PRESETS[Preset.HIGH])
	var env := _get_env()
	if not env:
		return

	# Ombres
	set_shadow_size(cfg["shadow_size"])
	set_shadow_distance(cfg["shadow_distance"])
	RenderingServer.directional_shadow_atlas_set_size(cfg["shadow_size"], true)

	# SSAO / SSIL / SSR
	env.ssao_enabled = cfg["ssao"]
	env.ssil_enabled = cfg["ssil"]
	env.ssr_enabled  = cfg["ssr"]

	# SDFGI
	env.sdfgi_enabled = cfg["sdfgi"]
	if cfg["sdfgi"]:
		env.sdfgi_use_occlusion = true
		env.sdfgi_min_cell_size  = 0.2

	# Bloom
	env.glow_enabled = cfg["bloom"]

	# Fog
	env.fog_enabled = cfg["fog"]

	# MSAA
	var vp := get_viewport()
	if vp:
		match cfg["msaa"]:
			0: vp.msaa_3d = Viewport.MSAA_DISABLED
			2: vp.msaa_3d = Viewport.MSAA_2X
			4: vp.msaa_3d = Viewport.MSAA_4X
			8: vp.msaa_3d = Viewport.MSAA_8X

	# Render scale (FSR2 si dispo)
	if vp:
		vp.scaling_3d_scale = cfg["render_scale"]

func set_shadow_size(size: int) -> void:
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", size)

func set_shadow_distance(dist: float) -> void:
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/max_distance", dist)

func set_fov(value: float) -> void:
	fov = value
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		cam.fov = value

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)

func set_max_fps(fps: int) -> void:
	max_fps = fps
	Engine.max_fps = fps

func set_render_scale(scale: float) -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(scale, 0.5, 1.5)

func _get_env() -> Environment:
	var we := get_tree().get_first_node_in_group("world_environment")
	if we and we is WorldEnvironment:
		return (we as WorldEnvironment).environment
	return null
