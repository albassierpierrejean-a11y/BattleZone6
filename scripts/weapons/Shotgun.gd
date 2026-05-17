extends "res://scripts/weapons/WeaponBase.gd"
const PlayerController = preload("res://scripts/player/PlayerController.gd")

const PELLETS := 8

func _ready() -> void:
	weapon_name      = "Remington 870"
	damage           = 14.0
	headshot_mult    = 1.5
	fire_rate        = 80.0
	reload_time      = 3.2
	mag_size         = 8
	reserve_ammo     = 32
	fire_mode        = FireMode.SEMI
	bullet_spread    = 0.12
	ads_spread_mult  = 0.60
	range_max        = 60.0
	recoil_pitch     = 2.2
	recoil_yaw       = 0.40
	mesh_size        = Vector3(0.058, 0.095, 0.58)
	hip_position     = Vector3(0.19, -0.17, -0.38)
	super._ready()

func _fire_bullet() -> void:
	current_ammo   -= 1
	_fire_cooldown  = 60.0 / fire_rate
	_fire_kick      = minf(_fire_kick + 1.2, 2.0)
	ammo_changed.emit(current_ammo, reserve_ammo)
	fired.emit()
	_play_effects()
	_apply_recoil()
	var cam := _get_camera()
	if not cam:
		return
	var player    := _find_player() as PlayerController
	var sprinting := player != null and player.is_sprinting()
	var spread := bullet_spread
	if _is_ads:
		spread *= ads_spread_mult
	elif sprinting:
		spread *= sprint_spread_mult
	for _i in PELLETS:
		var dir := -cam.global_transform.basis.z
		dir += Vector3(randf_range(-spread, spread),
					   randf_range(-spread, spread),
					   randf_range(-spread, spread))
		_cast_bullet(cam.global_position, dir.normalized())
