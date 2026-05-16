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

	# ── Mesh du drapeau avec shader d'ondulation ──
	if flag_mesh:
		var fb := PlaneMesh.new()
		fb.size = Vector2(0.65, 0.38)
		fb.subdivide_width  = 8
		fb.subdivide_depth  = 4
		fb.orientation = PlaneMesh.FACE_Z
		flag_mesh.mesh = fb
		flag_mesh.position = Vector3(0.33, 3.8, 0.0)
		var flag_shader := Shader.new()
		flag_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 flag_color : source_color = vec4(0.65, 0.65, 0.65, 1.0);
uniform float wave_speed : hint_range(0.5, 5.0) = 2.2;
uniform float wave_amp   : hint_range(0.0, 0.2) = 0.055;

void vertex() {
	float wave = sin(VERTEX.x * 6.0 + TIME * wave_speed) * wave_amp * VERTEX.x;
	VERTEX.z += wave;
}

void fragment() {
	ALBEDO    = flag_color.rgb;
	EMISSION  = flag_color.rgb * 0.28;
	ROUGHNESS = 0.85;
}
"""
		var flag_smat := ShaderMaterial.new()
		flag_smat.shader = flag_shader
		flag_smat.set_shader_parameter("flag_color", Color(0.65, 0.65, 0.65, 1.0))
		flag_mesh.material_override = flag_smat
		_flag_mat = null

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

	# ── Colonne lumineuse verticale (visible de loin) ──
	var beam := MeshInstance3D.new()
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius    = 0.15
	beam_cyl.bottom_radius = 0.15
	beam_cyl.height        = 20.0
	beam.mesh = beam_cyl
	beam.position = Vector3(0, 10.0, 0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color    = Color(1, 1, 1, 0.0)
	beam_mat.emission_enabled = true
	beam_mat.emission        = Color(0.65, 0.65, 0.65)
	beam_mat.emission_energy_multiplier = 1.5
	beam_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode       = BaseMaterial3D.CULL_DISABLED
	beam.material_override   = beam_mat
	beam.set_meta("beam_mat", beam_mat)
	beam.name = "BeamMesh"
	add_child(beam)

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
	if flag_mesh:
		var smat := flag_mesh.material_override as ShaderMaterial
		if smat:
			smat.set_shader_parameter("flag_color", color)
	if _indicator_mat:
		_indicator_mat.albedo_color = color
		_indicator_mat.emission     = color * 0.55
	if _name_label:
		_name_label.modulate = color
	if _beacon_light:
		_beacon_light.light_color = color
	if _outer_ring_mat:
		_outer_ring_mat.emission = color * 0.9
	var beam_mi := get_node_or_null("BeamMesh") as MeshInstance3D
	if beam_mi:
		var bmat := beam_mi.get_meta("beam_mat") as StandardMaterial3D
		if bmat:
			bmat.emission = color * 0.9

func _process(delta: float) -> void:
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
	var beam_mi := get_node_or_null("BeamMesh") as MeshInstance3D
	if beam_mi:
		var bmat := beam_mi.get_meta("beam_mat") as StandardMaterial3D
		if bmat:
			var ba := (sin(_pulse_t * 0.7) * 0.5 + 0.5) * 0.12 + 0.04
			bmat.albedo_color.a = ba
