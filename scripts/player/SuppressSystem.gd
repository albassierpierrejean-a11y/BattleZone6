extends Node
class_name SuppressSystem

const PlayerCamera = preload("res://scripts/player/PlayerCamera.gd")

# IS-style suppression : balles proches → désaturation + tremblement + ADS pénalisé

const SUPPRESS_RADIUS    := 4.5
const SUPPRESS_PER_ROUND := 0.28
const SUPPRESS_DECAY     := 0.6    # /sec
const SUPPRESS_MAX       := 1.0

signal suppression_changed(level: float)

var level: float = 0.0
var _post_process: ShaderMaterial = null

func _ready() -> void:
	add_to_group("suppress_system")
	_find_post_process()

func _process(delta: float) -> void:
	if level <= 0.0:
		return
	level = maxf(level - SUPPRESS_DECAY * delta, 0.0)
	_apply_visual()
	suppression_changed.emit(level)

func register_bullet_near(bullet_pos: Vector3) -> void:
	var player := _get_player()
	if not player:
		return
	var dist := player.global_position.distance_to(bullet_pos)
	if dist < SUPPRESS_RADIUS:
		var factor := 1.0 - (dist / SUPPRESS_RADIUS)
		level = minf(level + SUPPRESS_PER_ROUND * factor, SUPPRESS_MAX)
		_get_camera().add_shake(factor * 0.012)
		suppression_changed.emit(level)

func get_ads_penalty() -> float:
	return level * 0.45

func get_spread_penalty() -> float:
	return level * 1.8

func _apply_visual() -> void:
	if _post_process:
		_post_process.set_shader_parameter("suppress_str", level)

func _find_post_process() -> void:
	await get_tree().process_frame
	var nodes := get_tree().get_nodes_in_group("post_process")
	if nodes.size() > 0:
		var n := nodes[0]
		if n is CanvasItem:
			_post_process = (n as CanvasItem).material as ShaderMaterial

func _get_player() -> CharacterBody3D:
	var n := get_parent()
	while n:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null

func _get_camera() -> PlayerCamera:
	var cam := get_tree().get_first_node_in_group("local_player")
	if cam:
		var c := cam.find_child("Camera3D", true, false)
		if c is Camera3D and c.has_method("add_shake"):
			return c as PlayerCamera
	return null
