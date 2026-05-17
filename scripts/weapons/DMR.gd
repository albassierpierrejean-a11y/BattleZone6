extends WeaponBase

func _ready() -> void:
	weapon_name      = "M14 EBR"
	damage           = 65.0
	headshot_mult    = 3.0
	fire_rate        = 220.0
	reload_time      = 2.8
	mag_size         = 20
	reserve_ammo     = 80
	fire_mode        = FireMode.SEMI
	bullet_spread    = 0.010
	ads_spread_mult  = 0.18
	range_max        = 450.0
	recoil_pitch     = 1.80
	recoil_yaw       = 0.20
	ads_fov_mult     = 0.50
	mesh_size        = Vector3(0.05, 0.09, 0.62)
	super._ready()
