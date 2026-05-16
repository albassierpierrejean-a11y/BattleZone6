extends WeaponBase

@export var explosion_radius: float = 6.0
@export var explosion_damage: float = 180.0
@export var rocket_speed: float = 40.0
@export var rocket_scene: PackedScene

func _ready() -> void:
	weapon_name    = "RPG-7"
	damage         = 0.0
	fire_rate      = 20.0
	reload_time    = 4.0
	mag_size       = 1
	reserve_ammo   = 4
	fire_mode      = FireMode.SEMI
	bullet_spread  = 0.005
	range_max      = 500.0
	recoil_pitch   = 4.0
	recoil_yaw     = 0.5
	mesh_size      = Vector3(0.08, 0.08, 0.60)
	super._ready()

func _cast_bullet(origin: Vector3, dir: Vector3) -> void:
	var rocket := RocketProjectile.new()
	get_tree().current_scene.add_child(rocket)
	rocket.global_position = origin + dir * 0.5
	if dir.length_squared() > 0.01:
		rocket.look_at(rocket.global_position + dir, Vector3.UP)
	rocket.launch(dir, rocket_speed, explosion_radius, explosion_damage, multiplayer.get_unique_id())

func _do_instant_explosion(pos: Vector3) -> void:
	_spawn_explosion_vfx(pos, explosion_radius)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, pos)
	var hits: Array = space.intersect_shape(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var node: Node3D = collider
		var dist: float = node.global_position.distance_to(pos)
		var falloff: float = 1.0 - clamp(dist / explosion_radius, 0.0, 1.0)
		var dmg: float = explosion_damage * falloff
		if collider.has_method("take_damage"):
			collider.take_damage(dmg, multiplayer.get_unique_id())
		if collider.has_method("apply_damage"):
			collider.apply_damage(dmg, pos)

func _spawn_explosion_vfx(pos: Vector3, radius: float) -> void:
	var root := get_tree().current_scene
	# Boule de feu
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position     = pos
	fire.one_shot            = true
	fire.explosiveness       = 0.92
	fire.amount              = 50
	fire.lifetime            = 0.9
	fire.initial_velocity_min = radius * 1.5
	fire.initial_velocity_max = radius * 3.0
	fire.spread              = 90.0
	fire.gravity             = Vector3(0.0, -4.0, 0.0)
	fire.scale_amount_min    = 0.10
	fire.scale_amount_max    = 0.30
	fire.color               = Color(1.0, 0.55, 0.08, 1.0)
	fire.emitting            = true
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	# Fumée
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position    = pos
	smoke.one_shot           = true
	smoke.explosiveness      = 0.55
	smoke.amount             = 24
	smoke.lifetime           = 3.5
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 5.0
	smoke.spread             = 35.0
	smoke.gravity            = Vector3(0.0, 1.8, 0.0)
	smoke.scale_amount_min   = 0.6
	smoke.scale_amount_max   = 1.8
	smoke.color              = Color(0.18, 0.16, 0.14, 0.72)
	smoke.emitting           = true
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())
	# Flash lumineux
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = radius * 5.0
	light.light_energy    = 14.0
	light.light_color     = Color(1.0, 0.68, 0.28)
	get_tree().create_timer(0.18).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	# Tremblement caméra si le joueur est proche
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < radius * 6.0:
			cam.add_shake(clampf(1.0 - d / (radius * 6.0), 0.0, 1.0) * 0.06)
