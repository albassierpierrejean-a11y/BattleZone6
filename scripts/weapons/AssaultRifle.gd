extends WeaponBase

func _ready() -> void:
	weapon_name     = "M416"
	damage          = 28.0
	headshot_mult   = 2.2
	fire_rate       = 750.0
	reload_time     = 2.3
	mag_size        = 30
	reserve_ammo    = 150
	fire_mode       = FireMode.AUTO
	bullet_spread   = 0.018
	ads_spread_mult = 0.25
	range_max       = 250.0
	recoil_pitch    = 0.7
	recoil_yaw      = 0.15
	mesh_size       = Vector3(0.055, 0.09, 0.52)
	model_path      = "res://assets/models/weapons/ak74m.glb"
	super._ready()
