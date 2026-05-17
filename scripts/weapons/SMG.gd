extends WeaponBase

func _ready() -> void:
	weapon_name      = "MP5K"
	damage           = 22.0
	headshot_mult    = 2.0
	fire_rate        = 900.0
	reload_time      = 2.0
	mag_size         = 30
	reserve_ammo     = 180
	fire_mode        = FireMode.AUTO
	bullet_spread    = 0.025
	ads_spread_mult  = 0.35
	range_max        = 120.0
	recoil_pitch     = 0.50
	recoil_yaw       = 0.22
	mesh_size        = Vector3(0.048, 0.085, 0.38)
	hip_position     = Vector3(0.17, -0.15, -0.32)
	ads_position     = Vector3(0.0,  -0.09, -0.26)
	super._ready()
