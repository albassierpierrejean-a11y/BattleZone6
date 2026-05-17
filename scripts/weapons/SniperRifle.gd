extends "res://scripts/weapons/WeaponBase.gd"

func _ready() -> void:
	weapon_name    = "SR-98"
	damage         = 95.0
	headshot_mult  = 3.5
	fire_rate      = 40.0
	reload_time    = 3.5
	mag_size       = 10
	reserve_ammo   = 40
	fire_mode      = FireMode.SEMI
	bullet_spread  = 0.002
	ads_spread_mult = 0.05
	range_max      = 600.0
	recoil_pitch   = 2.5
	recoil_yaw     = 0.1
	ads_fov_mult   = 0.25
	mesh_size      = Vector3(0.048, 0.085, 0.72)
	super._ready()

func _cast_bullet(origin: Vector3, dir: Vector3) -> void:
	super._cast_bullet(origin, dir)
	var cam := _get_camera()
	if cam:
		_spawn_bullet_trail(cam.global_position, dir)

func _spawn_bullet_trace(_from: Vector3, _to: Vector3) -> void:
	pass  # Sniper uses _spawn_bullet_trail with longer persistence

func _spawn_bullet_trail(from: Vector3, dir: Vector3) -> void:
	var root := get_tree().current_scene
	var to   := from + dir * range_max
	# Vérifie si la balle touche quelque chose pour raccourcir le tracé
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		to = hit.get("position", to)
	var mid    := (from + to) * 0.5
	var length := from.distance_to(to)
	var mi     := MeshInstance3D.new()
	var cyl    := CylinderMesh.new()
	cyl.top_radius    = 0.003
	cyl.bottom_radius = 0.003
	cyl.height        = length
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color       = Color(1.0, 0.95, 0.7, 0.75)
	mat.emission_enabled   = true
	mat.emission           = Color(1.0, 0.92, 0.6)
	mat.emission_energy_multiplier = 2.5
	mat.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override   = mat
	root.add_child(mi)
	mi.global_position = mid
	if length > 0.01:
		mi.look_at(to, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(mi.queue_free)
