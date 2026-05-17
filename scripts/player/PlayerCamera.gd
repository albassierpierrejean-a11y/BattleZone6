extends Camera3D
class_name PlayerCamera

# ─── Constantes ──────────────────────────────────────────────────────────────
const FOV_DEFAULT     := 75.0
const FOV_ADS         := 45.0
const FOV_SPRINT      := 86.0
const FOV_LERP        := 10.0

const BOB_FREQ        := 2.2
const BOB_AMP         := 0.036

const RECOIL_RECOVER  := 9.0
const SHAKE_DECAY     := 5.5

const SPRINT_TILT     := 0.032   # radians
const SPRINT_TILT_SPD := 8.0

const LAND_RECOVER    := 12.0

const BREATH_FREQ     := 0.38    # Hz
const BREATH_AMP      := 0.0008

# ─── Décalages de position (composés en fin de frame) ────────────────────────
var _bob_x:    float = 0.0
var _bob_y:    float = 0.0
var _land_y:   float = 0.0   # négatif = choc vers le bas, retour à 0
var _shake_x:  float = 0.0
var _shake_y:  float = 0.0

# ─── État de rotation ────────────────────────────────────────────────────────
var _bob_t:         float   = 0.0
var _breath_t:      float   = 0.0
var _recoil:        Vector2 = Vector2.ZERO  # magnitude du recul actuel
var _recoil_applied:Vector2 = Vector2.ZERO  # ce qu'on a déjà appliqué cette frame
var _shake:         float   = 0.0
var _is_aiming:     bool    = false

var _player_cache:  PlayerController = null
var _wm_cache:      WeaponManager    = null
var _env_cache:     WorldEnvironment = null

func _ready() -> void:
	fov = FOV_DEFAULT
	await get_tree().process_frame
	_player_cache = _get_player()
	if _player_cache:
		_wm_cache = _player_cache.get_node_or_null("Head/Camera3D/WeaponManager") as WeaponManager
	_env_cache = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment

func _process(delta: float) -> void:
	var player := _player_cache
	if not player or not player.is_multiplayer_authority():
		return
	var head := get_parent() as Node3D

	_update_fov(delta, player)
	_update_bob(delta, player)
	_update_sprint_tilt(delta, player)
	_update_land(delta)
	_update_breath(delta, head)
	_update_recoil(delta, head)
	_update_shake(delta)
	_compose_position()

# ─── Champ de vision ─────────────────────────────────────────────────────────
func _update_fov(delta: float, player: PlayerController) -> void:
	_is_aiming = Input.is_action_pressed("aim")
	var target: float
	if _is_aiming:
		target = FOV_ADS
	elif player.is_sprinting():
		target = FOV_SPRINT
	else:
		target = FOV_DEFAULT
	fov = lerpf(fov, target, delta * FOV_LERP)
	_update_dof(delta, player)

# ─── Oscillation de la tête ──────────────────────────────────────────────────
func _update_bob(delta: float, player: PlayerController) -> void:
	var spd    := player.velocity.length()
	var moving := spd > 0.5 and player.is_on_floor()
	if moving:
		var freq_scale: float = 1.0 + clampf((spd - 5.0) / 6.0, 0.0, 0.5)
		var state_scale: float = 1.0 if player.state == PlayerController.State.STANDING else 0.72
		_bob_t += delta * BOB_FREQ * freq_scale * state_scale
	else:
		_bob_t = lerpf(_bob_t, 0.0, delta * 7.0)

	var ads: float = 0.22 if _is_aiming else 1.0
	_bob_y = lerpf(_bob_y, sin(_bob_t * TAU)  * BOB_AMP * ads,        delta * 10.0)
	_bob_x = lerpf(_bob_x, cos(_bob_t * PI)   * BOB_AMP * 0.42 * ads, delta * 10.0)

# ─── Inclinaison au sprint ────────────────────────────────────────────────────
func _update_sprint_tilt(delta: float, player: PlayerController) -> void:
	var target: float = SPRINT_TILT if player.is_sprinting() else 0.0
	rotation.z = lerpf(rotation.z, target, delta * SPRINT_TILT_SPD)

# ─── Choc d'atterrissage ─────────────────────────────────────────────────────
func _update_land(delta: float) -> void:
	_land_y = lerpf(_land_y, 0.0, delta * LAND_RECOVER)

func on_landed(impact_speed: float) -> void:
	_land_y = -clampf(impact_speed / 14.0, 0.1, 1.0) * 0.055
	if impact_speed > 7.0:
		add_shake(impact_speed * 0.003)

# ─── Respiration en visée — delta-based pour éviter la dérive ────────────────
func _update_breath(delta: float, head: Node3D) -> void:
	if not _is_aiming or not head:
		_breath_t = 0.0
		return
	var prev_t := _breath_t
	_breath_t += delta * BREATH_FREQ * TAU
	# On n'applique que le DELTA chaque frame — oscillation sans accumulation
	head.rotation.x += (sin(_breath_t * 0.5) - sin(prev_t * 0.5)) * BREATH_AMP
	head.rotation.y += (cos(_breath_t)        - cos(prev_t))       * BREATH_AMP * 0.5

# ─── Recul — décalage suivi appliqué à la tête ───────────────────────────────
func _update_recoil(delta: float, head: Node3D) -> void:
	if not head:
		return
	# Retire ce qu'on a appliqué la frame précédente
	head.rotation.x -= _recoil_applied.y
	head.rotation.y -= _recoil_applied.x
	# Diminution du recul vers zéro
	_recoil = _recoil.lerp(Vector2.ZERO, delta * RECOIL_RECOVER)
	# Ré-applique le recul actuel (diminué)
	_recoil_applied = _recoil
	head.rotation.x += _recoil_applied.y
	head.rotation.y += _recoil_applied.x
	head.rotation.x  = clampf(head.rotation.x, -PI / 2.1, PI / 2.1)

# ─── Tremblement caméra ──────────────────────────────────────────────────────
func _update_shake(delta: float) -> void:
	if _shake > 0.005:
		_shake_x = randf_range(-1.0, 1.0) * _shake
		_shake_y = randf_range(-1.0, 1.0) * _shake
		_shake   = lerpf(_shake, 0.0, delta * SHAKE_DECAY)
	else:
		_shake_x = lerpf(_shake_x, 0.0, delta * 12.0)
		_shake_y = lerpf(_shake_y, 0.0, delta * 12.0)

# ─── Composition des décalages de position ───────────────────────────────────
func _compose_position() -> void:
	position.x = _bob_x + _shake_x
	position.y = _bob_y + _land_y + _shake_y

# ─── API publique ─────────────────────────────────────────────────────────────
func add_recoil(pitch: float, yaw: float) -> void:
	_recoil += Vector2(yaw, -pitch)

func add_shake(intensity: float) -> void:
	_shake = minf(_shake + intensity, 0.06)

func is_aiming() -> bool:
	return _is_aiming

# ─── Utilitaire ──────────────────────────────────────────────────────────────
func _update_dof(_delta: float, _player: PlayerController) -> void:
	var wm := _wm_cache
	var is_sniper := wm != null and wm.get_current_weapon() != null and wm.get_current_weapon().weapon_name == "SR-98"
	var want_dof  := _is_aiming and is_sniper
	if not _env_cache or not _env_cache.environment:
		return
	var e := _env_cache.environment
	if want_dof and not e.dof_blur_far_enabled:
		e.dof_blur_far_enabled     = true
		e.dof_blur_far_distance    = 35.0
		e.dof_blur_far_transition  = 18.0
		e.dof_blur_far_amount      = 0.04
		e.dof_blur_near_enabled    = true
		e.dof_blur_near_distance   = 1.2
		e.dof_blur_near_transition = 0.5
		e.dof_blur_near_amount     = 0.02
	elif not want_dof and e.dof_blur_far_enabled:
		e.dof_blur_far_enabled  = false
		e.dof_blur_near_enabled = false

func _get_player() -> PlayerController:
	var n := get_parent()
	while n:
		if n is PlayerController:
			return n as PlayerController
		n = n.get_parent()
	return null
