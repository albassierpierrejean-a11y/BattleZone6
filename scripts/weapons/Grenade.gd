extends RigidBody3D
class_name Grenade

@export var fuse_time: float     = 3.5
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 120.0
@export var throw_force: float   = 15.0

var _owner_id: int = 1
var _exploded: bool = false
var _body_mat: StandardMaterial3D = null
var _fuse_elapsed: float = 0.0
var _blink_t: float = 0.0

func _ready() -> void:
	_build_visual()
	await get_tree().create_timer(fuse_time).timeout
	explode()

func _process(delta: float) -> void:
	if _exploded or not _body_mat:
		return
	_fuse_elapsed += delta
	var remaining := fuse_time - _fuse_elapsed
	if remaining < 1.2:
		_blink_t += delta * (1.0 / maxf(remaining, 0.08)) * 6.0
		var pulse := (sin(_blink_t) * 0.5 + 0.5)
		_body_mat.emission = Color(1.0, 0.12, 0.04) * pulse * 2.5
		_body_mat.emission_energy_multiplier = 1.0 + pulse * 3.0

func _build_visual() -> void:
	# Corps cylindrique de la grenade
	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.038
	cyl.bottom_radius = 0.042
	cyl.height        = 0.11
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = Color(0.12, 0.18, 0.10)
	mat.metallic         = 0.45
	mat.roughness        = 0.6
	mat.emission_enabled = true
	mat.emission         = Color(0, 0, 0)
	mi.material_override = mat
	_body_mat = mat
	add_child(mi)
	# Anneau de sécurité
	var ring_mi  := MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius    = 0.048
	ring_cyl.bottom_radius = 0.048
	ring_cyl.height        = 0.008
	ring_mi.mesh = ring_cyl
	ring_mi.position = Vector3(0, 0.04, 0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.65, 0.55, 0.30)
	ring_mat.metallic     = 0.85
	ring_mat.roughness    = 0.25
	ring_mi.material_override = ring_mat
	add_child(ring_mi)
	# Collision
	var col := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 0.045
	csh.height = 0.12
	col.shape  = csh
	add_child(col)

func throw_from(origin: Vector3, direction: Vector3, owner_id: int) -> void:
	_owner_id = owner_id
	global_position = origin
	apply_central_impulse(direction * throw_force + Vector3.UP * 4.0)

func explode() -> void:
	if _exploded:
		return
	_exploded = true
	_do_explosion()
	queue_free()

func _do_explosion() -> void:
	_spawn_explosion_vfx(global_position, explosion_radius)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	var hits: Array = space.intersect_shape(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var node: Node3D = collider
		var dist: float = (node.global_position - global_position).length()
		var falloff: float = 1.0 - clamp(dist / explosion_radius, 0.0, 1.0)
		var dmg: float = explosion_damage * falloff
		if collider.has_method("take_damage"):
			collider.take_damage(dmg, _owner_id)
		if collider.has_method("apply_damage"):
			collider.apply_damage(dmg, global_position)

func _spawn_explosion_vfx(pos: Vector3, radius: float) -> void:
	var root := get_tree().current_scene
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position      = pos
	fire.one_shot             = true
	fire.explosiveness        = 0.92
	fire.amount               = 45
	fire.lifetime             = 0.85
	fire.initial_velocity_min = radius * 1.5
	fire.initial_velocity_max = radius * 3.0
	fire.spread               = 90.0
	fire.gravity              = Vector3(0.0, -4.0, 0.0)
	fire.scale_amount_min     = 0.08
	fire.scale_amount_max     = 0.26
	fire.color                = Color(1.0, 0.55, 0.08, 1.0)
	fire.emitting             = true
	get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position     = pos
	smoke.one_shot            = true
	smoke.explosiveness       = 0.5
	smoke.amount              = 20
	smoke.lifetime            = 3.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 4.5
	smoke.spread              = 40.0
	smoke.gravity             = Vector3(0.0, 1.5, 0.0)
	smoke.scale_amount_min    = 0.5
	smoke.scale_amount_max    = 1.6
	smoke.color               = Color(0.18, 0.16, 0.14, 0.68)
	smoke.emitting            = true
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = radius * 5.0
	light.light_energy    = 12.0
	light.light_color     = Color(1.0, 0.68, 0.28)
	get_tree().create_timer(0.18).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < radius * 6.0:
			cam.add_shake(clampf(1.0 - d / (radius * 6.0), 0.0, 1.0) * 0.055)
