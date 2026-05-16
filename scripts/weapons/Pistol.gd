extends WeaponBase

func _ready() -> void:
	weapon_name    = "M9"
	damage         = 35.0
	headshot_mult  = 2.8
	fire_rate      = 450.0
	reload_time    = 1.6
	mag_size       = 15
	reserve_ammo   = 60
	fire_mode      = FireMode.SEMI
	bullet_spread  = 0.03
	ads_spread_mult = 0.4
	range_max      = 80.0
	recoil_pitch   = 1.2
	recoil_yaw     = 0.3
	mesh_size      = Vector3(0.04, 0.12, 0.22)
	model_path     = "res://assets/models/weapons/wac47.gltf"
	super._ready()
