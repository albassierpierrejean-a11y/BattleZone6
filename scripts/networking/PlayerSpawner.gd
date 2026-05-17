extends Node
class_name PlayerSpawner
const PlayerController = preload("res://scripts/player/PlayerController.gd")

@export var player_scene: PackedScene
@export var spawn_parent: Node3D

var _spawned_players: Dictionary = {}

func _ready() -> void:
	if multiplayer.is_server():
		NetworkManager.player_list_changed.connect(_spawn_all_pending)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	spawn_player(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	despawn_player(peer_id)

func _spawn_all_pending() -> void:
	for pid in NetworkManager.player_info:
		if pid not in _spawned_players:
			spawn_player(pid)

func spawn_player(peer_id: int) -> Node:
	if peer_id in _spawned_players:
		return _spawned_players[peer_id]
	var data := GameManager.get_player_data(peer_id)
	if not data:
		# Fallback pour tests sans passer par le menu
		GameManager.register_player(peer_id, "Soldat", GameManager.Team.ALPHA)
		data = GameManager.get_player_data(peer_id)
	if not data:
		return null
	var player: Node = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	var parent := spawn_parent if spawn_parent else get_tree().current_scene
	parent.add_child(player)
	var pc := player as PlayerController
	if pc:
		pc.team        = data.team
		pc.player_name = data.name
	var spawn_pos := GameManager.get_spawn_position(data.team, peer_id)
	player.global_position = spawn_pos
	_spawned_players[peer_id] = player
	GameManager.player_spawned.emit(peer_id)
	return player

func despawn_player(peer_id: int) -> void:
	if peer_id in _spawned_players:
		var node := _spawned_players[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		_spawned_players.erase(peer_id)

func get_player_node(peer_id: int) -> Node:
	return _spawned_players.get(peer_id, null)
