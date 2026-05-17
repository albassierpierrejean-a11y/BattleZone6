extends WeaponBase

func _ready() -> void:
	weapon_name      = "M249"
	damage           = 30.0
	headshot_mult    = 2.0
	fire_rate        = 750.0
	reload_time      = 5.0
	mag_size         = 100
	reserve_ammo     = 200
	fire_mode        = FireMode.AUTO
	bullet_spread    = 0.035
	ads_spread_mult  = 0.40
	range_max        = 280.0
	recoil_pitch     = 0.90
	recoil_yaw       = 0.30
	mesh_size        = Vector3(0.065, 0.11, 0.65)
	hip_position     = Vector3(0.20, -0.18, -0.40)
	ads_position     = Vector3(0.0,  -0.12, -0.32)
	super._ready()
