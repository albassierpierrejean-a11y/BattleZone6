extends VehicleBase

# ─── Constants ───────────────────────────────────────────────────────────────
const TURRET_ROTATE_SPEED := 1.2
const CANNON_PITCH_MIN    := -0.2
const CANNON_PITCH_MAX    := 0.35
const CANNON_RELOAD_TIME  := 4.0
const CANNON_DAMAGE       := 600.0
const CANNON_RADIUS       := 8.0
const CANNON_RANGE        := 500.0
const MOUSE_SENS          := 0.002

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var turret: Node3D     = $Turret
@onready var cannon: Node3D     = $Turret/Cannon
@onready var barrel_tip: Marker3D = $Turret/Cannon/BarrelTip
@onready var cannon_sound: AudioStreamPlayer3D = $CannonSound
@onready var reload_bar: ProgressBar = $TurretHUD/ReloadBar

# ─── State ───────────────────────────────────────────────────────────────────
var _cannon_cooldown: float = 0.0
var _turret_yaw: float = 0.0
var _cannon_pitch: float = 0.0

func _ready() -> void:
	vehicle_name     = "M1A2 Abrams"
	max_speed        = 14.0
	engine_force_val = 1200.0
	brake_force      = 30.0
	steer_max        = 0.25
	max_health       = 1200.0
	num_seats        = 2
	exit_offsets     = [Vector3(0, 1.5, -2), Vector3(0, 1.5, 1.5)]
	super._ready()

func _input(event: InputEvent) -> void:
	if not _driver or not _driver.is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		_turret_yaw   -= event.relative.x * MOUSE_SENS
		_cannon_pitch -= event.relative.y * MOUSE_SENS
		_cannon_pitch = clamp(_cannon_pitch, CANNON_PITCH_MIN, CANNON_PITCH_MAX)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_cannon_cooldown = maxf(_cannon_cooldown - delta, 0.0)
	if turret:
		turret.rotation.y = lerp_angle(turret.rotation.y, _turret_yaw, delta * TURRET_ROTATE_SPEED * 5.0)
	if cannon:
		cannon.rotation.x = lerp(cannon.rotation.x, _cannon_pitch, delta * 8.0)
	if reload_bar:
		reload_bar.value = 1.0 - (_cannon_cooldown / CANNON_RELOAD_TIME)
	if _driver and _driver.is_multiplayer_authority():
		if Input.is_action_just_pressed("fire"):
			_fire_cannon()

func _fire_cannon() -> void:
	if _cannon_cooldown > 0.0:
		return
	_cannon_cooldown = CANNON_RELOAD_TIME
	if cannon_sound and cannon_sound.stream:
		cannon_sound.play()
	var dir := -cannon.global_transform.basis.z
	_cannon_explosion(barrel_tip.global_position + dir * 5.0, dir)

func _cannon_explosion(origin: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + dir * CANNON_RANGE)
	ray.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	var pos: Vector3 = origin + dir * CANNON_RANGE
	if not hit.is_empty():
		pos = hit["position"]
	_spawn_cannon_vfx(pos)
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CANNON_RADIUS
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, pos)
	var hits: Array = space.intersect_shape(q, 32)
	for h in hits:
		var collider = h.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var node: Node3D = collider
		var dist: float = (node.global_position - pos).length()
		var falloff: float = 1.0 - clamp(dist / CANNON_RADIUS, 0.0, 1.0)
		var dmg: float = CANNON_DAMAGE * falloff
		if collider.has_method("take_damage"):
			collider.take_damage(dmg, multiplayer.get_unique_id())
		if collider.has_method("apply_damage"):
			collider.apply_damage(dmg, pos)

func _spawn_cannon_vfx(pos: Vector3) -> void:
	var root := get_tree().current_scene
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position      = pos
	fire.one_shot             = true
	fire.explosiveness        = 0.94
	fire.amount               = 70
	fire.lifetime             = 1.1
	fire.initial_velocity_min = CANNON_RADIUS * 2.0
	fire.initial_velocity_max = CANNON_RADIUS * 4.5
	fire.spread               = 90.0
	fire.gravity              = Vector3(0.0, -5.0, 0.0)
	fire.scale_amount_min     = 0.14
	fire.scale_amount_max     = 0.42
	fire.color                = Color(1.0, 0.55, 0.08, 1.0)
	fire.emitting             = true
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position     = pos
	smoke.one_shot            = true
	smoke.explosiveness       = 0.6
	smoke.amount              = 30
	smoke.lifetime            = 5.0
	smoke.initial_velocity_min = 2.0
	smoke.initial_velocity_max = 7.0
	smoke.spread              = 40.0
	smoke.gravity             = Vector3(0.0, 2.0, 0.0)
	smoke.scale_amount_min    = 0.8
	smoke.scale_amount_max    = 2.5
	smoke.color               = Color(0.16, 0.14, 0.12, 0.65)
	smoke.emitting            = true
	get_tree().create_timer(7.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = CANNON_RADIUS * 7.0
	light.light_energy    = 18.0
	light.light_color     = Color(1.0, 0.65, 0.25)
	get_tree().create_timer(0.22).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < CANNON_RADIUS * 10.0:
			cam.add_shake(clampf(1.0 - d / (CANNON_RADIUS * 10.0), 0.0, 1.0) * 0.06)
