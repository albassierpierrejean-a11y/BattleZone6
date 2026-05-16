extends VehicleBody3D
class_name VehicleBase

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var vehicle_name: String    = "Vehicle"
@export var max_speed: float        = 30.0
@export var engine_force_val: float = 800.0
@export var brake_force: float      = 20.0
@export var steer_max: float        = 0.4
@export var steer_speed: float      = 3.0
@export var max_health: float       = 500.0
@export var num_seats: int          = 2
@export var exit_offsets: Array[Vector3] = [Vector3(2, 0.5, 0), Vector3(-2, 0.5, 0)]

# ─── Signals ─────────────────────────────────────────────────────────────────
signal health_changed(current: float, max_hp: float)
signal destroyed
signal player_entered(player: Node, seat: int)
signal player_exited(player: Node, seat: int)

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var camera_mount: Node3D      = $CameraMount
@onready var camera: Camera3D         = $CameraMount/Camera3D
@onready var damage_particles: GPUParticles3D = $DamageParticles
@onready var smoke_particles: GPUParticles3D  = $SmokeParticles
@onready var engine_sound: AudioStreamPlayer3D = $EngineSound

# ─── State ───────────────────────────────────────────────────────────────────
var hp: float
var seats: Array   = []   # null = empty
var _driver: Node  = null
var _steer_input: float = 0.0
var _is_destroyed: bool = false

func _ready() -> void:
	hp = max_health
	seats.resize(num_seats)
	seats.fill(null)
	add_to_group("vehicles")
	_setup_camera()

func _setup_camera() -> void:
	if camera:
		camera.current = false

func _physics_process(delta: float) -> void:
	if _is_destroyed or not _driver:
		_apply_idle(delta)
		return
	if not _driver.is_multiplayer_authority():
		return
	_handle_drive_input(delta)
	_update_engine_sound()
	_sync_vehicle.rpc(global_position, global_rotation, linear_velocity, angular_velocity)

func _handle_drive_input(delta: float) -> void:
	var throttle := Input.get_axis("move_backward", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")
	var braking := Input.is_action_pressed("crouch")

	engine_force = throttle * engine_force_val
	if braking:
		brake = brake_force
		engine_force = 0.0
	else:
		brake = 0.0
	_steer_input = lerp(_steer_input, steer * steer_max, delta * steer_speed)
	steering = _steer_input

func _apply_idle(delta: float) -> void:
	engine_force = 0.0
	brake = 5.0
	_steer_input = lerp(_steer_input, 0.0, delta * steer_speed)
	steering = _steer_input

func _update_engine_sound() -> void:
	if not engine_sound:
		return
	var speed_ratio := linear_velocity.length() / max_speed
	engine_sound.pitch_scale = lerp(0.8, 1.8, speed_ratio)
	engine_sound.volume_db = linear_to_db(0.3 + speed_ratio * 0.7)

func try_enter(player: Node) -> bool:
	var seat := _find_empty_seat()
	if seat == -1:
		return false
	seats[seat] = player
	if seat == 0:
		_driver = player
		_activate_driver_camera(player)
	else:
		_activate_passenger_camera(player, seat)
	player_entered.emit(player, seat)
	return true

func _find_empty_seat() -> int:
	for i in seats.size():
		if seats[i] == null:
			return i
	return -1

func player_exit(player: Node) -> void:
	for i in seats.size():
		if seats[i] == player:
			seats[i] = null
			if i == 0:
				_driver = null
				_deactivate_driver_camera()
			player_exited.emit(player, i)
			return

func get_exit_position() -> Vector3:
	for i in exit_offsets.size():
		var offset: Vector3 = exit_offsets[i] if i < exit_offsets.size() else Vector3(2, 0.5, 0)
		return global_position + global_transform.basis * offset
	return global_position + Vector3(2, 1, 0)

func _activate_driver_camera(player: Node) -> void:
	if camera:
		camera.current = true

func _deactivate_driver_camera() -> void:
	if camera:
		camera.current = false

func _activate_passenger_camera(_player: Node, _seat: int) -> void:
	pass

func apply_damage(amount: float, _hit_pos: Vector3) -> void:
	take_damage(amount, 0)

func take_damage(amount: float, _source_id: int) -> void:
	if _is_destroyed:
		return
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, max_health)
	_update_damage_state()
	if hp <= 0.0:
		_destroy()

func _update_damage_state() -> void:
	var pct := hp / max_health
	if smoke_particles:
		smoke_particles.emitting = pct < 0.5
	if damage_particles:
		damage_particles.emitting = pct < 0.25

func _destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	for p in seats:
		if p and p.has_method("exit_vehicle"):
			p.exit_vehicle()
	destroyed.emit()
	_deactivate_driver_camera()
	await get_tree().create_timer(5.0).timeout
	queue_free()

@rpc("any_peer", "unreliable_ordered")
func _sync_vehicle(pos: Vector3, rot: Vector3, lin_vel: Vector3, ang_vel: Vector3) -> void:
	if _driver and _driver.is_multiplayer_authority():
		return
	global_position = pos
	global_rotation = rot
	linear_velocity = lin_vel
	angular_velocity = ang_vel

func is_occupied() -> bool:
	for s in seats:
		if s != null:
			return true
	return false

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6
