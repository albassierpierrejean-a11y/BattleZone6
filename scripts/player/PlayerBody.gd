extends Node3D
class_name PlayerBody

const COLOR_UNIFORM := Color(0.13, 0.19, 0.12)
const COLOR_SKIN    := Color(0.68, 0.52, 0.38)
const COLOR_HELMET  := Color(0.15, 0.19, 0.11)
const COLOR_GEAR    := Color(0.20, 0.26, 0.17)

func _ready() -> void:
	var player := get_parent() as PlayerController
	if not player:
		return
	await get_tree().process_frame
	if player.is_multiplayer_authority():
		visible = false
		return
	_build()

func _build() -> void:
	# Corps principal
	_add(CapsuleMesh.new(), Vector3(0, 0.85, 0), COLOR_UNIFORM,
		func(m: CapsuleMesh): m.radius = 0.27; m.height = 1.15)

	# Équipement tactique (gilet) — légèrement plus large
	_add(CapsuleMesh.new(), Vector3(0, 0.95, 0), COLOR_GEAR,
		func(m: CapsuleMesh): m.radius = 0.30; m.height = 0.55)

	# Cou
	_add(CylinderMesh.new(), Vector3(0, 1.56, 0), COLOR_SKIN,
		func(m: CylinderMesh): m.top_radius = 0.07; m.bottom_radius = 0.09; m.height = 0.12)

	# Tête
	_add(SphereMesh.new(), Vector3(0, 1.66, 0), COLOR_SKIN,
		func(m: SphereMesh): m.radius = 0.175; m.height = 0.35)

	# Casque (couvre le dessus de la tête)
	_add(SphereMesh.new(), Vector3(0, 1.70, 0), COLOR_HELMET,
		func(m: SphereMesh): m.radius = 0.205; m.height = 0.24)

	# Bras gauche
	_add(CapsuleMesh.new(), Vector3(-0.34, 1.05, 0), COLOR_UNIFORM,
		func(m: CapsuleMesh): m.radius = 0.065; m.height = 0.62)

	# Bras droit
	_add(CapsuleMesh.new(), Vector3(0.34, 1.05, 0), COLOR_UNIFORM,
		func(m: CapsuleMesh): m.radius = 0.065; m.height = 0.62)

func _add(mesh: Mesh, pos: Vector3, color: Color, configure: Callable) -> void:
	configure.call(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.88
	mat.metallic     = 0.02
	mi.material_override = mat
	add_child(mi)
