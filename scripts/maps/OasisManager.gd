extends MapManager
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

const HDRI_SKY := "res://assets/skies/DaySkyHDRI059A_4K_HDR.exr"
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

# ─── HDRI panorama sky ────────────────────────────────────────────────────────
func _setup_hdri_sky() -> void:
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not world_env:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky     := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	if ResourceLoader.exists(HDRI_SKY):
		sky_mat.panorama = load(HDRI_SKY) as Texture2D
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source   = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy   = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode           = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure       = 1.05
	env.tonemap_white          = 6.0
	env.glow_enabled           = true
	env.glow_normalized        = true
	env.glow_intensity         = 0.6
	env.glow_bloom             = 0.12
	env.ssao_enabled           = true
	env.ssao_radius            = 1.2
	env.ssao_intensity         = 2.0
	env.ssil_enabled           = true
	env.ssil_radius            = 5.0
	env.ssil_intensity         = 0.8
	env.ssil_sharpness         = 0.9
	env.sdfgi_enabled          = true
	env.sdfgi_use_occlusion    = true
	env.sdfgi_min_cell_size    = 0.2
	env.sdfgi_energy           = 1.0
	env.ssr_enabled            = false
	# Desert atmosphere — subtle sandy haze
	env.fog_enabled            = true
	env.fog_light_color        = Color(0.94, 0.82, 0.62)
	env.fog_density            = 0.0018
	env.fog_aerial_perspective = 0.18
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo  = Color(0.92, 0.80, 0.60)
	env.volumetric_fog_emission = Color(0.18, 0.12, 0.05)
	env.volumetric_fog_emission_energy = 0.12
	env.adjustment_enabled     = true
	env.adjustment_saturation  = 1.08
	env.adjustment_contrast    = 1.04
	world_env.environment = env

	# Direction du soleil pour un éclairage doré désertique
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-38, 30, 0)
		sun.light_energy     = 1.4
		sun.light_color      = Color(1.0, 0.92, 0.78)
		sun.shadow_enabled   = true

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
