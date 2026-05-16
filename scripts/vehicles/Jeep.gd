extends VehicleBase

func _ready() -> void:
	vehicle_name    = "Jeep"
	max_speed       = 28.0
	engine_force_val = 600.0
	brake_force     = 18.0
	steer_max       = 0.45
	max_health      = 300.0
	num_seats       = 4
	exit_offsets    = [Vector3(1.5, 0.5, 0), Vector3(-1.5, 0.5, 0),
					   Vector3(1.5, 0.5, -1.5), Vector3(-1.5, 0.5, -1.5)]
	super._ready()
