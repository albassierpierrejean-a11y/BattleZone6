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
	_build_mesh()

func _build_mesh() -> void:
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color(0.22, 0.28, 0.18)
	olive.roughness    = 0.85
	olive.metallic     = 0.12

	# ── Chassis ──────────────────────────────────────────────────────────────
	var hull := MeshInstance3D.new()
	var hull_bm := BoxMesh.new()
	hull_bm.size = Vector3(1.62, 0.52, 3.8)
	hull.mesh = hull_bm
	hull.position = Vector3(0, 0.62, 0)
	hull.material_override = olive
	add_child(hull)

	# Hood
	var hood := MeshInstance3D.new()
	var hood_bm := BoxMesh.new()
	hood_bm.size = Vector3(1.5, 0.28, 1.2)
	hood.mesh = hood_bm
	hood.position = Vector3(0, 0.9, 1.22)
	hood.material_override = olive
	add_child(hood)

	# Cab
	var cab := MeshInstance3D.new()
	var cab_bm := BoxMesh.new()
	cab_bm.size = Vector3(1.45, 0.68, 1.35)
	cab.mesh = cab_bm
	cab.position = Vector3(0, 1.18, -0.28)
	cab.material_override = olive
	add_child(cab)

	# Windshield
	var glass := MeshInstance3D.new()
	var glass_bm := BoxMesh.new()
	glass_bm.size = Vector3(1.28, 0.48, 0.05)
	glass.mesh = glass_bm
	glass.position = Vector3(0, 1.20, 0.42)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.45, 0.65, 0.90, 0.32)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness    = 0.05
	glass_mat.metallic     = 0.08
	glass.material_override = glass_mat
	add_child(glass)

	# Roll bar
	var bar := MeshInstance3D.new()
	var bar_bm := BoxMesh.new()
	bar_bm.size = Vector3(1.3, 0.06, 0.06)
	bar.mesh = bar_bm
	bar.position = Vector3(0, 1.58, -0.28)
	bar.material_override = olive
	add_child(bar)

	# ── Wheels ────────────────────────────────────────────────────────────────
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.07, 0.07, 0.07)
	tire_mat.roughness    = 0.97
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.48, 0.44, 0.38)
	rim_mat.metallic     = 0.62
	rim_mat.roughness    = 0.48

	var wheel_pos := [
		Vector3( 0.96, 0.36,  1.5),
		Vector3(-0.96, 0.36,  1.5),
		Vector3( 0.96, 0.36, -1.5),
		Vector3(-0.96, 0.36, -1.5),
	]
	for wp in wheel_pos:
		var tire := MeshInstance3D.new()
		var tcyl := CylinderMesh.new()
		tcyl.top_radius    = 0.38
		tcyl.bottom_radius = 0.38
		tcyl.height        = 0.30
		tire.mesh = tcyl
		tire.position = wp
		tire.rotation.z = PI * 0.5
		tire.material_override = tire_mat
		add_child(tire)
		var rim := MeshInstance3D.new()
		var rcyl := CylinderMesh.new()
		rcyl.top_radius    = 0.20
		rcyl.bottom_radius = 0.20
		rcyl.height        = 0.32
		rim.mesh = rcyl
		rim.position = wp
		rim.rotation.z = PI * 0.5
		rim.material_override = rim_mat
		add_child(rim)
