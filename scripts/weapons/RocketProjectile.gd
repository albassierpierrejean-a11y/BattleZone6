extends Node3D
class_name RocketProjectile

var _speed: float        = 40.0
var _radius: float       = 6.0
var _damage: float       = 180.0
var _owner_id: int       = 1
var _dir: Vector3        = Vector3.FORWARD
var _alive: bool         = true
var _trail: CPUParticles3D = null

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	# Corps de la roquette
	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.028
	cyl.bottom_radius = 0.035
	cyl.height        = 0.32
	mi.mesh = cyl
	mi.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.30, 0.28)
	mat.metallic     = 0.70
	mat.roughness    = 0.35
	mi.material_override = mat
	add_child(mi)

	# Tête ogive (cône = sphère aplatie)
	var tip := MeshInstance3D.new()
	var tip_sph := SphereMesh.new()
	tip_sph.radius = 0.032
	tip_sph.height = 0.075
	tip.mesh = tip_sph
	tip.position = Vector3(0, 0, -0.18)
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.50, 0.08, 0.06)
	tip_mat.metallic     = 0.40
	tip_mat.roughness    = 0.55
	tip.material_override = tip_mat
	add_child(tip)

	# Ailettes (4 petites BoxMesh)
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.28, 0.28, 0.26)
	fin_mat.metallic     = 0.65
	fin_mat.roughness    = 0.40
	for i in 4:
		var fin := MeshInstance3D.new()
		var fin_bm := BoxMesh.new()
		fin_bm.size = Vector3(0.005, 0.055, 0.08)
		fin.mesh = fin_bm
		fin.position = Vector3(0, 0, 0.12)
		fin.rotation.z = i * PI * 0.5
		fin.material_override = fin_mat
		add_child(fin)

	# Traînée de fumée / feu
	_trail = CPUParticles3D.new()
	_trail.one_shot             = false
	_trail.amount               = 18
	_trail.lifetime             = 0.55
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.8
	_trail.spread               = 12.0
	_trail.gravity              = Vector3.ZERO
	_trail.scale_amount_min     = 0.04
	_trail.scale_amount_max     = 0.14
	_trail.color                = Color(0.75, 0.42, 0.08, 0.90)
	_trail.position             = Vector3(0, 0, 0.18)
	_trail.emitting             = true
	add_child(_trail)

func launch(dir: Vector3, speed: float, radius: float, damage: float, owner_id: int) -> void:
	_dir      = dir.normalized()
	_speed    = speed
	_radius   = radius
	_damage   = damage
	_owner_id = owner_id

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var move := _dir * _speed * delta
	var space := get_world_3d().direct_space_state
	var ray   := PhysicsRayQueryParameters3D.create(global_position, global_position + move * 1.5)
	var hit   := space.intersect_ray(ray)
	if not hit.is_empty():
		_explode(hit.get("position", global_position))
		return
	global_position += move

func _explode(pos: Vector3) -> void:
	if not _alive:
		return
	_alive = false
	if _trail:
		_trail.emitting = false
	_spawn_explosion_vfx(pos)
	var space := get_world_3d().direct_space_state
	var q     := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _radius
	q.shape     = sphere
	q.transform = Transform3D(Basis.IDENTITY, pos)
	for h in space.intersect_shape(q, 32):
		var collider = h.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var dist    := (collider as Node3D).global_position.distance_to(pos)
		var falloff := 1.0 - clamp(dist / _radius, 0.0, 1.0)
		if collider.has_method("take_damage"):
			collider.take_damage(_damage * falloff, _owner_id)
		if collider.has_method("apply_damage"):
			collider.apply_damage(_damage * falloff, pos)
	queue_free()

func _spawn_explosion_vfx(pos: Vector3) -> void:
	var root := get_tree().current_scene
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position      = pos
	fire.one_shot             = true
	fire.explosiveness        = 0.92
	fire.amount               = 50
	fire.lifetime             = 0.9
	fire.initial_velocity_min = _radius * 1.5
	fire.initial_velocity_max = _radius * 3.0
	fire.spread               = 90.0
	fire.gravity              = Vector3(0.0, -4.0, 0.0)
	fire.scale_amount_min     = 0.10
	fire.scale_amount_max     = 0.30
	fire.color                = Color(1.0, 0.55, 0.08, 1.0)
	fire.emitting             = true
	get_tree().create_timer(3.5).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position     = pos
	smoke.one_shot            = true
	smoke.explosiveness       = 0.55
	smoke.amount              = 24
	smoke.lifetime            = 3.5
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 5.0
	smoke.spread              = 35.0
	smoke.gravity             = Vector3(0.0, 1.8, 0.0)
	smoke.scale_amount_min    = 0.6
	smoke.scale_amount_max    = 1.8
	smoke.color               = Color(0.18, 0.16, 0.14, 0.72)
	smoke.emitting            = true
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = _radius * 5.0
	light.light_energy    = 14.0
	light.light_color     = Color(1.0, 0.68, 0.28)
	get_tree().create_timer(0.22).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < _radius * 6.0:
			cam.add_shake(clampf(1.0 - d / (_radius * 6.0), 0.0, 1.0) * 0.06)
