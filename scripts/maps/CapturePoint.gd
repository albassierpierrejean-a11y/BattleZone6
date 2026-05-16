extends Node3D
class_name CapturePoint

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var flag_id: int          = 0
@export var point_name: String    = "Alpha"
@export var start_team: int       = 0   # 0 = neutre

# ─── Références nœuds (définis dans la scène) ────────────────────────────────
@onready var flag_pole_mi: MeshInstance3D   = $FlagPole
@onready var flag_mesh: MeshInstance3D      = $FlagPole/FlagMesh
@onready var capture_area: Area3D           = $CaptureArea
@onready var team_indicator: MeshInstance3D = $TeamIndicator

# ─── Couleurs des équipes ────────────────────────────────────────────────────
const TEAM_COLORS := {
	0: Color(0.65, 0.65, 0.65),
	1: Color(0.15, 0.45, 1.00),
	2: Color(1.00, 0.22, 0.12),
}

# ─── État ────────────────────────────────────────────────────────────────────
var owner_team: int   = 0
var _progress: float  = 0.0
var _name_label: Label3D
var _flag_mat: StandardMaterial3D
var _indicator_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("capture_points")
	owner_team = start_team
	_build_visuals()
	_update_visual()

func _build_visuals() -> void:
	# ── Cylindre du mât ──
	if flag_pole_mi:
		var cyl := CylinderMesh.new()
		cyl.top_radius    = 0.025
		cyl.bottom_radius = 0.045
		cyl.height        = 4.0
		flag_pole_mi.mesh = cyl
		var pole_mat := StandardMaterial3D.new()
		pole_mat.albedo_color = Color(0.70, 0.70, 0.72)
		pole_mat.metallic     = 0.82
		pole_mat.roughness    = 0.28
		flag_pole_mi.material_override = pole_mat

	# ── Mesh du drapeau ──
	if flag_mesh:
		var fb := BoxMesh.new()
		fb.size = Vector3(0.62, 0.36, 0.025)
		flag_mesh.mesh = fb
		_flag_mat = StandardMaterial3D.new()
		_flag_mat.emission_enabled = true
		flag_mesh.material_override = _flag_mat

	# ── Disque indicateur de base ──
	if team_indicator:
		team_indicator.position = Vector3.ZERO
		var disk := CylinderMesh.new()
		disk.top_radius    = 0.65
		disk.bottom_radius = 0.65
		disk.height        = 0.06
		team_indicator.mesh = disk
		_indicator_mat = StandardMaterial3D.new()
		_indicator_mat.emission_enabled = true
		team_indicator.material_override = _indicator_mat

	# ── Label du nom (billboard) ──
	_name_label = Label3D.new()
	_name_label.text        = point_name
	_name_label.font_size   = 26
	_name_label.position    = Vector3(0.0, 5.4, 0.0)
	_name_label.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	add_child(_name_label)

func set_capture_progress(progress: float, team: int) -> void:
	_progress  = progress
	owner_team = team
	_update_visual()

func _update_visual() -> void:
	var color: Color = TEAM_COLORS.get(owner_team, Color.GRAY)
	if _flag_mat:
		_flag_mat.albedo_color = color
		_flag_mat.emission     = color * 0.35
	if _indicator_mat:
		_indicator_mat.albedo_color = color
		_indicator_mat.emission     = color * 0.55
	if _name_label:
		_name_label.modulate = color

func _process(delta: float) -> void:
	if flag_mesh:
		flag_mesh.rotate_y(delta * 0.55)
