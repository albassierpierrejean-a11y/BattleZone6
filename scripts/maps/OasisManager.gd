extends "res://scripts/maps/MapManager.gd"
class_name OasisManager

# ─── Texture paths ────────────────────────────────────────────────────────────
const GRASS_C  := "res://assets/textures/Grass001_2K-PNG/Grass001_2K-PNG_Color.png"
const GRASS_N  := "res://assets/textures/Grass001_2K-PNG/Grass001_2K-PNG_NormalGL.png"
const GRASS_R  := "res://assets/textures/Grass001_2K-PNG/Grass001_2K-PNG_Roughness.png"
const GRASS_AO := "res://assets/textures/Grass001_2K-PNG/Grass001_2K-PNG_AmbientOcclusion.png"

const ROCK_C   := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Color.png"
const ROCK_N   := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_NormalGL.png"
const ROCK_R   := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Roughness.png"
const ROCK_AO  := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_AmbientOcclusion.png"

const SAND_C   := "res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Color.jpg"
const SAND_N   := "res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_NormalGL.jpg"
const SAND_R   := "res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Roughness.jpg"
const SAND_AO  := "res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_AmbientOcclusion.jpg"

const PAVE_C   := "res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_Color.png"
const PAVE_N   := "res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_NormalGL.png"
const PAVE_R   := "res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_Roughness.png"
const PAVE_AO  := "res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_AmbientOcclusion.png"

const HDRI_SKY  := "res://assets/skies/DaySkyHDRI063B_4K_HDR.exr"
const HDRI_SKY2 := "res://assets/skies/DaySkyHDRI059A_4K_HDR.exr"
const HEAT_HAZE_SHADER := "res://assets/shaders/heat_haze.gdshader"
const AK74_GLB := "res://assets/models/weapons/ak74m.glb"

# ─── Override parent visuals entirely ────────────────────────────────────────
func _setup_visuals() -> void:
	_setup_hdri_sky()
	_setup_ground_layers()
	_build_rock_formations()
	_build_ruins()
	_build_oasis_pool()
	_build_palm_trees()
	_build_paths()
	_build_boundary_walls()
	_build_heat_haze()

# ─── HDRI panorama sky + environnement complet ───────────────────────────────
func _setup_hdri_sky() -> void:
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not world_env:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky     := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	var hdri_path := HDRI_SKY if ResourceLoader.exists(HDRI_SKY) else HDRI_SKY2
	if ResourceLoader.exists(hdri_path):
		sky_mat.panorama = load(hdri_path) as Texture2D
	sky_mat.energy_multiplier = 1.0
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source        = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy        = 0.72
	env.ambient_light_sky_contribution = 0.75
	env.reflected_light_source      = Environment.REFLECTION_SOURCE_SKY

	# Tonemapping ACES — plus dramatique, pousse les oranges
	env.tonemap_mode     = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	env.tonemap_white    = 7.0

	# Glow — éclats légers sur métal/eau
	env.glow_enabled    = true
	env.glow_normalized = false
	env.glow_intensity  = 0.55
	env.glow_strength   = 1.0
	env.glow_bloom      = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# SSAO — occlusion ambiante forte dans les recoins de sable
	env.ssao_enabled   = true
	env.ssao_radius    = 1.4
	env.ssao_intensity = 2.4
	env.ssao_power     = 1.6
	env.ssao_detail    = 0.5
	env.ssao_horizon   = 0.06
	env.ssao_sharpness = 0.98

	# SSIL — rebond de lumière chaude sur le sable
	env.ssil_enabled   = true
	env.ssil_radius    = 6.0
	env.ssil_intensity = 1.1
	env.ssil_sharpness = 0.88

	# SSR — reflets sur l'eau de l'oasis
	env.ssr_enabled         = true
	env.ssr_max_steps       = 48
	env.ssr_fade_in         = 0.12
	env.ssr_fade_out        = 2.0
	env.ssr_depth_tolerance = 0.25

	# SDFGI — disabled: causes black screen on Metal (Apple Silicon)
	env.sdfgi_enabled = false

	# Brume désertique chaude
	env.fog_enabled            = true
	env.fog_light_color        = Color(0.96, 0.84, 0.60)
	env.fog_light_energy       = 1.0
	env.fog_density            = 0.0016
	env.fog_aerial_perspective = 0.22
	env.fog_sky_affect         = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo  = Color(0.94, 0.82, 0.58)
	env.volumetric_fog_emission        = Color(0.20, 0.13, 0.04)
	env.volumetric_fog_emission_energy = 0.15
	env.volumetric_fog_length          = 80.0
	env.volumetric_fog_detail_spread   = 2.0

	# Color grading — palette olive/orange (lift chaud, gain orange, gamma légèrement dégradé)
	env.adjustment_enabled    = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast   = 1.10
	env.adjustment_saturation = 1.14

	world_env.environment = env

	# Soleil principal — angle bas, lumière dorée intense
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.rotation_degrees    = Vector3(-32, 42, 0)
		sun.light_energy        = 1.6
		sun.light_color         = Color(1.0, 0.91, 0.72)
		sun.shadow_enabled      = true
		sun.shadow_bias         = 0.03
		sun.directional_shadow_mode            = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_split_1         = 0.1
		sun.directional_shadow_split_2         = 0.28
		sun.directional_shadow_split_3         = 0.55
		sun.directional_shadow_fade_start      = 0.82
		sun.directional_shadow_max_distance    = 180.0

	# Fill light — lumière de rebond de ciel bleu-froid depuis l'opposé
	if not get_node_or_null("FillLight"):
		var fill := DirectionalLight3D.new()
		fill.name                = "FillLight"
		fill.rotation_degrees    = Vector3(-18, -148, 0)
		fill.light_energy        = 0.28
		fill.light_color         = Color(0.62, 0.74, 0.92)
		fill.shadow_enabled      = false
		fill.light_specular      = 0.0
		add_child.call_deferred(fill)

# ─── Ground: sand base + grass patches + paving paths ────────────────────────
func _setup_ground_layers() -> void:
	var ground_mesh := get_node_or_null("Ground/GroundMesh") as MeshInstance3D
	if ground_mesh:
		var mesh   := PlaneMesh.new()
		mesh.size  = Vector2(300.0, 300.0)
		mesh.subdivide_width  = 12
		mesh.subdivide_depth  = 12
		ground_mesh.mesh = mesh
		ground_mesh.material_override = _make_pbr_material(SAND_C, SAND_N, SAND_R, SAND_AO, 80.0)

	# Zones d'herbe (dispersées autour du centre de la carte)
	var grass_positions: Array[Vector3] = [
		Vector3(-15, 0.01, -20), Vector3(18, 0.01, 12),
		Vector3(-30, 0.01,  5), Vector3( 5, 0.01, -35),
		Vector3( 35, 0.01, 22), Vector3(-45, 0.01, -10),
		Vector3( 10, 0.01,  40), Vector3(-20, 0.01, 30),
	]
	var patch_sizes: Array[Vector2] = [
		Vector2(12, 14), Vector2(16, 10), Vector2(9, 15), Vector2(14, 11),
		Vector2(11, 13), Vector2(10, 16), Vector2(15, 9),  Vector2(13, 12),
	]
	for i in grass_positions.size():
		var mi := MeshInstance3D.new()
		mi.name = "GrassPatch_%d" % i
		mi.position = grass_positions[i]
		var pm := PlaneMesh.new()
		pm.size = patch_sizes[i]
		mi.mesh = pm
		mi.material_override = _make_pbr_material(GRASS_C, GRASS_N, GRASS_R, GRASS_AO, 6.0)
		add_child(mi)

# ─── Paving stone paths between flags ────────────────────────────────────────
func _build_paths() -> void:
	# Horizontal axis path (Alpha → Mid → Bravo)
	var path_segs: Array = [
		[Vector3(-55, 0.01,  0), Vector3(14.0,  0.08, 4.0)],
		[Vector3( 20, 0.01,  0), Vector3(90.0,  0.08, 4.0)],
		# North diagonal
		[Vector3(-20, 0.01,-30), Vector3( 4.0,  0.08, 55.0)],
		# South diagonal
		[Vector3( 20, 0.01, 30), Vector3( 4.0,  0.08, 55.0)],
	]
	for i in path_segs.size():
		var pos: Vector3  = path_segs[i][0]
		var sz: Vector3   = path_segs[i][1]
		var path := StaticBody3D.new()
		path.name = "Path_%d" % i
		path.position = pos
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = _make_pbr_material(PAVE_C, PAVE_N, PAVE_R, PAVE_AO, sz.x * 0.6)
		path.add_child(mi)
		var col := CollisionShape3D.new()
		var csh := BoxShape3D.new()
		csh.size = sz
		col.shape = csh
		path.add_child(col)
		add_child(path)

# ─── Rock formations ──────────────────────────────────────────────────────────
func _build_rock_formations() -> void:
	var clusters: Array = [
		# [center, Array of [offset, size, rot_y]]
		[Vector3(-50,  0, -35), [
			[Vector3(0, 2.2, 0),   Vector3(5.0, 4.4, 4.2), 0.3],
			[Vector3(3, 1.0, 1.5), Vector3(3.2, 2.0, 2.8), 0.9],
			[Vector3(-2.5, 0.7,-1.5), Vector3(2.8, 1.4, 3.2), -0.4],
			[Vector3(1.5, 0.5, -2.8), Vector3(4.0, 1.0, 2.0), 0.7],
		]],
		[Vector3( 50,  0,  35), [
			[Vector3(0, 2.0, 0),    Vector3(4.5, 4.0, 5.0), -0.5],
			[Vector3(-3, 0.8, 2),   Vector3(3.0, 1.6, 2.5), 1.1],
			[Vector3(2.5, 1.0,-2),  Vector3(2.5, 2.0, 3.0), 0.2],
			[Vector3(-1, 0.5, 3.2), Vector3(3.5, 1.0, 1.8), -0.8],
		]],
		[Vector3(-55,  0,  40), [
			[Vector3(0, 1.8, 0),    Vector3(6.0, 3.6, 4.0), 0.1],
			[Vector3(3.5, 0.9, 1.5), Vector3(3.0, 1.8, 2.5), 0.6],
			[Vector3(-3, 0.6, -2),  Vector3(2.5, 1.2, 3.8), -0.3],
		]],
		[Vector3( 55,  0, -40), [
			[Vector3(0, 1.6, 0),    Vector3(5.5, 3.2, 4.5), -0.2],
			[Vector3(-2.5, 0.7, 2), Vector3(2.8, 1.4, 2.2), 0.8],
			[Vector3(3, 0.5, -1.5), Vector3(3.5, 1.0, 2.8), -0.5],
		]],
		# Flanking rocks mid-north
		[Vector3(  0,  0, -65), [
			[Vector3(0, 2.5, 0),    Vector3(8.0, 5.0, 6.0), 0.0],
			[Vector3(4.5, 1.2, 2),  Vector3(4.0, 2.4, 3.5), 0.4],
			[Vector3(-4, 0.9,-2.5), Vector3(3.5, 1.8, 4.0), -0.3],
			[Vector3(2, 0.6, -4),   Vector3(4.5, 1.2, 2.5), 0.6],
		]],
		[Vector3(  0,  0,  65), [
			[Vector3(0, 2.5, 0),    Vector3(7.5, 5.0, 5.5), 0.2],
			[Vector3(-4, 1.0, 1.5), Vector3(3.8, 2.0, 3.2), -0.6],
			[Vector3(3.5, 0.8,-2),  Vector3(3.2, 1.6, 4.0), 0.5],
		]],
		# Spawn-side boulders
		[Vector3(-90,  0, -15), [
			[Vector3(0, 1.2, 0),    Vector3(4.0, 2.4, 3.5), 0.3],
			[Vector3(3, 0.6, 1),    Vector3(2.5, 1.2, 2.0), -0.2],
		]],
		[Vector3( 90,  0,  15), [
			[Vector3(0, 1.2, 0),    Vector3(4.0, 2.4, 3.5), -0.4],
			[Vector3(-2.5, 0.5,-1), Vector3(2.5, 1.0, 2.2), 0.3],
		]],
	]

	var idx := 0
	for cluster in clusters:
		var center: Vector3 = cluster[0]
		var rocks: Array    = cluster[1]
		for j in rocks.size():
			var r_data: Array = rocks[j]
			var offset: Vector3 = r_data[0]
			var size: Vector3   = r_data[1]
			var rot_y: float    = r_data[2]

			var body := StaticBody3D.new()
			body.name = "Rock_%d_%d" % [idx, j]
			body.position = center + offset

			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
			mi.rotation.y = rot_y
			mi.material_override = _make_pbr_material(ROCK_C, ROCK_N, ROCK_R, ROCK_AO, size.x * 0.5)
			body.add_child(mi)

			var col := CollisionShape3D.new()
			var csh := BoxShape3D.new()
			csh.size = size
			col.shape = csh
			body.add_child(col)
			add_child(body)
		idx += 1

# ─── Ruined structures: broken walls + bunkers ────────────────────────────────
func _build_ruins() -> void:
	# [position, size, rot_y]
	var walls: Array = [
		# Mid area ruins around Flag B (-30,0,-45)
		[Vector3(-30,  2.5, -50), Vector3(0.8, 5.0, 10.0), 0.0],
		[Vector3(-36,  2.5, -42), Vector3(10.0, 5.0, 0.8), 0.0],
		[Vector3(-25,  1.5, -45), Vector3(0.8, 3.0,  6.0), 0.15],
		# Mid area ruins around Flag D (30,0,45)
		[Vector3( 30,  2.5,  50), Vector3(0.8, 5.0, 10.0), 0.0],
		[Vector3( 36,  2.5,  42), Vector3(10.0, 5.0, 0.8), 0.0],
		[Vector3( 25,  1.5,  45), Vector3(0.8, 3.0,  6.0), -0.15],
		# Central crossroads bunkers
		[Vector3(-12,  1.5,   0), Vector3(0.8, 3.0,  8.0), 0.0],
		[Vector3( 12,  1.5,   0), Vector3(0.8, 3.0,  8.0), 0.0],
		[Vector3(  0,  1.5, -12), Vector3(8.0, 3.0,  0.8), 0.0],
		[Vector3(  0,  1.5,  12), Vector3(8.0, 3.0,  0.8), 0.0],
		# Alpha side fortification walls
		[Vector3(-68,  2.0,  -8), Vector3(0.8, 4.0, 18.0), 0.0],
		[Vector3(-68,  2.0,   8), Vector3(0.8, 4.0,  8.0), 0.0],
		# Bravo side fortification walls
		[Vector3( 68,  2.0,   8), Vector3(0.8, 4.0, 18.0), 0.0],
		[Vector3( 68,  2.0,  -8), Vector3(0.8, 4.0,  8.0), 0.0],
	]

	var rock_mat := _make_pbr_material(ROCK_C, ROCK_N, ROCK_R, ROCK_AO, 3.0)
	for i in walls.size():
		var pos: Vector3  = walls[i][0]
		var sz: Vector3   = walls[i][1]
		var rot: float    = walls[i][2]

		var body := StaticBody3D.new()
		body.name = "Ruin_%d" % i
		body.position = pos
		body.rotation.y = rot

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = rock_mat
		body.add_child(mi)

		var col := CollisionShape3D.new()
		var csh := BoxShape3D.new()
		csh.size = sz
		col.shape = csh
		body.add_child(col)
		add_child(body)

# ─── Central oasis pool ───────────────────────────────────────────────────────
func _build_oasis_pool() -> void:
	# Surrounding stone rim
	var rim := StaticBody3D.new()
	rim.name = "OasisRim"
	rim.position = Vector3(0, 0, 0)
	var rim_mi := MeshInstance3D.new()
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius    = 9.5
	rim_cyl.bottom_radius = 9.5
	rim_cyl.height        = 0.35
	rim_cyl.rings         = 1
	rim_mi.mesh = rim_cyl
	rim_mi.material_override = _make_pbr_material(PAVE_C, PAVE_N, PAVE_R, PAVE_AO, 4.0)
	rim.add_child(rim_mi)
	var rim_col := CollisionShape3D.new()
	var rim_csh := CylinderShape3D.new()
	rim_csh.radius = 9.5
	rim_csh.height = 0.35
	rim_col.shape = rim_csh
	rim.add_child(rim_col)
	add_child(rim)

	# Surface de l'eau — shader animé avec ondulations UV
	var water := MeshInstance3D.new()
	water.name = "OasisWater"
	water.position = Vector3(0, 0.18, 0)
	var w_disk := CylinderMesh.new()
	w_disk.top_radius    = 8.8
	w_disk.bottom_radius = 8.8
	w_disk.height        = 0.06
	w_disk.rings         = 8
	water.mesh = w_disk
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform vec4 water_color : source_color = vec4(0.07, 0.26, 0.52, 0.84);
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
uniform float wave_scale : hint_range(0.1, 5.0) = 1.8;

void fragment() {
	vec2 uv1 = UV * wave_scale + vec2(TIME * speed * 0.7, TIME * speed * 0.5);
	vec2 uv2 = UV * wave_scale * 1.4 + vec2(-TIME * speed * 0.4, TIME * speed * 0.8);
	float wave = sin(uv1.x * 6.28 + uv1.y * 4.0) * 0.5
			   + sin(uv2.x * 5.0 - uv2.y * 7.0) * 0.5;
	wave = wave * 0.5 + 0.5;
	vec3 col = mix(water_color.rgb * 0.7, water_color.rgb * 1.15, wave);
	ALBEDO = col;
	ALPHA  = water_color.a;
	ROUGHNESS = roughness;
	METALLIC  = 0.04;
	SPECULAR  = 0.85;
	NORMAL    = normalize(vec3((wave - 0.5) * 0.18, 1.0, (wave - 0.5) * 0.14));
}
"""
	var w_mat := ShaderMaterial.new()
	w_mat.shader = water_shader
	water.material_override = w_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	# Fond de pierre peu profond sous l'eau
	var bed := StaticBody3D.new()
	bed.name = "OasisBed"
	bed.position = Vector3(0, -0.05, 0)
	var bed_mi := MeshInstance3D.new()
	var bd_cyl := CylinderMesh.new()
	bd_cyl.top_radius    = 8.8
	bd_cyl.bottom_radius = 8.8
	bd_cyl.height        = 0.12
	bd_cyl.rings         = 1
	bed_mi.mesh = bd_cyl
	bed_mi.material_override = _make_pbr_material(PAVE_C, PAVE_N, PAVE_R, PAVE_AO, 5.0)
	bed.add_child(bed_mi)
	var bed_col := CollisionShape3D.new()
	var bed_csh := CylinderShape3D.new()
	bed_csh.radius = 8.8
	bed_csh.height = 0.12
	bed_col.shape = bed_csh
	bed.add_child(bed_col)
	add_child(bed)

# ─── Palm trees around the oasis ─────────────────────────────────────────────
func _build_palm_trees() -> void:
	# [position, trunk_height, canopy_radius]
	var trees: Array = [
		[Vector3(-10.5, 0, -5.0), 5.5, 2.8],
		[Vector3(-10.5, 0,  5.0), 6.0, 3.0],
		[Vector3( 10.5, 0, -5.0), 5.8, 2.9],
		[Vector3( 10.5, 0,  5.0), 5.5, 2.7],
		[Vector3( -5.0, 0, 10.5), 6.5, 3.2],
		[Vector3(  5.0, 0, 10.5), 6.2, 3.0],
		[Vector3( -5.0, 0,-10.5), 5.8, 2.8],
		[Vector3(  5.0, 0,-10.5), 6.0, 3.1],
		# A few scattered ones near Flag B and Flag D ruins
		[Vector3(-28, 0, -52), 5.0, 2.5],
		[Vector3(-34, 0, -38), 5.5, 2.6],
		[Vector3( 28, 0,  52), 5.0, 2.5],
		[Vector3( 34, 0,  38), 5.5, 2.6],
	]

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.38, 0.26, 0.14)
	trunk_mat.roughness    = 0.85

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.12, 0.42, 0.10)
	canopy_mat.roughness    = 0.78

	for i in trees.size():
		var pos: Vector3      = trees[i][0]
		var h: float          = trees[i][1]
		var cr: float         = trees[i][2]

		var tree_root := Node3D.new()
		tree_root.name = "PalmTree_%d" % i
		tree_root.position = pos

		# Trunk
		var trunk_mi  := MeshInstance3D.new()
		var trunk_cyl := CylinderMesh.new()
		trunk_cyl.top_radius    = 0.14
		trunk_cyl.bottom_radius = 0.22
		trunk_cyl.height        = h
		trunk_mi.mesh = trunk_cyl
		trunk_mi.position.y = h * 0.5
		trunk_mi.material_override = trunk_mat
		tree_root.add_child(trunk_mi)

		# Canopy
		var canopy_mi  := MeshInstance3D.new()
		var canopy_sph := SphereMesh.new()
		canopy_sph.radius = cr
		canopy_sph.height = cr * 1.2
		canopy_mi.mesh = canopy_sph
		canopy_mi.position.y = h + cr * 0.6
		canopy_mi.material_override = canopy_mat
		tree_root.add_child(canopy_mi)

		add_child(tree_root)

# ─── Override props: larger map = more props ──────────────────────────────────
func _spawn_map_props() -> void:
	_spawn_barrels_oasis()
	_spawn_crates_oasis()
	_spawn_sandbags_oasis()
	_spawn_weapon_props()
	_spawn_health_pickups_oasis()
	_spawn_ammo_pickups_oasis()
	_spawn_vehicles_oasis()
	_spawn_ambient_lights_oasis()

func _spawn_barrels_oasis() -> void:
	var positions: Array[Vector3] = [
		# Near ruins around Flag B (-30,0,-45)
		Vector3(-28, 0.38, -52), Vector3(-32, 0.38, -48), Vector3(-26, 0.38, -42),
		# Near ruins around Flag D (30,0,45)
		Vector3( 28, 0.38,  52), Vector3( 32, 0.38,  48), Vector3( 26, 0.38,  42),
		# Crossroads bunkers
		Vector3(-14, 0.38,  3),  Vector3(-14, 0.38, -3),
		Vector3( 14, 0.38,  3),  Vector3( 14, 0.38, -3),
		# Alpha fortification
		Vector3(-72, 0.38,  5), Vector3(-72, 0.38, -5),
		Vector3(-65, 0.38, 12), Vector3(-65, 0.38,-12),
		# Bravo fortification
		Vector3( 72, 0.38, -5), Vector3( 72, 0.38,  5),
		Vector3( 65, 0.38,-12), Vector3( 65, 0.38, 12),
		# Mid-map flanks
		Vector3(-45, 0.38, 25), Vector3(-45, 0.38,-25),
		Vector3( 45, 0.38, 25), Vector3( 45, 0.38,-25),
	]
	for i in positions.size():
		var b := _make_barrel(positions[i])
		b.name = "Barrel_%d" % i
		add_child(b)

func _spawn_crates_oasis() -> void:
	var stacks: Array = [
		[Vector3(-30, 0, -38), 2], [Vector3( 30, 0,  38), 2],
		[Vector3(-10, 0,  15), 1], [Vector3( 10, 0, -15), 1],
		[Vector3(-55, 0,  15), 2], [Vector3( 55, 0, -15), 2],
		[Vector3(-80, 0,   5), 1], [Vector3( 80, 0,  -5), 1],
		[Vector3(  0, 0,  55), 1], [Vector3(  0, 0, -55), 1],
		[Vector3(-22, 0, -20), 1], [Vector3( 22, 0,  20), 1],
	]
	var idx := 0
	for stack in stacks:
		var pos: Vector3 = stack[0]
		var count: int   = stack[1]
		for k in count:
			var crate := _make_crate(pos + Vector3(0, 0.4 + k * 0.80, 0))
			crate.name = "Crate_%d" % idx
			add_child(crate)
			idx += 1

func _spawn_sandbags_oasis() -> void:
	var walls: Array = [
		# Oasis pool defensive positions
		[Vector3(-11, 0.25,   0), Vector3(0.6, 0.5, 4.0)],
		[Vector3( 11, 0.25,   0), Vector3(0.6, 0.5, 4.0)],
		[Vector3(  0, 0.25, -11), Vector3(4.0, 0.5, 0.6)],
		[Vector3(  0, 0.25,  11), Vector3(4.0, 0.5, 0.6)],
		# Flag B approach
		[Vector3(-22, 0.25, -44), Vector3(4.0, 0.5, 0.6)],
		[Vector3(-38, 0.25, -44), Vector3(4.0, 0.5, 0.6)],
		# Flag D approach
		[Vector3( 22, 0.25,  44), Vector3(4.0, 0.5, 0.6)],
		[Vector3( 38, 0.25,  44), Vector3(4.0, 0.5, 0.6)],
		# Alpha bunker exterior
		[Vector3(-62, 0.25,  -5), Vector3(0.6, 0.5, 8.0)],
		[Vector3(-62, 0.25,   5), Vector3(0.6, 0.5, 8.0)],
		# Bravo bunker exterior
		[Vector3( 62, 0.25,   5), Vector3(0.6, 0.5, 8.0)],
		[Vector3( 62, 0.25,  -5), Vector3(0.6, 0.5, 8.0)],
	]
	for i in walls.size():
		var sb := _make_sandbag_wall(walls[i][0], walls[i][1])
		sb.name = "Sandbag_%d" % i
		add_child(sb)

func _spawn_vehicles_oasis() -> void:
	var jeep_scene := load("res://scenes/vehicles/Jeep.tscn") as PackedScene
	var tank_scene := load("res://scenes/vehicles/Tank.tscn") as PackedScene
	var heli_scene := load("res://scenes/vehicles/Helicopter.tscn") as PackedScene

	var jeep_spawns: Array = [
		[Vector3(-88, 1,  8), Vector3(0,  1.5708, 0)],
		[Vector3( 88, 1, -8), Vector3(0, -1.5708, 0)],
		[Vector3(-88, 1, -8), Vector3(0,  1.5708, 0)],
		[Vector3( 88, 1,  8), Vector3(0, -1.5708, 0)],
	]
	if jeep_scene:
		for i in jeep_spawns.size():
			var j := jeep_scene.instantiate()
			j.name     = "Jeep_%d" % i
			j.position = jeep_spawns[i][0]
			j.rotation = jeep_spawns[i][1]
			add_child(j)

	var tank_spawns: Array = [
		[Vector3(-82, 1,  16), Vector3(0,  1.5708, 0)],
		[Vector3( 82, 1, -16), Vector3(0, -1.5708, 0)],
	]
	if tank_scene:
		for i in tank_spawns.size():
			var t := tank_scene.instantiate()
			t.name     = "Tank_%d" % i
			t.position = tank_spawns[i][0]
			t.rotation = tank_spawns[i][1]
			add_child(t)

	if heli_scene:
		var h := heli_scene.instantiate()
		h.name     = "Helicopter_0"
		h.position = Vector3(0, 1, -22)
		add_child(h)

func _spawn_ambient_lights_oasis() -> void:
	var lights: Array = [
		# [position, color, range, energy]
		[Vector3(  0, 3.5,   0), Color(0.55, 0.80, 1.00), 14.0, 1.0],   # oasis centre
		[Vector3(-75, 3.0,   0), Color(0.65, 0.90, 0.62), 12.0, 0.9],   # Alpha flag
		[Vector3( 75, 3.0,   0), Color(1.00, 0.32, 0.28), 12.0, 0.9],   # Bravo flag
		[Vector3(-30, 3.5, -45), Color(0.70, 0.55, 1.00),  9.0, 0.7],   # Flag B ruins
		[Vector3( 30, 3.5,  45), Color(0.70, 0.55, 1.00),  9.0, 0.7],   # Flag D ruins
		[Vector3(  0, 4.0, -65), Color(0.80, 0.75, 0.60),  7.0, 0.6],   # North rocks
		[Vector3(  0, 4.0,  65), Color(0.80, 0.75, 0.60),  7.0, 0.6],   # South rocks
	]
	for i in lights.size():
		var l := OmniLight3D.new()
		l.name           = "OasisLight_%d" % i
		l.position       = lights[i][0]
		l.light_color    = lights[i][1]
		l.omni_range     = lights[i][2]
		l.light_energy   = lights[i][3]
		l.shadow_enabled = false
		add_child(l)

func _spawn_weapon_props() -> void:
	if not ResourceLoader.exists(AK74_GLB):
		return
	var ak_scene := load(AK74_GLB) as PackedScene
	if not ak_scene:
		return
	# Pose des props AK sur des positions tactiques intéressantes
	var positions: Array[Vector3] = [
		Vector3(-30,  0.5, -48),
		Vector3( 30,  0.5,  48),
		Vector3( 12,  0.5,   2),
		Vector3(-70,  0.5,  10),
		Vector3(  0,  0.5,  56),
	]
	for i in positions.size():
		var inst := ak_scene.instantiate()
		inst.name = "AKProp_%d" % i
		inst.position = positions[i]
		inst.rotation.y = float(i) * 1.2
		# Scale down — GLB models are often in cm, scale to ~0.7m length
		inst.scale = Vector3(0.012, 0.012, 0.012)
		add_child(inst)

func _spawn_health_pickups_oasis() -> void:
	var positions: Array[Vector3] = [
		Vector3(  0.0, 0.9,   0.0),   # oasis center
		Vector3(-75.0, 0.9,   0.0),   # Alpha flag
		Vector3( 75.0, 0.9,   0.0),   # Bravo flag
		Vector3(-30.0, 0.9, -45.0),   # Flag B
		Vector3( 30.0, 0.9,  45.0),   # Flag D
		Vector3(-50.0, 0.9,  20.0),   # North-west flank
		Vector3( 50.0, 0.9, -20.0),   # South-east flank
		Vector3(  0.0, 0.9, -55.0),   # North rocks
		Vector3(  0.0, 0.9,  55.0),   # South rocks
	]
	for i in positions.size():
		var hp := HealthPickup.new()
		hp.name     = "HealthPickup_%d" % i
		hp.position = positions[i]
		add_child(hp)

func _spawn_ammo_pickups_oasis() -> void:
	var positions: Array[Vector3] = [
		Vector3( -6.0, 0.9,   0.0),
		Vector3(  6.0, 0.9,   0.0),
		Vector3(-75.0, 0.9,   8.0),
		Vector3( 75.0, 0.9,  -8.0),
		Vector3(-30.0, 0.9, -38.0),
		Vector3( 30.0, 0.9,  38.0),
		Vector3(-95.0, 0.9,   0.0),
		Vector3( 95.0, 0.9,   0.0),
	]
	for i in positions.size():
		var ap := AmmoPickup.new()
		ap.name     = "AmmoPickup_%d" % i
		ap.position = positions[i]
		add_child(ap)

# ─── Murs de bordure invisibles ──────────────────────────────────────────────
func _build_boundary_walls() -> void:
	const MAP_HALF := 148.0
	const WALL_H   := 30.0
	# [position, size]
	var walls: Array = [
		[Vector3(       0, WALL_H * 0.5,  MAP_HALF), Vector3(MAP_HALF * 2, WALL_H, 1.0)],
		[Vector3(       0, WALL_H * 0.5, -MAP_HALF), Vector3(MAP_HALF * 2, WALL_H, 1.0)],
		[Vector3( MAP_HALF, WALL_H * 0.5,        0), Vector3(1.0, WALL_H, MAP_HALF * 2)],
		[Vector3(-MAP_HALF, WALL_H * 0.5,        0), Vector3(1.0, WALL_H, MAP_HALF * 2)],
	]
	for i in walls.size():
		var body := StaticBody3D.new()
		body.name = "Boundary_%d" % i
		body.position = walls[i][0]
		var col := CollisionShape3D.new()
		var csh := BoxShape3D.new()
		csh.size = walls[i][1]
		col.shape = csh
		body.add_child(col)
		add_child(body)

# ─── Nappes de chaleur sur le sable ──────────────────────────────────────────
func _build_heat_haze() -> void:
	if not ResourceLoader.exists(HEAT_HAZE_SHADER):
		return
	var haze_shader := load(HEAT_HAZE_SHADER) as Shader
	if not haze_shader:
		return

	# Zones de chaleur intense : centre désertique + flancs exposés
	var zones: Array = [
		# [position_xz_centre, taille_xz, intensité, vitesse]
		[Vector3(   0, 0.08,    0), Vector2(60.0, 60.0), 0.014, 1.4],   # centre oasis
		[Vector3( -50, 0.08,  -25), Vector2(45.0, 35.0), 0.018, 1.6],   # flanc NW
		[Vector3(  50, 0.08,   25), Vector2(45.0, 35.0), 0.018, 1.6],   # flanc SE
		[Vector3( -80, 0.08,    0), Vector2(30.0, 30.0), 0.020, 1.8],   # spawn Alpha
		[Vector3(  80, 0.08,    0), Vector2(30.0, 30.0), 0.020, 1.8],   # spawn Bravo
		[Vector3(   0, 0.08,  -65), Vector2(25.0, 20.0), 0.016, 1.2],   # rochers nord
		[Vector3(   0, 0.08,   65), Vector2(25.0, 20.0), 0.016, 1.2],   # rochers sud
	]

	for i in zones.size():
		var pos: Vector3  = zones[i][0]
		var sz: Vector2   = zones[i][1]
		var inten: float  = zones[i][2]
		var spd: float    = zones[i][3]

		var mat := ShaderMaterial.new()
		mat.shader = haze_shader
		mat.set_shader_parameter("intensity",      inten)
		mat.set_shader_parameter("speed",          spd)
		mat.set_shader_parameter("noise_scale",    6.5 + float(i) * 0.4)
		mat.set_shader_parameter("vertical_fade",  0.55)
		mat.render_priority = -1

		var mi  := MeshInstance3D.new()
		mi.name = "HeatHaze_%d" % i
		mi.position = pos
		var pm := PlaneMesh.new()
		pm.size = sz
		mi.mesh = pm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode     = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
