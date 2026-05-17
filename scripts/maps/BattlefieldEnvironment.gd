extends WorldEnvironment

@export_group("Ambiance")
@export var fog_color: Color    = Color(0.58, 0.56, 0.50)
@export var fog_density: float  = 0.0022
@export var fog_sky_ratio: float = 0.38

@export_group("Éclairage")
@export var sun_energy: float   = 2.2
@export var sky_energy: float   = 1.0
@export var ambient_energy: float = 0.42

func _ready() -> void:
	add_to_group("world_environment")
	if Engine.is_editor_hint():
		return
	_configure_environment()
	_configure_sun()

func _configure_environment() -> void:
	if not environment:
		environment = Environment.new()
	var env := environment

	# Ciel HDRI — fallback procédural palette olive/orange si absent
	var sky := Sky.new()
	const HDRI_A := "res://assets/skies/DaySkyHDRI059A_4K_HDR.exr"
	const HDRI_B := "res://assets/skies/DaySkyHDRI063B_4K_HDR.exr"
	var hdri_path := HDRI_A if ResourceLoader.exists(HDRI_A) else (HDRI_B if ResourceLoader.exists(HDRI_B) else "")
	if hdri_path != "":
		var hdri_mat              := PanoramaSkyMaterial.new()
		hdri_mat.panorama          = load(hdri_path) as Texture2D
		hdri_mat.energy_multiplier = sky_energy
		sky.sky_material           = hdri_mat
	else:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color        = Color(0.14, 0.20, 0.32)
		sky_mat.sky_horizon_color    = Color(0.52, 0.46, 0.34)
		sky_mat.ground_bottom_color  = Color(0.05, 0.05, 0.04)
		sky_mat.ground_horizon_color = Color(0.28, 0.24, 0.18)
		sky_mat.sun_angle_max        = 28.0
		sky_mat.sun_curve            = 0.10
		sky.sky_material             = sky_mat
	env.sky                          = sky
	env.background_mode              = Environment.BG_SKY
	env.background_energy_multiplier = sky_energy

	# Tone mapping ACES — contraste cinématique, pousse les oranges/dorés
	env.tonemap_mode     = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.tonemap_white    = 6.5

	# Ambient — éclairage indirect du ciel
	env.ambient_light_source            = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy            = ambient_energy
	env.ambient_light_sky_contribution  = 0.72

	# SSAO — occlusion dans les coins de tranchées/murs
	env.ssao_enabled   = true
	env.ssao_radius    = 1.3
	env.ssao_intensity = 2.2
	env.ssao_power     = 1.6
	env.ssao_detail    = 0.5
	env.ssao_horizon   = 0.06
	env.ssao_sharpness = 0.98

	# SSIL — rebond de lumière solaire sur le terrain
	env.ssil_enabled   = true
	env.ssil_radius    = 5.5
	env.ssil_intensity = 0.9
	env.ssil_sharpness = 0.9

	# SSR — reflets sur mares et surfaces métalliques
	env.ssr_enabled         = true
	env.ssr_max_steps       = 56
	env.ssr_fade_in         = 0.14
	env.ssr_fade_out        = 2.0
	env.ssr_depth_tolerance = 0.22

	# SDFGI
	env.sdfgi_enabled       = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_energy        = 1.0
	env.sdfgi_normal_bias   = 1.1
	env.sdfgi_probe_bias    = 1.1

	# Glow — lumière volumétrique légère, éclats sur métal
	env.glow_enabled    = true
	env.glow_normalized = false
	env.glow_intensity  = 0.60
	env.glow_strength   = 1.0
	env.glow_bloom      = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Brume de champ de bataille (poussière, fumée légère)
	env.fog_enabled            = true
	env.fog_light_color        = fog_color
	env.fog_light_energy       = 1.0
	env.fog_density            = fog_density
	env.fog_sky_affect         = fog_sky_ratio
	env.fog_aerial_perspective = 0.15
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo  = Color(0.68, 0.66, 0.60)
	env.volumetric_fog_emission        = Color(0.08, 0.06, 0.03)
	env.volumetric_fog_emission_energy = 0.08
	env.volumetric_fog_length          = 64.0
	env.volumetric_fog_detail_spread   = 2.0

	# Color grading — warm olive lift, orange gain (cohérence avec UI)
	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast   = 1.10
	env.adjustment_saturation = 1.08

func _configure_sun() -> void:
	var sun := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not sun:
		return
	sun.light_energy              = sun_energy
	sun.light_color               = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled            = true
	sun.shadow_bias               = 0.025
	sun.directional_shadow_mode            = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1         = 0.08
	sun.directional_shadow_split_2         = 0.25
	sun.directional_shadow_split_3         = 0.55
	sun.directional_shadow_fade_start      = 0.84
	sun.directional_shadow_max_distance    = 200.0

	# Fill light depuis l'opposé — lumière de ciel froide/bleue
	var parent := get_parent()
	if not parent.get_node_or_null("FillLight"):
		var fill := DirectionalLight3D.new()
		fill.name             = "FillLight"
		fill.rotation_degrees = Vector3(-15, sun.rotation_degrees.y + 180.0, 0)
		fill.light_energy     = 0.22
		fill.light_color      = Color(0.58, 0.70, 0.90)
		fill.shadow_enabled   = false
		fill.light_specular   = 0.0
		parent.add_child(fill)
