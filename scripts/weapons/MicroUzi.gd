extends WeaponBase

func _ready() -> void:
	weapon_name      = "Micro UZI"
	damage           = 18.0
	headshot_mult    = 1.8
	fire_rate        = 1200.0
	reload_time      = 1.8
	mag_size         = 25
	reserve_ammo     = 150
	fire_mode        = FireMode.AUTO
	bullet_spread    = 0.045
	ads_spread_mult  = 0.50
	range_max        = 70.0
	recoil_pitch     = 0.65
	recoil_yaw       = 0.35
	mesh_size        = Vector3(0.038, 0.10, 0.24)
	hip_position     = Vector3(0.15, -0.14, -0.28)
	super._ready()
