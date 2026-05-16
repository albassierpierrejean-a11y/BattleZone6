extends CharacterBody3D
class_name PlayerController

# ─── Constantes ──────────────────────────────────────────────────────────────
const WALK_SPEED           := 5.0
const SPRINT_SPEED         := 8.5
const CROUCH_SPEED         := 2.5
const PRONE_SPEED          := 1.2
const ADS_MOVE_MULT        := 0.62    # plus lent en visant
const JUMP_VELOCITY        := 5.2
const GRAVITY              := 9.8
const MOUSE_SENS           := 0.002
const STAND_HEIGHT         := 1.8
const CROUCH_HEIGHT        := 1.1
const PRONE_HEIGHT         := 0.45
const VEHICLE_ENTER_RADIUS := 3.5
const LEAN_AMOUNT          := 0.25
const HEAD_LERP_SPEED      := 12.0
const COYOTE_TIME          := 0.12   # fenêtre de grâce après avoir quitté une plateforme
const JUMP_BUFFER_TIME     := 0.12   # pré-buffer du saut avant de toucher le sol
const STAMINA_MAX          := 100.0
const STAMINA_DRAIN        := 22.0   # /sec en sprint
const STAMINA_REGEN        := 14.0   # /sec hors sprint
const STAMINA_REGEN_DELAY  := 1.8    # secondes avant que la regen démarre
const STAMINA_SPRINT_MIN   := 12.0   # seuil minimum pour lancer un sprint

# ─── Énumérations ────────────────────────────────────────────────────────────
enum State { STANDING, CROUCHING, PRONE, IN_VEHICLE, DEAD }

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var team: int = GameManager.Team.ALPHA
@export var player_name: String = "Soldier"

# ─── Références nœuds ────────────────────────────────────────────────────────
@onready var head: Node3D               = $Head
@onready var camera: Camera3D           = $Head/Camera3D
@onready var capsule: CollisionShape3D  = $Capsule
@onready var weapon_manager: Node       = $Head/Camera3D/WeaponManager
@onready var health: Node               = $PlayerHealth
@onready var footstep_timer: Timer      = $FootstepTimer
@onready var interact_area: Area3D      = $InteractArea

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal died(player_id: int)
signal entered_vehicle(vehicle: Node)
signal exited_vehicle()
signal landed(impact_speed: float)
signal stamina_changed(current: float, max_val: float)

# ─── État runtime ────────────────────────────────────────────────────────────
var state: State       = State.STANDING
var current_vehicle: Node = null
var lean_input: float  = 0.0
var target_head_height := 1.6
var is_aiming: bool    = false
var peer_id: int       = 1

var _was_on_floor:    bool  = false
var _coyote_timer:    float = 0.0
var _jump_buffer:     float = 0.0
var _air_vel_y:       float = 0.0
var _is_sprinting:    bool  = false
var stamina:          float = STAMINA_MAX
var _stamina_delay:   float = 0.0

func _ready() -> void:
	peer_id = name.to_int() if name.is_valid_int() else 1
	set_multiplayer_authority(peer_id)
	add_to_group("players")
	if is_multiplayer_authority():
		add_to_group("local_player")
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		landed.connect(_on_landed)
		if footstep_timer:
			footstep_timer.timeout.connect(_on_footstep)
	else:
		camera.current = false
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if state == State.IN_VEHICLE or state == State.DEAD:
		return
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	if event.is_action_pressed("menu"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or state == State.DEAD:
		return
	if state == State.IN_VEHICLE:
		_handle_vehicle_input()
		return

	_handle_state_input()
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_lean(delta)
	_smooth_head_height(delta)
	_update_stamina(delta)
	_handle_interactions()
	_detect_landing()
	move_and_slide()
	_was_on_floor = is_on_floor()
	_sync_transform.rpc(global_position, rotation, head.rotation)

# ─── Visée souris ─────────────────────────────────────────────────────────────
func _handle_mouse_look(rel: Vector2) -> void:
	rotate_y(-rel.x * MOUSE_SENS)
	head.rotate_x(-rel.y * MOUSE_SENS)
	head.rotation.x = clamp(head.rotation.x, -PI / 2.1, PI / 2.1)

# ─── Posture ─────────────────────────────────────────────────────────────────
func _handle_state_input() -> void:
	if Input.is_action_just_pressed("crouch"):
		match state:
			State.STANDING:  _enter_crouch()
			State.CROUCHING: _enter_stand()
			State.PRONE:     _enter_crouch()
	if Input.is_action_just_pressed("prone"):
		match state:
			State.PRONE: _enter_stand()
			_:           _enter_prone()

func _enter_stand() -> void:
	state = State.STANDING
	_set_capsule_height(STAND_HEIGHT)
	target_head_height = 1.6

func _enter_crouch() -> void:
	state = State.CROUCHING
	_set_capsule_height(CROUCH_HEIGHT)
	target_head_height = 0.9

func _enter_prone() -> void:
	state = State.PRONE
	_set_capsule_height(PRONE_HEIGHT)
	target_head_height = 0.3

func _set_capsule_height(h: float) -> void:
	var shape := capsule.shape as CapsuleShape3D
	shape.height = h
	capsule.position.y = h * 0.5

# ─── Physique ────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		_air_vel_y = velocity.y
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# Fenêtre coyote
	if _was_on_floor and not is_on_floor():
		_coyote_timer = COYOTE_TIME
	elif _coyote_timer > 0.0:
		_coyote_timer -= delta

func _handle_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	is_aiming = Input.is_action_pressed("aim")

	var can_sprint := (state == State.STANDING
		and not is_aiming
		and stamina >= STAMINA_SPRINT_MIN
		and input.y < -0.2)
	_is_sprinting = Input.is_action_pressed("sprint") and can_sprint

	var speed := _get_speed(_is_sprinting) * (ADS_MOVE_MULT if is_aiming else 1.0)
	var dir   := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	if is_on_floor():
		# Saut — avec support coyote + buffer
		var jumpable := (is_on_floor() or _coyote_timer > 0.0) and state == State.STANDING
		if (Input.is_action_just_pressed("jump") or _jump_buffer > 0.0) and jumpable:
			velocity.y       = JUMP_VELOCITY
			_coyote_timer    = 0.0
			_jump_buffer     = 0.0
		velocity.x = lerp(velocity.x, dir.x * speed, delta * 13.0)
		velocity.z = lerp(velocity.z, dir.z * speed, delta * 13.0)
	else:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER_TIME
		if _jump_buffer > 0.0:
			_jump_buffer -= delta
		velocity.x = lerp(velocity.x, dir.x * speed, delta * 3.2)
		velocity.z = lerp(velocity.z, dir.z * speed, delta * 3.2)

	# Cadence des pas en fonction de l'état
	if footstep_timer:
		if is_on_floor() and velocity.length() > 0.6:
			var rate := 0.32 if _is_sprinting else (0.48 if state == State.STANDING else 0.6)
			if footstep_timer.wait_time != rate:
				footstep_timer.wait_time = rate
			if footstep_timer.is_stopped():
				footstep_timer.start()
		else:
			footstep_timer.stop()

func _get_speed(sprinting: bool) -> float:
	match state:
		State.CROUCHING: return CROUCH_SPEED
		State.PRONE:     return PRONE_SPEED
	return SPRINT_SPEED if sprinting else WALK_SPEED

# ─── Endurance ───────────────────────────────────────────────────────────────
func _update_stamina(delta: float) -> void:
	if _is_sprinting:
		_stamina_delay = STAMINA_REGEN_DELAY
		var old := stamina
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina != old:
			stamina_changed.emit(stamina, STAMINA_MAX)
	else:
		if _stamina_delay > 0.0:
			_stamina_delay -= delta
		else:
			var old := stamina
			stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)
			if stamina != old:
				stamina_changed.emit(stamina, STAMINA_MAX)

# ─── Inclinaison latérale ────────────────────────────────────────────────────
func _handle_lean(delta: float) -> void:
	lean_input = float(Input.is_action_pressed("lean_right")) - float(Input.is_action_pressed("lean_left"))
	head.rotation.z   = lerp(head.rotation.z,   -lean_input * 0.2,  delta * HEAD_LERP_SPEED)
	head.position.x   = lerp(head.position.x,    lean_input * LEAN_AMOUNT, delta * HEAD_LERP_SPEED)

func _smooth_head_height(delta: float) -> void:
	head.position.y = lerp(head.position.y, target_head_height, delta * HEAD_LERP_SPEED)

# ─── Détection d'atterrissage ─────────────────────────────────────────────────
func _detect_landing() -> void:
	if not _was_on_floor and is_on_floor() and _air_vel_y < -2.0:
		landed.emit(absf(_air_vel_y))

func _on_landed(impact_speed: float) -> void:
	if camera and camera.has_method("on_landed"):
		camera.on_landed(impact_speed)

# ─── Pas ─────────────────────────────────────────────────────────────────────
func _on_footstep() -> void:
	if AudioManager.has_method("play_footstep"):
		AudioManager.play_footstep(global_position, state)

# ─── Interactions ─────────────────────────────────────────────────────────────
func _handle_interactions() -> void:
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("vehicle_exit"):
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("vehicles") and state != State.IN_VEHICLE:
				_try_enter_vehicle(body)
				return

func _handle_vehicle_input() -> void:
	if Input.is_action_just_pressed("vehicle_exit"):
		exit_vehicle()

func _try_enter_vehicle(vehicle: Node) -> void:
	if vehicle.has_method("try_enter") and vehicle.try_enter(self):
		state = State.IN_VEHICLE
		current_vehicle = vehicle
		set_collision_layer_value(1, false)
		visible = false
		entered_vehicle.emit(vehicle)

func exit_vehicle() -> void:
	if not current_vehicle:
		return
	if current_vehicle.has_method("player_exit"):
		current_vehicle.player_exit(self)
	var exit_pos: Vector3 = current_vehicle.get_exit_position()
	current_vehicle = null
	state = State.STANDING
	global_position = exit_pos
	set_collision_layer_value(1, true)
	visible = true
	exited_vehicle.emit()

# ─── Combat ──────────────────────────────────────────────────────────────────
func take_damage(amount: float, source_id: int) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount, source_id)

func die(killer_id: int) -> void:
	state = State.DEAD
	visible = false
	died.emit(peer_id)
	if multiplayer.is_server():
		GameManager.report_kill.rpc(killer_id, peer_id)

func respawn(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	state    = State.STANDING
	stamina  = STAMINA_MAX
	visible  = true
	_enter_stand()
	health.reset()

# ─── Accesseurs ──────────────────────────────────────────────────────────────
func is_sprinting() -> bool:
	return _is_sprinting

# ─── Réseau ──────────────────────────────────────────────────────────────────
@rpc("any_peer", "unreliable_ordered")
func _sync_transform(pos: Vector3, rot: Vector3, head_rot: Vector3) -> void:
	if is_multiplayer_authority():
		return
	global_position = pos
	rotation        = rot
	head.rotation   = head_rot
