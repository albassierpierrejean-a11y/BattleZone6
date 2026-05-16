extends RigidBody3D
class_name Helicopter

# ─── Constants ───────────────────────────────────────────────────────────────
const LIFT_FORCE          := 18.0
const TILT_FORCE          := 12.0
const YAW_TORQUE          := 4.0
const MAX_TILT            := 0.45
const TILT_LERP           := 5.0
const MOUSE_SENS          := 0.002
const GUN_FIRE_RATE       := 900.0
const GUN_DAMAGE          := 18.0
const GUN_RANGE           := 200.0
const MAX_HEALTH          := 400.0

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var num_seats: int = 2

# ─── Signals ─────────────────────────────────────────────────────────────────
signal health_changed(current: float, max_hp: float)
signal destroyed

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var rotor: Node3D             = $Rotor
@onready var camera_mount: Node3D     = $CameraMount
@onready var camera: Camera3D         = $CameraMount/Camera3D
@onready var gun_tip: Marker3D        = $GunTip
@onready var engine_sound: AudioStreamPlayer3D = $EngineSound
@onready var gun_sound: AudioStreamPlayer3D    = $GunSound

# ─── State ───────────────────────────────────────────────────────────────────
var hp: float = MAX_HEALTH
var seats: Array = []
var _pilot: Node = null
var _target_tilt: Vector2 = Vector2.ZERO
var _gun_cooldown: float = 0.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _engines_on: bool = false

func _ready() -> void:
	seats.resize(num_seats)
	seats.fill(null)
	add_to_group("vehicles")

func _input(event: InputEvent) -> void:
	if not _pilot or not _pilot.is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		_cam_yaw   -= event.relative.x * MOUSE_SENS
		_cam_pitch -= event.relative.y * MOUSE_SENS
		_cam_pitch = clamp(_cam_pitch, -0.6, 0.4)

func _physics_process(delta: float) -> void:
	_gun_cooldown = maxf(_gun_cooldown - delta, 0.0)
	_spin_rotor(delta)
	if not _pilot or not _pilot.is_multiplayer_authority():
		return
	_handle_flight(delta)
	_update_camera(delta)
	if Input.is_action_pressed("fire"):
		_fire_gun()
	if Input.is_action_just_pressed("vehicle_exit"):
		_pilot.exit_vehicle()

func _handle_flight(delta: float) -> void:
	var collective := Input.get_axis("crouch", "jump")
	var cyclic_x   := Input.get_axis("move_left", "move_right")
	var cyclic_z   := Input.get_axis("move_forward", "move_backward")
	var pedal      := Input.get_axis("lean_left", "lean_right")

	# Lift
	var lift := (collective + 1.0) * 0.5 * LIFT_FORCE * mass
	apply_central_force(Vector3.UP * lift)

	# Tilt (cyclic)
	_target_tilt = Vector2(cyclic_x, cyclic_z)
	var current_tilt := Vector2(rotation.z, rotation.x)
	var tilt_diff    := _target_tilt * MAX_TILT - current_tilt
	apply_torque(Vector3(tilt_diff.y, 0, -tilt_diff.x) * TILT_FORCE * mass * delta * 10.0)

	# Yaw (pedal)
	apply_torque(Vector3.UP * pedal * YAW_TORQUE * mass * delta * 10.0)

	# Drag
	linear_velocity  = linear_velocity.lerp(Vector3.ZERO, delta * 0.5)
	angular_velocity = angular_velocity.lerp(Vector3.ZERO, delta * 2.0)

func _spin_rotor(delta: float) -> void:
	if rotor:
		rotor.rotate_y(delta * TAU * 4.0)

func _update_camera(delta: float) -> void:
	if camera_mount:
		camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, _cam_yaw, delta * 8.0)
		camera_mount.rotation.x = lerp(camera_mount.rotation.x, _cam_pitch, delta * 8.0)

func _fire_gun() -> void:
	if _gun_cooldown > 0.0 or not gun_tip:
		return
	_gun_cooldown = 60.0 / GUN_FIRE_RATE
	if gun_sound and gun_sound.stream:
		gun_sound.play()
	var dir := -gun_tip.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(gun_tip.global_position, gun_tip.global_position + dir * GUN_RANGE)
	ray.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(GUN_DAMAGE, multiplayer.get_unique_id())

func try_enter(player: Node) -> bool:
	for i in seats.size():
		if seats[i] == null:
			seats[i] = player
			if i == 0:
				_pilot = player
				if camera:
					camera.current = true
			return true
	return false

func player_exit(player: Node) -> void:
	for i in seats.size():
		if seats[i] == player:
			seats[i] = null
			if i == 0:
				_pilot = null
				if camera:
					camera.current = false
			return

func get_exit_position() -> Vector3:
	return global_position + Vector3(3, 0, 0)

func apply_damage(amount: float, _pos: Vector3) -> void:
	take_damage(amount, 0)

func take_damage(amount: float, _source: int) -> void:
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, MAX_HEALTH)
	if hp <= 0.0:
		_destroy()

func _destroy() -> void:
	for s in seats:
		if s and s.has_method("exit_vehicle"):
			s.exit_vehicle()
	destroyed.emit()
	await get_tree().create_timer(0.5).timeout
	queue_free()
