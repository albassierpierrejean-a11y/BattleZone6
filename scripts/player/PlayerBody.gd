extends Node3D
class_name PlayerBody
const PlayerController = preload("res://scripts/player/PlayerController.gd")

enum SoldierClass { ASSAULT = 0, MEDIC = 1, SNIPER = 2, ENGINEER = 3, HEAVY = 4, RECON = 5 }
const CLASS_COUNT := 6

# ─── Skin tone per class ──────────────────────────────────────────────────────
const SKIN := [
	Color(0.750, 0.600, 0.480),  # Assault  — medium-light
	Color(0.875, 0.718, 0.615),  # Medic    — fair
	Color(0.618, 0.480, 0.348),  # Sniper   — medium
	Color(0.748, 0.598, 0.475),  # Engineer — medium-light
	Color(0.398, 0.288, 0.188),  # Heavy    — dark
	Color(0.618, 0.480, 0.348),  # Recon    — medium
]

# Per-class palette [uniform, gear, helmet] — Alpha (green) team
const PAL_ALPHA := [
	[Color(0.120,0.178,0.100), Color(0.158,0.220,0.132), Color(0.090,0.132,0.070)], # Assault
	[Color(0.158,0.238,0.128), Color(0.122,0.180,0.096), Color(0.215,0.295,0.172)], # Medic
	[Color(0.072,0.112,0.052), Color(0.098,0.140,0.068), Color(0.052,0.085,0.035)], # Sniper
	[Color(0.195,0.195,0.128), Color(0.268,0.255,0.158), Color(0.155,0.155,0.098)], # Engineer
	[Color(0.108,0.138,0.095), Color(0.078,0.098,0.065), Color(0.058,0.075,0.048)], # Heavy
	[Color(0.092,0.138,0.072), Color(0.135,0.182,0.105), Color(0.175,0.252,0.138)], # Recon
]
# Per-class palette — Bravo (tan) team
const PAL_BRAVO := [
	[Color(0.462,0.402,0.258), Color(0.382,0.322,0.198), Color(0.332,0.282,0.162)], # Assault
	[Color(0.515,0.462,0.298), Color(0.378,0.338,0.202), Color(0.442,0.402,0.258)], # Medic
	[Color(0.278,0.238,0.142), Color(0.228,0.195,0.115), Color(0.198,0.168,0.092)], # Sniper
	[Color(0.518,0.495,0.315), Color(0.442,0.418,0.252), Color(0.378,0.355,0.212)], # Engineer
	[Color(0.348,0.308,0.208), Color(0.248,0.218,0.145), Color(0.195,0.172,0.108)], # Heavy
	[Color(0.548,0.498,0.342), Color(0.438,0.395,0.248), Color(0.578,0.535,0.378)], # Recon
]

func _ready() -> void:
	var player := get_parent() as PlayerController
	if not player:
		return
	await get_tree().process_frame
	if player.is_multiplayer_authority():
		visible = false
		return
	_build(player)
	_build_name_tag(player)

func _build(player: PlayerController) -> void:
	var cls  := player.peer_id % CLASS_COUNT
	var skin := SKIN[cls]
	var pal: Array
	match player.team:
		GameManager.Team.ALPHA: pal = PAL_ALPHA[cls]
		GameManager.Team.BRAVO: pal = PAL_BRAVO[cls]
		_:                      pal = PAL_ALPHA[cls]
	match cls:
		SoldierClass.ASSAULT:  _build_assault(pal, skin)
		SoldierClass.MEDIC:    _build_medic(pal, skin)
		SoldierClass.SNIPER:   _build_sniper(pal, skin)
		SoldierClass.ENGINEER: _build_engineer(pal, skin)
		SoldierClass.HEAVY:    _build_heavy(pal, skin)
		_:                     _build_recon(pal, skin)

# ─── ASSAULT — standard infantry, PASGT dome helmet, radio on shoulder ────────
func _build_assault(pal: Array, skin: Color) -> void:
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.270; m.height = 1.15)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.300; m.height = 0.55)
	_add(CylinderMesh.new(), Vector3(0, 1.560, 0), skin,
		func(m): m.top_radius = 0.07; m.bottom_radius = 0.09; m.height = 0.12)
	_add(SphereMesh.new(), Vector3(0, 1.660, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# PASGT dome — squished sphere = wider than tall
	_add(SphereMesh.new(), Vector3(0, 1.695, 0), pal[2],
		func(m): m.radius = 0.218; m.height = 0.265)
	_add(CapsuleMesh.new(), Vector3(-0.34, 1.05, 0), pal[0],
		func(m): m.radius = 0.065; m.height = 0.62)
	_add(CapsuleMesh.new(), Vector3( 0.34, 1.05, 0), pal[0],
		func(m): m.radius = 0.065; m.height = 0.62)
	# Radio handset on left shoulder
	_add(BoxMesh.new(), Vector3(-0.34, 1.28, 0.04), pal[1],
		func(m): m.size = Vector3(0.07, 0.12, 0.05))
	_add(CylinderMesh.new(), Vector3(-0.34, 1.38, 0.04), Color(0.08,0.08,0.08),
		func(m): m.top_radius = 0.008; m.bottom_radius = 0.008; m.height = 0.09)

# ─── MEDIC — lighter build, soft cap, red-cross armband, medical bag ──────────
func _build_medic(pal: Array, skin: Color) -> void:
	var white := Color(0.92, 0.92, 0.90)
	var red   := Color(0.72, 0.06, 0.06)
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.260; m.height = 1.18)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.278; m.height = 0.50)
	_add(CylinderMesh.new(), Vector3(0, 1.565, 0), skin,
		func(m): m.top_radius = 0.07; m.bottom_radius = 0.09; m.height = 0.12)
	_add(SphereMesh.new(), Vector3(0, 1.665, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# Soft garrison cap
	_add(CylinderMesh.new(), Vector3(0, 1.762, 0), pal[2],
		func(m): m.top_radius = 0.180; m.bottom_radius = 0.195; m.height = 0.112)
	_add(CylinderMesh.new(), Vector3(0, 1.706, 0), pal[2],
		func(m): m.top_radius = 0.210; m.bottom_radius = 0.210; m.height = 0.022)
	_add(CapsuleMesh.new(), Vector3(-0.33, 1.05, 0), pal[0],
		func(m): m.radius = 0.062; m.height = 0.62)
	_add(CapsuleMesh.new(), Vector3( 0.33, 1.05, 0), pal[0],
		func(m): m.radius = 0.062; m.height = 0.62)
	# Red-cross armband on left arm
	_add(CylinderMesh.new(), Vector3(-0.33, 1.12, 0), white,
		func(m): m.top_radius = 0.073; m.bottom_radius = 0.073; m.height = 0.058)
	_add(BoxMesh.new(), Vector3(-0.33, 1.12, 0), red,
		func(m): m.size = Vector3(0.025, 0.025, 0.145))
	_add(BoxMesh.new(), Vector3(-0.33, 1.12, 0), red,
		func(m): m.size = Vector3(0.025, 0.110, 0.025))
	# Medical bag on back (white with red cross)
	_add(BoxMesh.new(), Vector3(0, 0.95, 0.22), white,
		func(m): m.size = Vector3(0.22, 0.26, 0.10))
	_add(BoxMesh.new(), Vector3(0, 0.97, 0.228), red,
		func(m): m.size = Vector3(0.05, 0.05, 0.01))

# ─── SNIPER — tall/thin, boonie hat, ghillie vegetation patches ───────────────
func _build_sniper(pal: Array, skin: Color) -> void:
	var leaf := Color(0.095, 0.178, 0.065)
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.238; m.height = 1.22)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.260; m.height = 0.38)
	_add(CylinderMesh.new(), Vector3(0, 1.575, 0), skin,
		func(m): m.top_radius = 0.07; m.bottom_radius = 0.09; m.height = 0.12)
	_add(SphereMesh.new(), Vector3(0, 1.675, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# Boonie hat — crown cylinder + wide flat brim
	_add(CylinderMesh.new(), Vector3(0, 1.772, 0), pal[2],
		func(m): m.top_radius = 0.162; m.bottom_radius = 0.172; m.height = 0.128)
	_add(CylinderMesh.new(), Vector3(0, 1.714, 0), pal[2],
		func(m): m.top_radius = 0.275; m.bottom_radius = 0.275; m.height = 0.024)
	_add(CapsuleMesh.new(), Vector3(-0.31, 1.05, 0), pal[0],
		func(m): m.radius = 0.058; m.height = 0.62)
	_add(CapsuleMesh.new(), Vector3( 0.31, 1.05, 0), pal[0],
		func(m): m.radius = 0.058; m.height = 0.62)
	# Ghillie vegetation — fixed positions on front torso
	_add(SphereMesh.new(), Vector3(-0.10, 0.82, -0.19), leaf, func(m: SphereMesh): m.radius = 0.068)
	_add(SphereMesh.new(), Vector3( 0.08, 1.10, -0.20), leaf, func(m: SphereMesh): m.radius = 0.072)
	_add(SphereMesh.new(), Vector3(-0.06, 0.98, -0.20), leaf, func(m: SphereMesh): m.radius = 0.065)
	_add(SphereMesh.new(), Vector3( 0.12, 0.88, -0.18), leaf, func(m: SphereMesh): m.radius = 0.058)

# ─── ENGINEER — stocky, angular box helmet + visor peak, kneepads, tool pouch ─
func _build_engineer(pal: Array, skin: Color) -> void:
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.290; m.height = 1.10)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.322; m.height = 0.60)
	_add(CylinderMesh.new(), Vector3(0, 1.540, 0), skin,
		func(m): m.top_radius = 0.07; m.bottom_radius = 0.10; m.height = 0.12)
	_add(SphereMesh.new(), Vector3(0, 1.640, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# Angular combat helmet (box)
	_add(BoxMesh.new(), Vector3(0, 1.698, 0), pal[2],
		func(m): m.size = Vector3(0.400, 0.225, 0.420))
	# Visor peak at front (-Z)
	_add(BoxMesh.new(), Vector3(0, 1.592, -0.176), pal[2],
		func(m): m.size = Vector3(0.345, 0.062, 0.115))
	_add(CapsuleMesh.new(), Vector3(-0.36, 1.05, 0), pal[0],
		func(m): m.radius = 0.068; m.height = 0.60)
	_add(CapsuleMesh.new(), Vector3( 0.36, 1.05, 0), pal[0],
		func(m): m.radius = 0.068; m.height = 0.60)
	# Tool pouch on right hip
	_add(BoxMesh.new(), Vector3(0.30, 0.68, -0.06), pal[1],
		func(m): m.size = Vector3(0.12, 0.16, 0.08))
	# Kneepads (front of knees, -Z)
	_add(BoxMesh.new(), Vector3(-0.10, 0.38, -0.14), pal[2],
		func(m): m.size = Vector3(0.12, 0.04, 0.12))
	_add(BoxMesh.new(), Vector3( 0.10, 0.38, -0.14), pal[2],
		func(m): m.size = Vector3(0.12, 0.04, 0.12))

# ─── HEAVY — bulky, full ballistic helmet with ear guards, shoulder plates ────
func _build_heavy(pal: Array, skin: Color) -> void:
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.330; m.height = 1.05)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.368; m.height = 0.65)
	_add(CylinderMesh.new(), Vector3(0, 1.515, 0), skin,
		func(m): m.top_radius = 0.082; m.bottom_radius = 0.105; m.height = 0.10)
	_add(SphereMesh.new(), Vector3(0, 1.615, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# Full ballistic helmet — perfect sphere for max coverage
	_add(SphereMesh.new(), Vector3(0, 1.655, 0), pal[2],
		func(m): m.radius = 0.240; m.height = 0.480)
	# Ear protection boxes
	_add(BoxMesh.new(), Vector3(-0.225, 1.612, 0), pal[2],
		func(m): m.size = Vector3(0.058, 0.185, 0.215))
	_add(BoxMesh.new(), Vector3( 0.225, 1.612, 0), pal[2],
		func(m): m.size = Vector3(0.058, 0.185, 0.215))
	_add(CapsuleMesh.new(), Vector3(-0.39, 1.05, 0), pal[0],
		func(m): m.radius = 0.076; m.height = 0.60)
	_add(CapsuleMesh.new(), Vector3( 0.39, 1.05, 0), pal[0],
		func(m): m.radius = 0.076; m.height = 0.60)
	# Shoulder armor plates
	_add(BoxMesh.new(), Vector3(-0.38, 1.22, 0), pal[2],
		func(m): m.size = Vector3(0.158, 0.082, 0.182))
	_add(BoxMesh.new(), Vector3( 0.38, 1.22, 0), pal[2],
		func(m): m.size = Vector3(0.158, 0.082, 0.182))

# ─── RECON — lean, baseball cap with front brim, earpiece + wire ─────────────
func _build_recon(pal: Array, skin: Color) -> void:
	var dark := Color(0.12, 0.12, 0.10)
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), pal[0],
		func(m): m.radius = 0.248; m.height = 1.20)
	_add(CapsuleMesh.new(), Vector3(0, 0.96, 0), pal[1],
		func(m): m.radius = 0.265; m.height = 0.42)
	_add(CylinderMesh.new(), Vector3(0, 1.570, 0), skin,
		func(m): m.top_radius = 0.07; m.bottom_radius = 0.09; m.height = 0.12)
	_add(SphereMesh.new(), Vector3(0, 1.670, 0), skin,
		func(m): m.radius = 0.175; m.height = 0.35)
	# Baseball cap — crown + brim disk + front-only peak
	_add(CylinderMesh.new(), Vector3(0, 1.768, 0), pal[2],
		func(m): m.top_radius = 0.182; m.bottom_radius = 0.192; m.height = 0.090)
	_add(CylinderMesh.new(), Vector3(0, 1.724, 0), pal[2],
		func(m): m.top_radius = 0.205; m.bottom_radius = 0.205; m.height = 0.022)
	_add(BoxMesh.new(), Vector3(0, 1.715, -0.178), pal[2],
		func(m): m.size = Vector3(0.240, 0.022, 0.135))
	_add(CapsuleMesh.new(), Vector3(-0.32, 1.05, 0), pal[0],
		func(m): m.radius = 0.060; m.height = 0.62)
	_add(CapsuleMesh.new(), Vector3( 0.32, 1.05, 0), pal[0],
		func(m): m.radius = 0.060; m.height = 0.62)
	# Earpiece + wire on right ear
	_add(SphereMesh.new(), Vector3(0.185, 1.640, 0.028), dark,
		func(m: SphereMesh): m.radius = 0.025)
	_add(CylinderMesh.new(), Vector3(0.185, 1.572, 0.028), dark,
		func(m): m.top_radius = 0.006; m.bottom_radius = 0.006; m.height = 0.12)

# ─── Name tag ────────────────────────────────────────────────────────────────
func _build_name_tag(player: PlayerController) -> void:
	var label := Label3D.new()
	label.text          = player.player_name
	label.font_size     = 28
	label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position      = Vector3(0, 2.15, 0)
	match player.team:
		GameManager.Team.ALPHA: label.modulate = Color(0.35, 0.72, 1.0, 0.9)
		GameManager.Team.BRAVO: label.modulate = Color(1.0, 0.32, 0.28, 0.9)
		_:                      label.modulate = Color(0.88, 0.92, 0.80, 0.9)
	add_child(label)

# ─── Mesh helper ─────────────────────────────────────────────────────────────
func _add(mesh: Mesh, pos: Vector3, color: Color, configure: Callable) -> void:
	configure.call(mesh)
	# Maximise polygon density on every primitive for ultra-high-poly appearance
	if mesh is SphereMesh:
		(mesh as SphereMesh).radial_segments = 128
		(mesh as SphereMesh).rings           = 64
	elif mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radial_segments = 64
		(mesh as CapsuleMesh).rings           = 32
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).radial_segments = 64
		(mesh as CylinderMesh).rings           = 16
	elif mesh is BoxMesh:
		(mesh as BoxMesh).subdivide_width  = 12
		(mesh as BoxMesh).subdivide_height = 12
		(mesh as BoxMesh).subdivide_depth  = 12
	var mi := MeshInstance3D.new()
	mi.mesh     = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.82
	mat.metallic     = 0.04
	mi.material_override = mat
	add_child(mi)
