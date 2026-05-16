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

func _ready() -> void:
	fov = FOV_DEFAULT

func _process(delta: float) -> void:
	var player := _get_player()
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
func _get_player() -> PlayerController:
	var n := get_parent()
	while n:
		if n is PlayerController:
			return n as PlayerController
		n = n.get_parent()
	return null
