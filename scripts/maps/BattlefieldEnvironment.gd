extends WorldEnvironment

# Attache ce script sur ton nœud WorldEnvironment dans la map.
# Il configure SDFGI + SSAO + Bloom + Fog + Tone mapping automatiquement.

@export_group("Ambiance")
@export var time_of_day: float = 12.0   # 0-24h
@export var fog_color: Color = Color(0.62, 0.65, 0.60)
@export var fog_density: float = 0.003
@export var fog_sky_ratio: float = 0.4

@export_group("Éclairage")
@export var sun_energy: float = 2.2
@export var sky_energy: float = 1.0
@export var ambient_energy: float = 0.4

func _ready() -> void:
	add_to_group("world_environment")
	if Engine.is_editor_hint():
		return
	_configure_environment()

func _configure_environment() -> void:
	if not environment:
		environment = Environment.new()
	var env := environment

	# Ciel HDRI (fallback procédural si le fichier manque)
	var sky := Sky.new()
	const HDRI_PATH := "res://assets/skies/DaySkyHDRI059A_4K_HDR.exr"
	if ResourceLoader.exists(HDRI_PATH):
		var hdri_mat         := PanoramaSkyMaterial.new()
		hdri_mat.panorama     = load(HDRI_PATH) as Texture2D
		hdri_mat.energy_multiplier = sky_energy
		sky.sky_material     = hdri_mat
	else:
		var sky_mat          := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color     = Color(0.18, 0.26, 0.42)
		sky_mat.sky_horizon_color = Color(0.58, 0.52, 0.42)
		sky_mat.ground_bottom_color   = Color(0.06, 0.06, 0.06)
		sky_mat.ground_horizon_color  = Color(0.32, 0.28, 0.22)
		sky_mat.sun_angle_max  = 30.0
		sky_mat.sun_curve      = 0.12
		sky.sky_material = sky_mat
	env.sky         = sky
	env.background_mode              = Environment.BG_SKY
	env.background_energy_multiplier = sky_energy

	# Tone mapping ACES
	env.tonemap_mode      = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure  = 1.05
	env.tonemap_white     = 6.0

	# Ambient
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	env.ambient_light_sky_contribution = 0.7

	# SSAO
	env.ssao_enabled    = true
	env.ssao_radius     = 1.2
	env.ssao_intensity  = 2.0
	env.ssao_power      = 1.5
	env.ssao_detail     = 0.5
	env.ssao_horizon    = 0.06
	env.ssao_sharpness  = 0.98

	# SSIL
	env.ssil_enabled    = true
	env.ssil_radius     = 5.0
	env.ssil_intensity  = 0.8
	env.ssil_sharpness  = 0.9

	# Screen Space Reflections
	env.ssr_enabled         = true
	env.ssr_max_steps       = 64
	env.ssr_fade_in         = 0.15
	env.ssr_fade_out        = 2.0
	env.ssr_depth_tolerance = 0.2

	# SDFGI (GI globale)
	env.sdfgi_enabled       = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy        = 1.0
	env.sdfgi_normal_bias   = 1.1
	env.sdfgi_probe_bias    = 1.1

	# Bloom (Glow)
	env.glow_enabled    = true
	env.glow_normalized = false
	env.glow_intensity  = 0.65
	env.glow_strength   = 1.0
	env.glow_bloom      = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Fog — fog_depth_begin/end n'existe pas en Godot 4 (supprimé)
	env.fog_enabled      = true
	env.fog_light_color  = fog_color
	env.fog_light_energy = 1.0
	env.fog_density      = fog_density
	env.fog_sky_affect   = fog_sky_ratio
	env.volumetric_fog_enabled  = true
	env.volumetric_fog_density  = 0.02
	env.volumetric_fog_albedo   = Color(0.7, 0.72, 0.68)
	env.volumetric_fog_length   = 64.0
	env.volumetric_fog_detail_spread  = 2.0
	env.set("volumetric_fog_gi_inject",      1.0)
	env.set("volumetric_fog_ambient_inject", 0.5)

	# Adjustement des couleurs
	env.adjustment_enabled     = true
	env.adjustment_brightness  = 0.98
	env.adjustment_contrast    = 1.08
	env.adjustment_saturation  = 1.06
