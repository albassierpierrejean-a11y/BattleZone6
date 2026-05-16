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
	if not rocket_scene:
		_do_instant_explosion(origin + dir * 2.0)
		return
	var rocket: Node3D = rocket_scene.instantiate()
	get_tree().current_scene.add_child(rocket)
	rocket.global_position = origin + dir * 0.5
	rocket.look_at(origin + dir * 100.0, Vector3.UP)
	if rocket.has_method("launch"):
		rocket.launch(dir, rocket_speed, explosion_radius, explosion_damage, multiplayer.get_unique_id())

func _do_instant_explosion(pos: Vector3) -> void:
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
