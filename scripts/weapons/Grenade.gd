extends RigidBody3D
class_name Grenade

enum Type { FRAG, SMOKE, FLASH, STUN, THERMITE }

@export var fuse_time:        float = 3.5
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 120.0
@export var throw_force:      float = 15.0

var grenade_type: Type = Type.FRAG
var _owner_id:    int  = 1
var _exploded:    bool = false
var _body_mat:    StandardMaterial3D = null
var _fuse_elapsed: float = 0.0
var _blink_t:      float = 0.0

func _ready() -> void:
	_build_visual()
	await get_tree().create_timer(fuse_time).timeout
	if not _exploded:
		explode()

func _process(delta: float) -> void:
	if _exploded or not _body_mat:
		return
	_fuse_elapsed += delta
	var remaining := fuse_time - _fuse_elapsed
	if remaining < 1.2:
		_blink_t += delta * (1.0 / maxf(remaining, 0.08)) * 6.0
		var pulse: float = sin(_blink_t) * 0.5 + 0.5
		var blink_col: Color = _blink_color()
		_body_mat.emission = blink_col * pulse * 2.5
		_body_mat.emission_energy_multiplier = 1.0 + pulse * 3.0

func _blink_color() -> Color:
	match grenade_type:
		Type.SMOKE:    return Color(0.5, 0.5, 0.5)
		Type.FLASH:    return Color(1.0, 1.0, 0.8)
		Type.STUN:     return Color(0.2, 0.6, 1.0)
		Type.THERMITE: return Color(1.0, 0.4, 0.0)
		_:             return Color(1.0, 0.12, 0.04)

func _build_visual() -> void:
	var body_col := _get_body_color()
	var mi  := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.038
	cyl.bottom_radius = 0.042
	cyl.height        = 0.11
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = body_col
	mat.metallic         = 0.45
	mat.roughness        = 0.60
	mat.emission_enabled = true
	mat.emission         = Color(0, 0, 0)
	mi.material_override = mat
	_body_mat = mat
	add_child(mi)
	# Anneau de sécurité
	var ring    := MeshInstance3D.new()
	var rcyl    := CylinderMesh.new()
	rcyl.top_radius    = 0.048
	rcyl.bottom_radius = 0.048
	rcyl.height        = 0.008
	ring.mesh = rcyl
	ring.position = Vector3(0, 0.04, 0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.65, 0.55, 0.30)
	rmat.metallic     = 0.85
	rmat.roughness    = 0.25
	ring.material_override = rmat
	add_child(ring)
	# Collision
	var col := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 0.045
	csh.height = 0.12
	col.shape  = csh
	add_child(col)

func _get_body_color() -> Color:
	match grenade_type:
		Type.SMOKE:    return Color(0.30, 0.30, 0.30)
		Type.FLASH:    return Color(0.80, 0.75, 0.50)
		Type.STUN:     return Color(0.12, 0.18, 0.42)
		Type.THERMITE: return Color(0.50, 0.20, 0.05)
		_:             return Color(0.12, 0.18, 0.10)

func throw_from(origin: Vector3, direction: Vector3, owner_id: int) -> void:
	_owner_id = owner_id
	global_position = origin
	apply_central_impulse(direction * throw_force + Vector3.UP * 4.0)
	apply_torque_impulse(Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)) * 0.4)

func explode() -> void:
	if _exploded:
		return
	_exploded = true
	match grenade_type:
		Type.FRAG:     _do_frag()
		Type.SMOKE:    _do_smoke()
		Type.FLASH:    _do_flash()
		Type.STUN:     _do_stun()
		Type.THERMITE: _do_thermite()
	queue_free()

# ─────────────────────────────────────────────────────────────────────────────
# TYPES
# ─────────────────────────────────────────────────────────────────────────────
func _do_frag() -> void:
	var pos := global_position
	_deal_radius_damage(pos, explosion_radius, explosion_damage)
	_spawn_explosion_vfx(pos, explosion_radius)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < explosion_radius * 6.0:
			cam.add_shake(clampf(1.0 - d / (explosion_radius * 6.0), 0.0, 1.0) * 0.055)

func _do_smoke() -> void:
	var pos  := global_position
	var root := get_tree().current_scene
	# Nuage persistant
	var cloud := CPUParticles3D.new()
	root.add_child(cloud)
	cloud.global_position       = pos
	cloud.one_shot              = false
	cloud.amount                = 40
	cloud.lifetime              = 4.0
	cloud.initial_velocity_min  = 1.0
	cloud.initial_velocity_max  = 3.5
	cloud.spread                = 60.0
	cloud.gravity               = Vector3(0.0, 0.5, 0.0)
	cloud.scale_amount_min      = 1.2
	cloud.scale_amount_max      = 3.5
	cloud.color                 = Color(0.55, 0.58, 0.52, 0.60)
	cloud.emitting              = true
	# Pop initial
	var pop := CPUParticles3D.new()
	root.add_child(pop)
	pop.global_position      = pos
	pop.one_shot             = true
	pop.explosiveness        = 0.95
	pop.amount               = 18
	pop.lifetime             = 1.0
	pop.initial_velocity_min = 4.0
	pop.initial_velocity_max = 9.0
	pop.spread               = 70.0
	pop.gravity              = Vector3(0.0, 0.8, 0.0)
	pop.scale_amount_min     = 0.5
	pop.scale_amount_max     = 1.8
	pop.color                = Color(0.60, 0.62, 0.58, 0.75)
	pop.emitting             = true
	# Petite lumière verte
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = 4.0
	light.light_energy    = 2.0
	light.light_color     = Color(0.55, 0.85, 0.55)
	get_tree().create_timer(10.0).timeout.connect(func():
		if is_instance_valid(cloud): cloud.queue_free()
		if is_instance_valid(pop):   pop.queue_free()
		if is_instance_valid(light): light.queue_free()
	)

func _do_flash() -> void:
	var pos  := global_position
	var root := get_tree().current_scene
	# Lumière blanche intense très brève
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = explosion_radius * 8.0
	light.light_energy    = 60.0
	light.light_color     = Color(1.0, 0.97, 0.90)
	# Particules de flash
	var burst := CPUParticles3D.new()
	root.add_child(burst)
	burst.global_position      = pos
	burst.one_shot             = true
	burst.explosiveness        = 1.0
	burst.amount               = 30
	burst.lifetime             = 0.25
	burst.initial_velocity_min = explosion_radius * 3.0
	burst.initial_velocity_max = explosion_radius * 6.0
	burst.spread               = 90.0
	burst.gravity              = Vector3.ZERO
	burst.scale_amount_min     = 0.08
	burst.scale_amount_max     = 0.20
	burst.color                = Color(1.0, 0.98, 0.88, 1.0)
	burst.emitting             = true
	# Flash sur la caméra du joueur local
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(pos)
		if d < explosion_radius * 5.0:
			var intensity: float = clampf(1.0 - d / (explosion_radius * 5.0), 0.0, 1.0)
			if cam.has_method("add_shake"):
				cam.add_shake(intensity * 0.03)
			_flash_screen(intensity)
	get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())
	# Stun léger des ennemis proches
	_apply_stun_area(pos, explosion_radius * 3.0, 2.5)

func _do_stun() -> void:
	var pos  := global_position
	var root := get_tree().current_scene
	# Arc électrique
	var arcs := CPUParticles3D.new()
	root.add_child(arcs)
	arcs.global_position      = pos
	arcs.one_shot             = true
	arcs.explosiveness        = 0.9
	arcs.amount               = 25
	arcs.lifetime             = 0.6
	arcs.initial_velocity_min = explosion_radius * 1.5
	arcs.initial_velocity_max = explosion_radius * 3.0
	arcs.spread               = 90.0
	arcs.gravity              = Vector3.ZERO
	arcs.scale_amount_min     = 0.04
	arcs.scale_amount_max     = 0.12
	arcs.color                = Color(0.4, 0.7, 1.0, 0.9)
	arcs.emitting             = true
	# Lumière bleue
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = explosion_radius * 4.0
	light.light_energy    = 8.0
	light.light_color     = Color(0.35, 0.60, 1.0)
	# Onde de choc visuelle (anneau)
	var ring := CPUParticles3D.new()
	root.add_child(ring)
	ring.global_position      = pos
	ring.one_shot             = true
	ring.explosiveness        = 1.0
	ring.amount               = 50
	ring.lifetime             = 0.4
	ring.initial_velocity_min = explosion_radius * 4.0
	ring.initial_velocity_max = explosion_radius * 5.0
	ring.spread               = 12.0
	ring.gravity              = Vector3.ZERO
	ring.scale_amount_min     = 0.05
	ring.scale_amount_max     = 0.10
	ring.color                = Color(0.5, 0.75, 1.0, 0.7)
	ring.emitting             = true
	_apply_stun_area(pos, explosion_radius * 2.5, 4.0)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_shake"):
		var d := cam.global_position.distance_to(pos)
		if d < explosion_radius * 5.0:
			cam.add_shake(clampf(1.0 - d / (explosion_radius * 5.0), 0.0, 1.0) * 0.025)
	get_tree().create_timer(0.2).timeout.connect(func(): if is_instance_valid(light): light.queue_free())
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(arcs): arcs.queue_free()
		if is_instance_valid(ring): ring.queue_free()
	)

func _do_thermite() -> void:
	var pos  := global_position
	var root := get_tree().current_scene
	# Dégâts immédiats
	_deal_radius_damage(pos, 1.5, explosion_damage * 0.5)
	# Feu persistant
	var fire := CPUParticles3D.new()
	root.add_child(fire)
	fire.global_position      = pos
	fire.one_shot             = false
	fire.amount               = 30
	fire.lifetime             = 1.5
	fire.initial_velocity_min = 1.5
	fire.initial_velocity_max = 4.0
	fire.spread               = 30.0
	fire.gravity              = Vector3(0.0, 4.0, 0.0)
	fire.scale_amount_min     = 0.12
	fire.scale_amount_max     = 0.40
	fire.color                = Color(1.0, 0.55, 0.05, 0.95)
	fire.emitting             = true
	# Étincelles blanches
	var sparks := CPUParticles3D.new()
	root.add_child(sparks)
	sparks.global_position      = pos
	sparks.one_shot             = false
	sparks.amount               = 20
	sparks.lifetime             = 0.8
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 8.0
	sparks.spread               = 45.0
	sparks.gravity              = Vector3(0.0, -8.0, 0.0)
	sparks.scale_amount_min     = 0.015
	sparks.scale_amount_max     = 0.035
	sparks.color                = Color(1.0, 0.92, 0.60)
	sparks.emitting             = true
	# Lumière orange
	var light := OmniLight3D.new()
	root.add_child(light)
	light.global_position = pos
	light.omni_range      = 6.0
	light.light_energy    = 8.0
	light.light_color     = Color(1.0, 0.50, 0.10)
	# 12 ticks de dégâts toutes les 0.5 s sur 6 s (closures indépendantes de self)
	var owner_saved := _owner_id
	var scene_root  := root
	for tick in 12:
		var delay: float = 0.5 * (tick + 1)
		var fref := fire
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(fref):
				return
			var space2: PhysicsDirectSpaceState3D = scene_root.get_world_3d().direct_space_state
			var q2 := PhysicsShapeQueryParameters3D.new()
			var sph2 := SphereShape3D.new()
			sph2.radius = 1.5
			q2.shape    = sph2
			q2.transform = Transform3D(Basis.IDENTITY, pos)
			for hit2 in space2.intersect_shape(q2, 16):
				var col2 = hit2.get("collider")
				if not col2 or not (col2 is Node3D): continue
				var d2: float = (col2 as Node3D).global_position.distance_to(pos)
				var fo: float = 1.0 - clampf(d2 / 1.5, 0.0, 1.0)
				if col2.has_method("take_damage"): col2.take_damage(18.0 * fo, owner_saved)
		)
	get_tree().create_timer(6.5).timeout.connect(func():
		if is_instance_valid(fire):   fire.queue_free()
		if is_instance_valid(sparks): sparks.queue_free()
		if is_instance_valid(light):  light.queue_free()
	)

# ─────────────────────────────────────────────────────────────────────────────
# UTILITAIRES
# ─────────────────────────────────────────────────────────────────────────────
func _deal_radius_damage(pos: Vector3, radius: float, dmg: float) -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, pos)
	var hits: Array = space.intersect_shape(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var node: Node3D = collider
		var dist: float = (node.global_position - pos).length()
		var falloff: float = 1.0 - clampf(dist / radius, 0.0, 1.0)
		var final_dmg: float = dmg * falloff
		if collider.has_method("take_damage"):
			collider.take_damage(final_dmg, _owner_id)
		if collider.has_method("apply_damage"):
			collider.apply_damage(final_dmg, pos)

func _apply_stun_area(pos: Vector3, radius: float, duration: float) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		var p3 := player as Node3D
		if not p3:
			continue
		var dist: float = p3.global_position.distance_to(pos)
		if dist < radius:
			var intensity: float = 1.0 - clampf(dist / radius, 0.0, 1.0)
			if player.has_method("apply_stun"):
				player.apply_stun(duration * intensity)

func _flash_screen(intensity: float) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var flash_rect := ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.98, 0.90, intensity * 0.95)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas := CanvasLayer.new()
	canvas.layer = 99
	vp.add_child(canvas)
	canvas.add_child(flash_rect)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 1.5 * intensity)
	tw.tween_callback(func(): if is_instance_valid(canvas): canvas.queue_free())

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
