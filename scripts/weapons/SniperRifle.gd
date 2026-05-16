extends WeaponBase

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
