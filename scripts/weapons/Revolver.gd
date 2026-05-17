extends WeaponBase

func _ready() -> void:
	weapon_name      = "Colt Python"
	damage           = 75.0
	headshot_mult    = 3.2
	fire_rate        = 150.0
	reload_time      = 3.0
	mag_size         = 6
	reserve_ammo     = 30
	fire_mode        = FireMode.SEMI
	bullet_spread    = 0.025
	ads_spread_mult  = 0.45
	range_max        = 100.0
	recoil_pitch     = 2.00
	recoil_yaw       = 0.50
	mesh_size        = Vector3(0.042, 0.125, 0.26)
	hip_position     = Vector3(0.16, -0.16, -0.30)
	super._ready()
