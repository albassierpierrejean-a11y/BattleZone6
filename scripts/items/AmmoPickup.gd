extends Area3D
class_name AmmoPickup

@export var ammo_per_weapon: int = 60
@export var respawn_delay: float = 20.0

var _available: bool = true
var _base_y: float = 0.0
var _time: float = 0.0

const COLOR_BOX   := Color(0.22, 0.18, 0.08, 1.0)
const COLOR_BAND  := Color(0.90, 0.65, 0.10, 1.0)
const EMISSION    := Color(0.55, 0.38, 0.02)

func _ready() -> void:
	add_to_group("pickups")
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Caisse principale
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = COLOR_BOX
	box_mat.roughness = 0.8
	box_mat.metallic = 0.1

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.40, 0.38)
	mi.mesh = bm
	mi.material_override = box_mat
	add_child(mi)

	# Bande jaune (indicateur de munitions)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = COLOR_BAND
	band_mat.emission_enabled = true
	band_mat.emission = EMISSION
	band_mat.emission_energy_multiplier = 2.0
	band_mat.roughness = 0.3

	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.57, 0.08, 0.40)
	band.mesh = bb
	band.material_override = band_mat
	add_child(band)

	# Cube de lueur extérieur
	var outer := MeshInstance3D.new()
	var ob := BoxMesh.new()
	ob.size = Vector3(0.65, 0.50, 0.48)
	outer.mesh = ob
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.5, 0.35, 0.0, 0.12)
	omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	omat.emission_enabled = true
	omat.emission = EMISSION
	omat.emission_energy_multiplier = 0.4
	omat.cull_mode = BaseMaterial3D.CULL_DISABLED
	outer.material_override = omat
	add_child(outer)

	# Collision de ramassage
	var col := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = Vector3(0.70, 0.55, 0.55)
	col.shape = csh
	add_child(col)

func _process(delta: float) -> void:
	if not _available:
		return
	_time += delta
	rotate_y(delta * 1.0)
	position.y = _base_y + sin(_time * 1.8) * 0.06

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
		var wm := player.get_node_or_null("Head/Camera3D/WeaponManager") as WeaponManager
		if wm:
			for w in wm.weapons:
				w.reserve_ammo = mini(w.reserve_ammo + ammo_per_weapon, w.mag_size * 6)
			var cw := wm.get_current_weapon()
			if cw:
				wm.ammo_updated.emit(cw.current_ammo, cw.reserve_ammo)

func _respawn() -> void:
	_show_all.rpc()

@rpc("authority", "call_local", "reliable")
func _show_all() -> void:
	_available = true
	visible = true
	_time = 0.0
	position.y = _base_y
