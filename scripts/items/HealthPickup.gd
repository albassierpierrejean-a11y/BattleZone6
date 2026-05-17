extends Area3D
class_name HealthPickup
const PlayerController = preload("res://scripts/player/PlayerController.gd")
const PlayerHealth     = preload("res://scripts/player/PlayerHealth.gd")

@export var heal_amount: float = 40.0
@export var respawn_delay: float = 15.0

var _available: bool = true
var _base_y: float = 0.0
var _time: float = 0.0

const COLOR_ACTIVE   := Color(0.10, 0.90, 0.30, 1.0)
const COLOR_INACTIVE := Color(0.15, 0.15, 0.15, 1.0)
const EMISSION_ACTIVE := Color(0.04, 0.55, 0.12)

var _mat_v: StandardMaterial3D
var _mat_h: StandardMaterial3D
var _mat_outer: StandardMaterial3D

func _ready() -> void:
	add_to_group("pickups")
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_ACTIVE
	mat.emission_enabled = true
	mat.emission = EMISSION_ACTIVE
	mat.emission_energy_multiplier = 1.8
	mat.metallic = 0.2
	mat.roughness = 0.4
	_mat_v = mat
	_mat_h = mat.duplicate() as StandardMaterial3D

	# Croix : bras vertical
	var v := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.12, 0.52, 0.12)
	v.mesh = vb
	v.material_override = _mat_v
	add_child(v)

	# Croix : bras horizontal
	var h := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.52, 0.12, 0.12)
	h.mesh = hb
	h.material_override = _mat_h
	add_child(h)

	# Cube translucide extérieur pour la visibilité
	var outer := MeshInstance3D.new()
	var ob := BoxMesh.new()
	ob.size = Vector3(0.68, 0.68, 0.68)
	outer.mesh = ob
	_mat_outer = StandardMaterial3D.new()
	_mat_outer.albedo_color = Color(0.05, 0.35, 0.10, 0.18)
	_mat_outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_outer.emission_enabled = true
	_mat_outer.emission = EMISSION_ACTIVE
	_mat_outer.emission_energy_multiplier = 0.5
	_mat_outer.cull_mode = BaseMaterial3D.CULL_DISABLED
	outer.material_override = _mat_outer
	add_child(outer)

	# Sphère de détection
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.72
	col.shape = sphere
	add_child(col)

func _process(delta: float) -> void:
	if not _available:
		return
	_time += delta
	rotate_y(delta * 1.5)
	position.y = _base_y + sin(_time * 2.2) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if not _available:
		return
	if not body is PlayerController:
		return
	if not (body as PlayerController).is_multiplayer_authority():
		return
	var pid := (body as PlayerController).peer_id
	if multiplayer.is_server():
		_server_pickup(pid)
	else:
		_request_pickup.rpc_id(1, pid)

@rpc("any_peer", "reliable")
func _request_pickup(collector_id: int) -> void:
	if not multiplayer.is_server():
		return
	_server_pickup(collector_id)

func _server_pickup(collector_id: int) -> void:
	if not _available:
		return
	_available = false
	_grant_pickup.rpc(collector_id)
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn, CONNECT_ONE_SHOT)

@rpc("authority", "call_local", "reliable")
func _grant_pickup(collector_id: int) -> void:
	_available = false
	visible = false
	var player := get_tree().get_first_node_in_group("local_player") as PlayerController
	if player and player.peer_id == collector_id:
		var health := player.get_node_or_null("PlayerHealth") as PlayerHealth
		if health and not health.is_dead():
			health.heal(heal_amount)

func _respawn() -> void:
	_show_all.rpc()

@rpc("authority", "call_local", "reliable")
func _show_all() -> void:
	_available = true
	visible = true
	_time = 0.0
	position.y = _base_y
