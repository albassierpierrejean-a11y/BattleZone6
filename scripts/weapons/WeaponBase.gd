extends Node3D
class_name WeaponBase

# ─── Énumérations ────────────────────────────────────────────────────────────
enum FireMode { SEMI, AUTO, BURST }

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var weapon_name:       String   = "Arme"
@export var damage:            float    = 25.0
@export var headshot_mult:     float    = 2.5
@export var fire_rate:         float    = 600.0   # coups par minute
@export var reload_time:       float    = 2.4
@export var mag_size:          int      = 30
@export var reserve_ammo:      int      = 120
@export var fire_mode:         FireMode = FireMode.AUTO
@export var bullet_speed:      float    = 400.0
@export var bullet_spread:     float    = 0.02
@export var ads_spread_mult:   float    = 0.30
@export var sprint_spread_mult:float    = 2.8    # pénalité de précision en sprint
@export var range_max:         float    = 300.0
@export var recoil_pitch:      float    = 0.8
@export var recoil_yaw:        float    = 0.2
@export var ads_fov_mult:      float    = 0.6
@export var burst_count:       int      = 3
@export var mesh_size:         Vector3  = Vector3(0.055, 0.10, 0.44)
@export var hip_position:      Vector3  = Vector3(0.18, -0.16, -0.35)
@export var ads_position:      Vector3  = Vector3(0.0,  -0.10, -0.28)
@export var model_path:        String   = ""

# ─── Références nœuds ────────────────────────────────────────────────────────
@onready var muzzle:       Marker3D               = $Muzzle
@onready var anim:         AnimationPlayer        = get_node_or_null("AnimationPlayer")          as AnimationPlayer
@onready var shoot_sound:  AudioStreamPlayer3D    = get_node_or_null("ShootSound")               as AudioStreamPlayer3D
@onready var reload_sound: AudioStreamPlayer3D    = get_node_or_null("ReloadSound")              as AudioStreamPlayer3D
@onready var empty_sound:  AudioStreamPlayer3D    = get_node_or_null("EmptySound")               as AudioStreamPlayer3D
@onready var muzzle_flash: GPUParticles3D         = get_node_or_null("Muzzle/MuzzleFlash")       as GPUParticles3D

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal ammo_changed(current: int, reserve: int)
signal fired
signal reloaded
signal reload_started(duration: float)
signal empty_click
signal hit_confirmed(is_headshot: bool)

# ─── État runtime ────────────────────────────────────────────────────────────
var current_ammo:    int   = 0
var _fire_cooldown:  float = 0.0
var _is_reloading:   bool  = false
var _is_ads:         bool  = false
var _burst_remaining:int   = 0

# Animation
var _fire_kick:  float   = 0.0
var _reload_dip: Vector3 = Vector3.ZERO
var _anim_tween: Tween   = null
var _idle_t:     float   = 0.0
var anim_offset: Vector3 = Vector3.ZERO   # lu par WeaponManager
var anim_rot_x:  float   = 0.0            # lu par WeaponManager

func _ready() -> void:
	current_ammo = mag_size
	_build_mesh()
	_build_effects()

func _build_mesh() -> void:
	if get_node_or_null("WeaponMesh"):
		return
	# Charge le .glb si un chemin est défini et que le fichier existe
	if model_path != "" and ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var inst := scene.instantiate()
			inst.name = "WeaponMesh"
			add_child(inst)
			return
	# Fallback : cube gris
	var mi := MeshInstance3D.new()
	mi.name = "WeaponMesh"
	var box := BoxMesh.new()
	box.size = mesh_size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.10, 0.12)
	mat.metallic     = 0.75
	mat.roughness    = 0.35
	mi.material_override = mat
	add_child(mi)
	mi.position = Vector3(0.0, 0.0, -mesh_size.z * 0.5)

func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_update_anim(delta)
	if not visible:
		return
	var player := _find_player()
	if player and player.is_multiplayer_authority():
		_handle_input()

func _update_anim(delta: float) -> void:
	_fire_kick  = lerpf(_fire_kick, 0.0, delta * 16.0)
	_idle_t    += delta * 0.9
	var idle := Vector3(sin(_idle_t * 0.62) * 0.0012, sin(_idle_t) * 0.0018, 0.0)
	anim_offset = Vector3(0.0, _fire_kick * -0.008, _fire_kick * 0.048) + _reload_dip + idle
	anim_rot_x  = _fire_kick * -0.04

func _handle_input() -> void:
	if _is_reloading:
		return
	_is_ads = Input.is_action_pressed("aim")
	var trigger := (Input.is_action_pressed("fire")      if fire_mode == FireMode.AUTO
				 else Input.is_action_just_pressed("fire"))
	if trigger:
		try_fire()
	if Input.is_action_just_pressed("reload") and current_ammo < mag_size:
		start_reload()

func try_fire() -> void:
	if _is_reloading or _fire_cooldown > 0.0:
		return
	if current_ammo <= 0:
		_on_empty()
		return
	match fire_mode:
		FireMode.SEMI, FireMode.AUTO:
			_fire_bullet()
		FireMode.BURST:
			if _burst_remaining <= 0:
				_burst_remaining = burst_count
			_fire_bullet()
			_burst_remaining -= 1

func _fire_bullet() -> void:
	current_ammo    -= 1
	_fire_cooldown   = 60.0 / fire_rate
	_fire_kick       = minf(_fire_kick + 0.85, 1.4)
	ammo_changed.emit(current_ammo, reserve_ammo)
	fired.emit()
	_play_effects()
	_apply_recoil()

	var cam := _get_camera()
	if not cam:
		return

	# Dispersion : ADS < normal < sprint
	var player    := _find_player() as PlayerController
	var sprinting := player != null and player.is_sprinting()

	var spread := bullet_spread
	if _is_ads:
		spread *= ads_spread_mult
	elif sprinting:
		spread *= sprint_spread_mult

	var dir    := -cam.global_transform.basis.z
	dir += Vector3(randf_range(-spread, spread),
				   randf_range(-spread, spread),
				   randf_range(-spread, spread))
	_cast_bullet(cam.global_position, dir.normalized())

func _cast_bullet(origin: Vector3, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(origin, origin + dir * range_max)
	var hit    := space.intersect_ray(query)
	if hit.is_empty():
		_notify_suppression_along(origin, dir)
		_spawn_bullet_trace(origin, origin + dir * minf(range_max, 80.0))
		return

	var collider   = hit.get("collider")
	var hit_pos    = hit.get("position", Vector3.ZERO)
	var hit_normal = hit.get("normal",   Vector3.UP)
	if not collider:
		return

	# Tir en tête : la cible doit être dans le groupe "head_hitbox"
	var is_head: bool = collider.is_in_group("head_hitbox")
	var dmg: float    = damage * (headshot_mult if is_head else 1.0)

	var shooter_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if collider.has_method("take_damage"):
		collider.take_damage(dmg, shooter_id)
		if collider.is_in_group("players"):
			hit_confirmed.emit(is_head)
			_spawn_damage_number(hit_pos + Vector3.UP * 0.5, dmg, is_head)
	if collider.has_method("apply_damage"):
		collider.apply_damage(dmg, hit_pos)
	_spawn_hit_effect(hit_pos, hit_normal, collider)
	_spawn_bullet_trace(origin, hit_pos)

func _play_effects() -> void:
	if shoot_sound and shoot_sound.stream:
		shoot_sound.play()
	if muzzle_flash:
		muzzle_flash.restart()
	_flash_muzzle_light()
	_eject_shell()
	_spawn_muzzle_smoke()

func _spawn_muzzle_smoke() -> void:
	if not muzzle:
		return
	var root := get_tree().current_scene
	if not root:
		return
	var smoke := CPUParticles3D.new()
	root.add_child(smoke)
	smoke.global_position      = muzzle.global_position
	smoke.one_shot             = true
	smoke.explosiveness        = 0.9
	smoke.amount               = 4
	smoke.lifetime             = 0.6
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.4
	smoke.spread               = 22.0
	smoke.gravity              = Vector3(0.0, 0.8, 0.0)
	smoke.scale_amount_min     = 0.02
	smoke.scale_amount_max     = 0.08
	smoke.color                = Color(0.65, 0.62, 0.58, 0.55)
	smoke.emitting             = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(smoke): smoke.queue_free())

func _apply_recoil() -> void:
	var cam := _get_camera()
	if cam and cam.has_method("add_recoil"):
		cam.add_recoil(recoil_pitch, randf_range(-recoil_yaw, recoil_yaw))

func _on_empty() -> void:
	if empty_sound and empty_sound.stream:
		empty_sound.play()
	empty_click.emit()
	if reserve_ammo > 0:
		start_reload()

func start_reload() -> void:
	if _is_reloading or reserve_ammo <= 0 or current_ammo == mag_size:
		return
	_is_reloading = true
	reload_started.emit(reload_time)
	if reload_sound and reload_sound.stream:
		reload_sound.play()
	_tween_reload()
	await get_tree().create_timer(reload_time).timeout
	if not is_inside_tree():
		return
	_finish_reload()

func _finish_reload() -> void:
	var needed   := mag_size - current_ammo
	var take     := mini(needed, reserve_ammo)
	current_ammo += take
	reserve_ammo -= take
	_is_reloading = false
	reloaded.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)

func _spawn_hit_effect(pos: Vector3, normal: Vector3, target: Object) -> void:
	if target is CharacterBody3D and target.is_in_group("players"):
		_spawn_blood_effect(pos, normal)
	else:
		_spawn_impact_effect(pos, normal)

func _spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	var root := get_tree().current_scene
	# Étincelles
	var sparks := CPUParticles3D.new()
	root.add_child(sparks)
	sparks.global_position      = pos + normal * 0.01
	sparks.one_shot             = true
	sparks.explosiveness        = 0.95
	sparks.amount               = 10
	sparks.lifetime             = 0.35
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 7.0
	sparks.spread               = 40.0
	sparks.gravity              = Vector3(0.0, -12.0, 0.0)
	sparks.scale_amount_min     = 0.012
	sparks.scale_amount_max     = 0.025
	sparks.color                = Color(1.0, 0.72, 0.18)
	if normal.length_squared() > 0.01:
		sparks.look_at(pos + normal)
	sparks.emitting = true
	get_tree().create_timer(1.5).timeout.connect(
		func(): if is_instance_valid(sparks): sparks.queue_free())
	# Puff de poussière si impact sur le sol (normale vers le haut)
	if normal.y > 0.5:
		var dust := CPUParticles3D.new()
		root.add_child(dust)
		dust.global_position      = pos + Vector3(0, 0.02, 0)
		dust.one_shot             = true
		dust.explosiveness        = 0.7
		dust.amount               = 7
		dust.lifetime             = 0.55
		dust.initial_velocity_min = 0.8
		dust.initial_velocity_max = 2.5
		dust.spread               = 55.0
		dust.gravity              = Vector3(0.0, -2.0, 0.0)
		dust.scale_amount_min     = 0.06
		dust.scale_amount_max     = 0.18
		dust.color                = Color(0.62, 0.52, 0.38, 0.75)
		dust.emitting             = true
		get_tree().create_timer(2.0).timeout.connect(
			func(): if is_instance_valid(dust): dust.queue_free())
	# Trou de balle — flat mesh (Decal sans texture = invisible en Godot 4)
	var hole := MeshInstance3D.new()
	var hole_pm := PlaneMesh.new()
	hole_pm.size = Vector2(0.055, 0.055)
	hole.mesh = hole_pm
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color      = Color(0.04, 0.03, 0.02, 0.92)
	hole_mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	hole_mat.depth_draw_mode   = BaseMaterial3D.DEPTH_DRAW_NEVER
	hole_mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	hole_mat.render_priority   = 1
	hole.material_override     = hole_mat
	hole.gi_mode               = GeometryInstance3D.GI_MODE_DISABLED
	root.add_child(hole)
	hole.global_position = pos + normal * 0.006
	if normal.length_squared() > 0.01:
		hole.look_at(pos + normal, Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	get_tree().create_timer(12.0).timeout.connect(
		func(): if is_instance_valid(hole): hole.queue_free())

func _spawn_blood_effect(pos: Vector3, normal: Vector3) -> void:
	var root  := get_tree().current_scene
	var blood := CPUParticles3D.new()
	root.add_child(blood)
	blood.global_position       = pos
	blood.one_shot              = true
	blood.explosiveness         = 0.88
	blood.amount                = 8
	blood.lifetime              = 0.45
	blood.initial_velocity_min  = 1.2
	blood.initial_velocity_max  = 4.5
	blood.spread                = 50.0
	blood.gravity               = Vector3(0.0, -14.0, 0.0)
	blood.scale_amount_min      = 0.018
	blood.scale_amount_max      = 0.040
	blood.color                 = Color(0.68, 0.03, 0.03)
	if normal.length_squared() > 0.01:
		blood.look_at(pos + normal)
	blood.emitting = true
	get_tree().create_timer(1.2).timeout.connect(
		func(): if is_instance_valid(blood): blood.queue_free())

func _notify_suppression_along(origin: Vector3, dir: Vector3) -> void:
	var self_player := _find_player()
	for player in get_tree().get_nodes_in_group("players"):
		if player == self_player:
			continue
		var p3 := player as Node3D
		if not p3:
			continue
		var to_p := p3.global_position - origin
		var proj  := to_p.dot(dir)
		if proj < 0.0 or proj > range_max:
			continue
		var closest := origin + dir * proj
		var lat_dist := (p3.global_position - closest).length()
		if lat_dist < 4.5:
			var ss := p3.find_child("SuppressSystem", true, false) as SuppressSystem
			if ss:
				ss.register_bullet_near(closest)

func _get_camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func _find_player() -> Node:
	var n: Node = get_parent()
	while n:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null

func equip() -> void:
	visible = true
	_reload_dip = Vector3(0.0, -0.30, 0.0)
	if _anim_tween:
		_anim_tween.kill()
	_anim_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_method(func(v: Vector3): _reload_dip = v, _reload_dip, Vector3.ZERO, 0.28)

func unequip() -> void:
	visible       = false
	_is_reloading = false
	if _anim_tween:
		_anim_tween.kill()
	_reload_dip = Vector3.ZERO
	_fire_kick  = 0.0

func _tween_reload() -> void:
	if _anim_tween:
		_anim_tween.kill()
	var from := _reload_dip
	_anim_tween = create_tween()
	_anim_tween.tween_method(
		func(v: Vector3): _reload_dip = v,
		from, Vector3(0.0, -0.14, 0.07), reload_time * 0.35)
	_anim_tween.tween_method(
		func(v: Vector3): _reload_dip = v,
		Vector3(0.0, -0.14, 0.07), Vector3.ZERO, reload_time * 0.28)

func _build_effects() -> void:
	if not muzzle:
		return
	var flash         := GPUParticles3D.new()
	flash.name        = "MuzzleFlash"
	var pm            := ParticleProcessMaterial.new()
	pm.direction       = Vector3(0.0, 0.0, -1.0)
	pm.spread          = 28.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 18.0
	pm.color           = Color(1.0, 0.85, 0.42, 1.0)
	var grad           := Gradient.new()
	grad.colors        = PackedColorArray([Color(1.0, 0.85, 0.42, 1.0), Color(1.0, 0.50, 0.08, 0.0)])
	var grad_tex       := GradientTexture1D.new()
	grad_tex.gradient  = grad
	pm.color_ramp      = grad_tex
	pm.scale_min       = 0.03
	pm.scale_max       = 0.09
	flash.process_material = pm
	flash.amount       = 12
	flash.lifetime     = 0.08
	flash.one_shot     = true
	flash.explosiveness = 1.0
	flash.emitting     = false
	muzzle.add_child(flash)
	muzzle_flash = flash

func _spawn_damage_number(pos: Vector3, amount: float, is_headshot: bool) -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var label := Label3D.new()
	label.text        = "-%d" % int(amount)
	label.font_size   = 48
	label.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	if is_headshot:
		label.modulate  = Color(1.0, 0.18, 0.08)
		label.text      = "-%d  HS" % int(amount)
		label.font_size = 58
	else:
		label.modulate  = Color(1.0, 0.92, 0.22)
	root.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	var tween := create_tween()
	tween.tween_property(label, "global_position", pos + Vector3.UP * 2.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(label.queue_free)

func _spawn_bullet_trace(from: Vector3, to: Vector3) -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var length := from.distance_to(to)
	if length < 0.5:
		return
	var mid    := (from + to) * 0.5
	var mi     := MeshInstance3D.new()
	var cyl    := CylinderMesh.new()
	cyl.top_radius    = 0.0018
	cyl.bottom_radius = 0.0018
	cyl.height        = length
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color       = Color(1.0, 0.92, 0.72, 0.45)
	mat.emission_enabled   = true
	mat.emission           = Color(1.0, 0.88, 0.55)
	mat.emission_energy_multiplier = 1.8
	mat.transparency       = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override   = mat
	root.add_child(mi)
	mi.global_position = mid
	if length > 0.01:
		mi.look_at(to, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tween.tween_callback(mi.queue_free)

func _eject_shell() -> void:
	if not muzzle:
		return
	var owner_player := _find_player()
	if owner_player and not owner_player.is_multiplayer_authority():
		return
	var root := get_tree().current_scene
	if not root:
		return
	var shell := RigidBody3D.new()
	shell.gravity_scale = 1.0
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.004
	cyl.bottom_radius = 0.004
	cyl.height        = 0.016
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.62, 0.18)
	mat.metallic     = 0.88
	mat.roughness    = 0.22
	mi.material_override = mat
	shell.add_child(mi)
	var col := CollisionShape3D.new()
	var csh := SphereShape3D.new()
	csh.radius = 0.006
	col.shape = csh
	shell.add_child(col)
	root.add_child(shell)
	shell.global_position = muzzle.global_position
	# Éjecte vers la droite de l'arme avec une impulsion aléatoire
	var basis := muzzle.global_transform.basis
	var eject_dir := basis.x * randf_range(1.8, 2.8) + basis.y * randf_range(0.6, 1.4) + basis.z * randf_range(-0.5, 0.5)
	shell.apply_central_impulse(eject_dir * shell.mass)
	shell.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.002)
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(shell): shell.queue_free())

func _flash_muzzle_light() -> void:
	if not muzzle:
		return
	var light := muzzle.get_node_or_null("MuzzleLight") as OmniLight3D
	if not light:
		light                = OmniLight3D.new()
		light.name           = "MuzzleLight"
		light.omni_range     = 3.5
		light.light_energy   = 10.0
		light.light_color    = Color(1.0, 0.72, 0.32)
		light.shadow_enabled = false
		muzzle.add_child(light)
	light.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(light):
		light.visible = false
