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

var _exhaust: CPUParticles3D = null
var _track_timer: float = 0.0

func _ready() -> void:
	hp = max_health
	seats.resize(num_seats)
	seats.fill(null)
	add_to_group("vehicles")
	_setup_camera()
	_build_exhaust()

func _setup_camera() -> void:
	if camera:
		camera.current = false

func _build_exhaust() -> void:
	_exhaust = CPUParticles3D.new()
	_exhaust.name             = "ExhaustSmoke"
	_exhaust.one_shot         = false
	_exhaust.amount           = 8
	_exhaust.lifetime         = 1.2
	_exhaust.initial_velocity_min = 0.5
	_exhaust.initial_velocity_max = 1.8
	_exhaust.spread           = 18.0
	_exhaust.gravity          = Vector3(0.0, 1.2, 0.0)
	_exhaust.scale_amount_min = 0.12
	_exhaust.scale_amount_max = 0.42
	_exhaust.color            = Color(0.22, 0.20, 0.18, 0.55)
	_exhaust.position         = Vector3(0, 0.8, -2.8)
	_exhaust.emitting         = false
	add_child(_exhaust)

func _physics_process(delta: float) -> void:
	if _is_destroyed or not _driver:
		_apply_idle(delta)
		return
	if not _driver.is_multiplayer_authority():
		return
	_handle_drive_input(delta)
	_update_engine_sound()
	_spawn_tire_tracks(delta)
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
	if _exhaust:
		_exhaust.emitting = speed_ratio > 0.05

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
	_spawn_destruction_vfx()
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _spawn_tire_tracks(delta: float) -> void:
	var spd := linear_velocity.length()
	if spd < 0.5:
		return
	_track_timer -= delta
	if _track_timer > 0.0:
		return
	_track_timer = 0.25
	var root := get_tree().current_scene
	if not root:
		return
	var space := get_world_3d().direct_space_state
	# Cast ray down from vehicle center
	var from := global_position + Vector3.UP * 0.5
	var ray  := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0)
	ray.exclude = [get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return
	var pos := hit["position"]
	var decal := Decal.new()
	root.add_child(decal)
	decal.global_position = pos + Vector3.UP * 0.01
	decal.size     = Vector3(1.6, 0.1, 0.8)
	decal.modulate = Color(0.12, 0.10, 0.08, 0.65)
	decal.rotation.y = global_rotation.y
	get_tree().create_timer(18.0).timeout.connect(func(): if is_instance_valid(decal): decal.queue_free())

func _spawn_destruction_vfx() -> void:
	var root := get_tree().current_scene
	var pos  := global_position + Vector3.UP * 1.0
	# Big fireball
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position      = pos
	fire.one_shot             = true
	fire.explosiveness        = 0.96
	fire.amount               = 80
	fire.lifetime             = 1.4
	fire.initial_velocity_min = 8.0
	fire.initial_velocity_max = 22.0
	fire.spread               = 90.0
	fire.gravity              = Vector3(0.0, -6.0, 0.0)
	fire.scale_amount_min     = 0.20
	fire.scale_amount_max     = 0.70
	fire.color                = Color(1.0, 0.48, 0.06, 1.0)
	fire.emitting             = true
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	# Heavy black smoke
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position     = pos
	smoke.one_shot            = false
	smoke.explosiveness       = 0.1
	smoke.amount              = 40
	smoke.lifetime            = 6.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 6.0
	smoke.spread              = 25.0
	smoke.gravity             = Vector3(0.0, 2.0, 0.0)
	smoke.scale_amount_min    = 1.0
	smoke.scale_amount_max    = 3.5
	smoke.color               = Color(0.08, 0.07, 0.06, 0.80)
	smoke.emitting            = true
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())
	# Flash light
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = 20.0
	light.light_energy    = 25.0
	light.light_color     = Color(1.0, 0.62, 0.22)
	get_tree().create_timer(0.25).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	# Camera shake
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < 60.0:
			cam.add_shake(clampf(1.0 - d / 60.0, 0.0, 1.0) * 0.08)

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
