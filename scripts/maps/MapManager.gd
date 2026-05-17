extends Node
class_name MapManager

const GameModeBase    = preload("res://scripts/game_modes/GameModeBase.gd")
const LagCompensation = preload("res://scripts/networking/LagCompensation.gd")
const HUD             = preload("res://scripts/ui/HUD.gd")
const PlayerController = preload("res://scripts/player/PlayerController.gd")
const ConquestMode    = preload("res://scripts/game_modes/Conquest.gd")
const AfterMatch      = preload("res://scripts/ui/AfterMatch.gd")

@export var game_mode_scene: PackedScene
@export var hud_scene: PackedScene
@export var player_scene: PackedScene

@onready var spawner:   PlayerSpawner = $PlayerSpawner
@onready var game_mode: GameModeBase  = $GameMode
@onready var hud_layer: CanvasLayer   = $HUDLayer
@onready var lag_comp:  LagCompensation = $LagCompensation

func _ready() -> void:
	GameManager.reset_for_new_map()
	_setup_visuals()
	_spawn_map_props()
	if multiplayer.is_server():
		_register_spawn_points()
		_setup_server()
	_setup_client()
	game_mode.timer_updated.connect(_on_timer_updated)
	game_mode.round_ended.connect(_on_round_ended)
	_fade_in_start()

func _fade_in_start() -> void:
	# Fondu noir de démarrage (1 frame de délai pour laisser la scène se charger)
	await get_tree().process_frame
	var hud_layer := get_node_or_null("HUDLayer") as CanvasLayer
	if not hud_layer:
		return
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color        = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(fade)
	var tween := fade.create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.2)
	tween.tween_callback(fade.queue_free)

# ─── Visuels terrain + bâtiments ─────────────────────────────────────────────
func _setup_visuals() -> void:
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	# Si BattlefieldEnvironment.gd est attaché, il configure l'env lui-même — ne pas écraser
	if world_env and world_env.get_script() == null:
		var env          := Environment.new()
		env.background_mode          = Environment.BG_SKY
		var sky          := Sky.new()
		var sky_mat      := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color        = Color(0.18, 0.38, 0.72)
		sky_mat.sky_horizon_color    = Color(0.55, 0.68, 0.82)
		sky_mat.ground_bottom_color  = Color(0.22, 0.20, 0.18)
		sky_mat.ground_horizon_color = Color(0.40, 0.38, 0.35)
		sky.sky_material             = sky_mat
		env.sky                      = sky
		env.ambient_light_source     = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy     = 0.6
		env.tonemap_mode             = Environment.TONE_MAPPER_FILMIC
		env.ssao_enabled             = true
		env.ssao_radius              = 1.0
		env.ssao_intensity           = 1.6
		env.glow_enabled             = true
		env.glow_normalized          = true
		env.glow_intensity           = 0.45
		env.glow_bloom               = 0.08
		env.fog_enabled              = true
		env.fog_light_color          = Color(0.60, 0.70, 0.80)
		env.fog_density              = 0.0012
		env.fog_aerial_perspective   = 0.12
		world_env.environment        = env

	var ground_mesh := get_node_or_null("Ground/GroundMesh") as MeshInstance3D
	if ground_mesh:
		var mesh    := BoxMesh.new()
		mesh.size   = Vector3(200.0, 0.5, 200.0)
		ground_mesh.mesh = mesh
		ground_mesh.material_override = _make_pbr_material(
			"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Color.jpg",
			"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_NormalGL.jpg",
			"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Roughness.jpg",
			"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_AmbientOcclusion.jpg",
			52.0)
	_add_capture_paving()

	const ROCK_C := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Color.png"
	const ROCK_N := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_NormalGL.png"
	const ROCK_R := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Roughness.png"
	const ROCK_A := "res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_AmbientOcclusion.png"
	for bpath in ["Buildings/Building1", "Buildings/Building2"]:
		_add_pbr_mesh(bpath, Vector3(8, 6, 8), ROCK_C, ROCK_N, ROCK_R, ROCK_A, 4.0)
		_add_building_details(bpath, Vector3(8, 6, 8))
	_add_pbr_mesh("Buildings/Wall1", Vector3(10, 4, 1), ROCK_C, ROCK_N, ROCK_R, ROCK_A, 3.0)
	_add_pbr_mesh("Buildings/Wall2", Vector3(10, 4, 1), ROCK_C, ROCK_N, ROCK_R, ROCK_A, 3.0)

# ─── Props 3D : barils, caisses, sacs de sable, pickups ──────────────────────
func _spawn_map_props() -> void:
	_spawn_terrain_elevation()
	_spawn_terrain_features()
	_spawn_barrels()
	_spawn_crates()
	_spawn_sandbags()
	_spawn_health_pickups()
	_spawn_ammo_pickups()
	_spawn_ambient_lights()

func _spawn_ambient_lights() -> void:
	# Lumières tactiques: couleur chaude = intérieur bâtiment, froide = extérieur
	var lights: Array = [
		# [position, color, range, energy]
		[Vector3(-10, 4.0,  5), Color(1.0, 0.82, 0.55), 12.0, 1.4],  # Building1
		[Vector3( 10, 4.0, -5), Color(1.0, 0.82, 0.55), 12.0, 1.4],  # Building2
		[Vector3(  0, 3.5,  0), Color(0.55, 0.75, 1.00),  9.0, 0.9],  # centre carte
		[Vector3(-20, 2.5,  0), Color(0.70, 0.90, 0.65),  8.0, 0.8],  # zone Alpha
		[Vector3( 20, 2.5,  0), Color(0.70, 0.90, 0.65),  8.0, 0.8],  # zone Bravo
		[Vector3(-10, 2.0,  5), Color(0.90, 0.60, 0.30),  6.0, 0.6],  # bâtiment 1 ext
		[Vector3( 10, 2.0, -5), Color(0.90, 0.60, 0.30),  6.0, 0.6],  # bâtiment 2 ext
	]
	for i in lights.size():
		var l := OmniLight3D.new()
		l.name           = "AmbientLight_%d" % i
		l.position       = lights[i][0]
		l.light_color    = lights[i][1]
		l.omni_range     = lights[i][2]
		l.light_energy   = lights[i][3]
		l.shadow_enabled = false
		add_child(l)

func _spawn_terrain_features() -> void:
	var rock_mat := _make_pbr_material(
		"res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Color.png",
		"res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_NormalGL.png",
		"res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_Roughness.png",
		"res://assets/textures/Rock064_2K-PNG/Rock064_2K-PNG_AmbientOcclusion.png", 2.0)
	var rock_positions: Array[Vector3] = [
		Vector3(-30, 0, 15), Vector3(-25, 0, -18), Vector3(30, 0, 12),
		Vector3(26, 0, -20), Vector3(-45, 0, 8),  Vector3(44, 0, -9),
		Vector3(0, 0, 30),   Vector3(0, 0, -32),  Vector3(-38, 0, -12),
		Vector3(38, 0, 14),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in rock_positions.size():
		var pos := rock_positions[i]
		var sz  := Vector3(rng.randf_range(1.5, 3.5), rng.randf_range(0.9, 2.2), rng.randf_range(1.2, 2.8))
		var sb  := StaticBody3D.new()
		sb.position = pos + Vector3(0, sz.y * 0.5 - 0.25, 0)
		sb.rotation.y = rng.randf_range(0, TAU)
		var mi  := MeshInstance3D.new()
		var bm  := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = rock_mat
		sb.add_child(mi)
		var col := CollisionShape3D.new()
		var cs  := BoxShape3D.new()
		cs.size = sz
		col.shape = cs
		sb.add_child(col)
		add_child(sb)
		sb.name = "Rock_%d" % i

	var tree_positions: Array[Vector3] = [
		Vector3(-42, 0, 20), Vector3(-38, 0, 28), Vector3(-44, 0, -22),
		Vector3(42, 0, 18),  Vector3(40, 0, -26), Vector3(46, 0, 6),
		Vector3(-15, 0, 38), Vector3(15, 0, -38), Vector3(0, 0, 42),
		Vector3(-20, 0, -40), Vector3(22, 0, 40),
	]
	for i in tree_positions.size():
		var pos := tree_positions[i]
		rng.seed = 100 + i
		var h := rng.randf_range(3.5, 6.0)
		var tree := _make_tree(pos, h, rng)
		tree.name = "Tree_%d" % i
		add_child(tree)

func _make_tree(pos: Vector3, height: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.position = pos

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.22, 0.14)
	trunk_mat.roughness    = 0.95

	var trunk_mi  := MeshInstance3D.new()
	var trunk_cyl := CylinderMesh.new()
	trunk_cyl.top_radius    = 0.12
	trunk_cyl.bottom_radius = 0.18
	trunk_cyl.height        = height * 0.55
	trunk_mi.mesh = trunk_cyl
	trunk_mi.position = Vector3(0, height * 0.55 * 0.5, 0)
	trunk_mi.material_override = trunk_mat
	root.add_child(trunk_mi)

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(
		rng.randf_range(0.08, 0.15),
		rng.randf_range(0.28, 0.40),
		rng.randf_range(0.08, 0.16))
	leaf_mat.roughness = 0.92

	for layer in 3:
		var ly_mi  := MeshInstance3D.new()
		var ly_sph := SphereMesh.new()
		var r := rng.randf_range(1.1, 1.8) - layer * 0.22
		ly_sph.radius = r
		ly_sph.height = r * 2.0
		ly_mi.mesh = ly_sph
		ly_mi.material_override = leaf_mat
		ly_mi.position = Vector3(
			rng.randf_range(-0.2, 0.2),
			height * 0.52 + layer * r * 0.75,
			rng.randf_range(-0.2, 0.2))
		root.add_child(ly_mi)

	var col := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 0.18
	csh.height = height
	col.shape  = csh
	col.position = Vector3(0, height * 0.5, 0)
	var sb := StaticBody3D.new()
	sb.add_child(col)
	root.add_child(sb)
	return root

func _spawn_terrain_elevation() -> void:
	var dirt_mat := _make_pbr_material(
		"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Color.jpg",
		"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_NormalGL.jpg",
		"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_Roughness.jpg",
		"res://assets/textures/Ground080_4K-JPG/Ground080_4K-JPG_AmbientOcclusion.jpg", 6.0)
	# Bermes tactiques entre les zones
	var berms: Array = [
		[Vector3(-15, 0, 0),  Vector3(8.0, 1.6, 4.0)],
		[Vector3( 15, 0, 0),  Vector3(8.0, 1.6, 4.0)],
		[Vector3(  0, 0, 12), Vector3(4.0, 1.2, 7.0)],
		[Vector3(  0, 0,-12), Vector3(4.0, 1.2, 7.0)],
		[Vector3(-30, 0, 0),  Vector3(5.0, 2.0, 3.5)],
		[Vector3( 30, 0, 0),  Vector3(5.0, 2.0, 3.5)],
	]
	for i in berms.size():
		var pos: Vector3  = berms[i][0]
		var sz: Vector3   = berms[i][1]
		var sb  := StaticBody3D.new()
		sb.position = pos + Vector3(0, sz.y * 0.5, 0)
		sb.name = "Berm_%d" % i
		var mi  := MeshInstance3D.new()
		var bm  := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = dirt_mat
		sb.add_child(mi)
		var col := CollisionShape3D.new()
		var cs  := BoxShape3D.new()
		cs.size = sz
		col.shape = cs
		sb.add_child(col)
		add_child(sb)

func _add_building_details(path: String, size: Vector3) -> void:
	var parent := get_node_or_null(path)
	if not parent:
		return
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.12, 0.12, 0.14)
	roof_mat.metallic     = 0.40
	roof_mat.roughness    = 0.55

	# Corniche de toit
	var ledge := MeshInstance3D.new()
	var lb    := BoxMesh.new()
	lb.size   = Vector3(size.x + 0.35, 0.22, size.z + 0.35)
	ledge.mesh = lb
	ledge.position = Vector3(0, size.y * 0.5 + 0.11, 0)
	ledge.material_override = roof_mat
	parent.add_child(ledge)

	# Toit (légèrement en retrait)
	var roof := MeshInstance3D.new()
	var rb   := BoxMesh.new()
	rb.size  = Vector3(size.x - 0.05, 0.12, size.z - 0.05)
	roof.mesh = rb
	roof.position = Vector3(0, size.y * 0.5 + 0.28, 0)
	roof.material_override = roof_mat
	parent.add_child(roof)

	# Cadres de fenêtres (4 faces)
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.07, 0.10, 0.16)
	win_mat.metallic     = 0.05
	win_mat.roughness    = 0.15
	var offsets := [
		[Vector3(0, 1.2, size.z * 0.5 + 0.02), Vector3(1.4, 0.8, 0.08)],
		[Vector3(0, 1.2, -size.z * 0.5 - 0.02), Vector3(1.4, 0.8, 0.08)],
		[Vector3(size.x * 0.5 + 0.02, 1.2, 0), Vector3(0.08, 0.8, 1.4)],
		[Vector3(-size.x * 0.5 - 0.02, 1.2, 0), Vector3(0.08, 0.8, 1.4)],
	]
	for od in offsets:
		var wf    := MeshInstance3D.new()
		var wfb   := BoxMesh.new()
		wfb.size   = od[1] as Vector3
		wf.mesh    = wfb
		wf.position = od[0] as Vector3
		wf.material_override = win_mat
		parent.add_child(wf)

func _add_capture_paving() -> void:
	var pave_mat := _make_pbr_material(
		"res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_Color.png",
		"res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_NormalGL.png",
		"res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_Roughness.png",
		"res://assets/textures/PavingStones149_4K-PNG/PavingStones149_4K-PNG_AmbientOcclusion.png", 6.0)
	for pos in [Vector3(-20, 0, 0), Vector3(0, 0, 0), Vector3(20, 0, 0)]:
		var sb  := StaticBody3D.new()
		sb.position = pos + Vector3(0, -0.22, 0)
		var mi  := MeshInstance3D.new()
		var bm  := BoxMesh.new()
		bm.size = Vector3(10.0, 0.04, 10.0)
		mi.mesh = bm
		mi.material_override = pave_mat
		sb.add_child(mi)
		add_child(sb)

func _spawn_barrels() -> void:
	# Positions : près des bâtiments et sur les axes d'attaque
	var positions: Array[Vector3] = [
		# Autour de Building1 (à -10,3,5)
		Vector3(-14.0, 0.38, 3.0), Vector3(-13.0, 0.38, 4.5), Vector3(-14.5, 0.38, 5.5),
		# Autour de Building2 (à 10,3,-5)
		Vector3(14.0, 0.38, -3.0), Vector3(13.0, 0.38, -4.5), Vector3(14.5, 0.38, -5.5),
		# Près de Wall1 (à -5,2,-8)
		Vector3(-7.0, 0.38, -10.0), Vector3(-5.5, 0.38, -10.5),
		# Près de Wall2 (à 5,2,8)
		Vector3(7.0, 0.38, 10.0),  Vector3(5.5, 0.38, 10.5),
		# Flancs centre de carte
		Vector3(-28.0, 0.38,  3.0), Vector3(-28.0, 0.38, -3.0),
		Vector3( 28.0, 0.38,  3.0), Vector3( 28.0, 0.38, -3.0),
	]
	for i in positions.size():
		var b := _make_barrel(positions[i])
		b.name = "Barrel_%d" % i
		add_child(b)

func _spawn_crates() -> void:
	var stacks: Array = [
		# [position, nombre d'étages]
		[Vector3( 0.0, 0.0, 12.0), 2],
		[Vector3( 0.0, 0.0,-12.0), 2],
		[Vector3(-16.0, 0.0, 8.0), 1],
		[Vector3( 16.0, 0.0,-8.0), 1],
		[Vector3(-22.0, 0.0,-6.0), 1],
		[Vector3( 22.0, 0.0, 6.0), 1],
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

func _spawn_sandbags() -> void:
	# Murs de sacs de sable horizontaux aux points d'étranglement
	var walls: Array = [
		[Vector3(-18.0, 0.25, 5.0),  Vector3(3.0, 0.5, 0.6)],
		[Vector3( 18.0, 0.25,-5.0),  Vector3(3.0, 0.5, 0.6)],
		[Vector3(  0.0, 0.25, 18.0), Vector3(0.6, 0.5, 3.0)],
		[Vector3(  0.0, 0.25,-18.0), Vector3(0.6, 0.5, 3.0)],
		[Vector3( -8.0, 0.25,  0.0), Vector3(0.6, 0.5, 2.5)],
		[Vector3(  8.0, 0.25,  0.0), Vector3(0.6, 0.5, 2.5)],
	]
	for i in walls.size():
		var pos: Vector3  = walls[i][0]
		var size: Vector3 = walls[i][1]
		var sb := _make_sandbag_wall(pos, size)
		sb.name = "Sandbag_%d" % i
		add_child(sb)

func _spawn_health_pickups() -> void:
	var positions: Array[Vector3] = [
		Vector3(  0.0, 0.9,  0.0),   # centre exact
		Vector3(-20.0, 0.9,  0.0),   # près du drapeau Alpha
		Vector3( 20.0, 0.9,  0.0),   # près du drapeau Bravo
		Vector3(-32.0, 0.9,  5.0),   # côté Alpha
		Vector3( 32.0, 0.9, -5.0),   # côté Bravo
		Vector3(  0.0, 0.9, 14.0),   # flanc nord
		Vector3(  0.0, 0.9,-14.0),   # flanc sud
	]
	for i in positions.size():
		var hp := HealthPickup.new()
		hp.name     = "HealthPickup_%d" % i
		hp.position = positions[i]
		add_child(hp)

func _spawn_ammo_pickups() -> void:
	var positions: Array[Vector3] = [
		Vector3( -5.0, 0.9,  0.0),   # centre-gauche
		Vector3(  5.0, 0.9,  0.0),   # centre-droite
		Vector3(-20.0, 0.9,  7.0),   # zone drapeau Alpha
		Vector3( 20.0, 0.9, -7.0),   # zone drapeau Bravo
		Vector3(-36.0, 0.9,  0.0),   # spawn Alpha
		Vector3( 36.0, 0.9,  0.0),   # spawn Bravo
	]
	for i in positions.size():
		var ap := AmmoPickup.new()
		ap.name     = "AmmoPickup_%d" % i
		ap.position = positions[i]
		add_child(ap)

# ─── Constructeurs de props ───────────────────────────────────────────────────
func _make_barrel(pos: Vector3) -> StaticBody3D:
	var body  := StaticBody3D.new()
	body.position = pos

	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.22
	cyl.bottom_radius = 0.24
	cyl.height        = 0.75
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.14, 0.12)
	mat.metallic     = 0.65
	mat.roughness    = 0.55
	mi.material_override = mat
	body.add_child(mi)

	# Cerclages métalliques
	for rim_y in [-0.28, 0.28]:
		var rim_mi := MeshInstance3D.new()
		var rim_cyl := CylinderMesh.new()
		rim_cyl.top_radius    = 0.245
		rim_cyl.bottom_radius = 0.245
		rim_cyl.height        = 0.045
		rim_mi.mesh = rim_cyl
		rim_mi.position = Vector3(0, rim_y, 0)
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color(0.28, 0.25, 0.22)
		rim_mat.metallic     = 0.75
		rim_mat.roughness    = 0.40
		rim_mi.material_override = rim_mat
		body.add_child(rim_mi)

	var col := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 0.24
	csh.height = 0.75
	col.shape  = csh
	body.add_child(col)
	return body

func _make_crate(pos: Vector3) -> StaticBody3D:
	var body  := StaticBody3D.new()
	body.position = pos

	var sz := Vector3(0.80, 0.80, 0.80)
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.34, 0.20)
	mat.roughness    = 0.88
	mat.metallic     = 0.05
	mi.material_override = mat
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = sz
	col.shape = csh
	body.add_child(col)
	return body

func _make_sandbag_wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body      := StaticBody3D.new()
	body.position = pos

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.55, 0.38)
	mat.roughness    = 0.92
	mat.metallic     = 0.0
	mi.material_override = mat
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = size
	col.shape = csh
	body.add_child(col)
	return body

# ─── Utilitaires PBR ─────────────────────────────────────────────────────────
func _make_pbr_material(color_path: String, normal_path: String,
		rough_path: String, ao_path: String, uv_scale: float = 1.0) -> StandardMaterial3D:
	var mat              := StandardMaterial3D.new()
	mat.uv1_scale        = Vector3(uv_scale, uv_scale, uv_scale)
	var color_tex  = load(color_path)  if ResourceLoader.exists(color_path)  else null
	var normal_tex = load(normal_path) if ResourceLoader.exists(normal_path) else null
	var rough_tex  = load(rough_path)  if ResourceLoader.exists(rough_path)  else null
	var ao_tex     = load(ao_path)     if ResourceLoader.exists(ao_path)     else null
	if color_tex:  mat.albedo_texture  = color_tex
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale   = 1.0
	if rough_tex:
		mat.roughness_texture         = rough_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if ao_tex:
		mat.ao_enabled      = true
		mat.ao_texture      = ao_tex
		mat.ao_light_affect = 0.8
	return mat

func _add_pbr_mesh(path: String, size: Vector3,
		color_p: String, normal_p: String, rough_p: String, ao_p: String,
		uv_scale: float) -> void:
	var parent := get_node_or_null(path)
	if not parent:
		return
	var mi := parent.get_node_or_null("Mesh") as MeshInstance3D
	if not mi:
		mi = MeshInstance3D.new()
		parent.add_child(mi)
	var mesh    := BoxMesh.new()
	mesh.size   = size
	mi.mesh     = mesh
	mi.material_override = _make_pbr_material(color_p, normal_p, rough_p, ao_p, uv_scale)

# ─── Enregistrement des points de spawn (serveur uniquement) ─────────────────
func _register_spawn_points() -> void:
	var sp_root := get_node_or_null("SpawnPoints")
	if not sp_root:
		push_warning("MapManager : aucun nœud SpawnPoints trouvé")
		return
	for child in sp_root.get_children():
		if not child is Node3D:
			continue
		var n := child.name.to_lower()
		if n.begins_with("alpha"):
			GameManager.register_spawn_point(GameManager.Team.ALPHA, child as Node3D)
		elif n.begins_with("bravo"):
			GameManager.register_spawn_point(GameManager.Team.BRAVO, child as Node3D)

# ─── Initialisation serveur ───────────────────────────────────────────────────
func _setup_server() -> void:
	if spawner:
		if not spawner.player_scene:
			spawner.player_scene = player_scene if player_scene \
				else load("res://scenes/player/Player.tscn")
		spawner.spawn_parent = $Players

		# Fallback solo/debug : enregistre un joueur si aucun n'existe encore
		if NetworkManager.player_info.is_empty():
			var solo_id := multiplayer.get_unique_id()
			NetworkManager.player_info[solo_id] = {"name": "Solo", "team": GameManager.Team.ALPHA}

		# Re-synchronise GameManager.players depuis NetworkManager
		# (reset_for_new_map() les a effacés, il faut les recréer avant le spawn)
		for pid in NetworkManager.player_info:
			var info: Dictionary = NetworkManager.player_info[pid]
			GameManager.register_player(pid, info.get("name", "Soldat"), info.get("team", GameManager.Team.ALPHA))

		# Spawn de tous les joueurs
		for pid in NetworkManager.player_info:
			spawner.spawn_player(pid)

# ─── Initialisation client ────────────────────────────────────────────────────
func _setup_client() -> void:
	var hud: HUD = null
	if hud_scene:
		hud = hud_scene.instantiate() as HUD
		hud_layer.add_child(hud)

	# Connecte les tickets Conquest aux labels de score du HUD
	if hud and game_mode is ConquestMode:
		(game_mode as ConquestMode).tickets_changed.connect(hud._on_scores_updated)

	var local_id := multiplayer.get_unique_id()
	var player: Node = null
	var attempts := 0
	while not player and attempts < 120:
		await get_tree().process_frame
		player = _find_local_player(local_id)
		attempts += 1

	if player and hud:
		hud.link_player(player as PlayerController)
	GameManager.current_game_mode = game_mode

	# Écran de fin de match
	const AFTER_MATCH_SCENE := "res://scenes/ui/AfterMatch.tscn"
	if ResourceLoader.exists(AFTER_MATCH_SCENE):
		var am_scene := load(AFTER_MATCH_SCENE) as PackedScene
		if am_scene:
			var am := am_scene.instantiate() as AfterMatch
			hud_layer.add_child(am)
			GameManager.match_ended.connect(am.show_result)

func _find_local_player(peer_id: int) -> Node:
	if spawner:
		var p := spawner.get_player_node(peer_id)
		if p:
			return p
	var players_node := get_node_or_null("Players")
	if players_node:
		return players_node.get_node_or_null(str(peer_id))
	return null

# ─── Callbacks ────────────────────────────────────────────────────────────────
func _on_timer_updated(remaining: float) -> void:
	var hud: HUD = _get_hud()
	if hud:
		hud.update_round_timer(remaining)

func _on_round_ended(winner: int) -> void:
	var msg := "ÉQUIPE %s GAGNE !" % GameManager.TEAM_NAMES.get(winner, "INCONNUE")
	var hud: HUD = _get_hud()
	if hud:
		hud.show_objective_message(msg, 8.0)
	await get_tree().create_timer(8.0).timeout
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _get_hud() -> HUD:
	if hud_layer.get_child_count() > 0:
		return hud_layer.get_child(0) as HUD
	return null
