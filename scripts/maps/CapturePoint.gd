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
var _beacon_light: OmniLight3D
var _outer_ring: MeshInstance3D
var _outer_ring_mat: StandardMaterial3D
var _pulse_t: float = 0.0

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

	# ── Anneau extérieur animé ──
	_outer_ring = MeshInstance3D.new()
	var ring_c := CylinderMesh.new()
	ring_c.top_radius    = 2.8
	ring_c.bottom_radius = 2.8
	ring_c.height        = 0.04
	ring_c.rings         = 1
	_outer_ring.mesh = ring_c
	_outer_ring.position = Vector3(0, 0.03, 0)
	_outer_ring_mat = StandardMaterial3D.new()
	_outer_ring_mat.emission_enabled = true
	_outer_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outer_ring_mat.albedo_color = Color(1, 1, 1, 0)
	_outer_ring.material_override = _outer_ring_mat
	add_child(_outer_ring)

	# ── Beacon lumineux au sommet du mât ──
	_beacon_light = OmniLight3D.new()
	_beacon_light.position  = Vector3(0, 4.5, 0)
	_beacon_light.omni_range = 10.0
	_beacon_light.light_energy = 2.2
	add_child(_beacon_light)

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
	if _beacon_light:
		_beacon_light.light_color = color
	if _outer_ring_mat:
		_outer_ring_mat.emission = color * 0.9

func _process(delta: float) -> void:
	if flag_mesh:
		flag_mesh.rotate_y(delta * 0.55)
	_pulse_t += delta * 1.4
	if _outer_ring:
		var s := 1.0 + sin(_pulse_t) * 0.06
		_outer_ring.scale = Vector3(s, 1.0, s)
	if _outer_ring_mat:
		var alpha := (sin(_pulse_t) * 0.5 + 0.5) * 0.55 + 0.15
		_outer_ring_mat.albedo_color.a = alpha
	if _beacon_light:
		var energy := 1.8 + sin(_pulse_t * 1.8) * 0.45
		_beacon_light.light_energy = energy
