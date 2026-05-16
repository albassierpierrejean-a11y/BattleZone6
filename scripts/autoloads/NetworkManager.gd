extends Node

# ─── Constantes ──────────────────────────────────────────────────────────────
const DEFAULT_PORT    := 7777
const MAX_CLIENTS     := 64
const SERVER_ID       := 1

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal server_created
signal joined_server
signal connection_failed
signal player_list_changed
signal disconnected_from_server

# ─── État ────────────────────────────────────────────────────────────────────
var player_info: Dictionary = {}
var local_player_name: String = "Soldier"
var local_player_team: int = GameManager.Team.ALPHA
var current_map_scene: String = "res://scenes/maps/TestMap.tscn"

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# ─── Héberger / Rejoindre ─────────────────────────────────────────────────────
func create_server(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Impossible de créer le serveur : " + str(err))
		return err
	multiplayer.multiplayer_peer = peer
	_register_local_player(SERVER_ID)
	server_created.emit()
	print("Serveur démarré sur le port ", port)
	return OK

func join_server(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Impossible de se connecter : " + str(err))
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	player_info.clear()
	disconnected_from_server.emit()

# ─── Échange d'informations joueur ───────────────────────────────────────────
func _register_local_player(peer_id: int) -> void:
	player_info[peer_id] = {
		"name": local_player_name,
		"team": local_player_team,
	}
	GameManager.register_player(peer_id, local_player_name, local_player_team)

@rpc("any_peer", "reliable")
func send_player_info(info: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	player_info[sender_id] = info
	GameManager.register_player(sender_id, info.get("name", "Inconnu"), info.get("team", 0))
	player_list_changed.emit()
	if multiplayer.is_server():
		_broadcast_player_list()

@rpc("authority", "reliable")
func receive_player_list(list: Dictionary) -> void:
	player_info = list
	for pid in list:
		var info: Dictionary = list[pid]
		GameManager.register_player(pid, info.get("name", "Inconnu"), info.get("team", 0))
	player_list_changed.emit()

func _broadcast_player_list() -> void:
	receive_player_list.rpc(player_info)

# ─── Callbacks réseau ─────────────────────────────────────────────────────────
func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	_register_local_player(my_id)
	send_player_info.rpc_id(SERVER_ID, player_info[my_id])
	joined_server.emit()
	print("Connecté au serveur, peer id : ", my_id)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()
	print("Échec de la connexion")

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	player_info.clear()
	disconnected_from_server.emit()
	print("Déconnecté du serveur")

func _on_peer_connected(peer_id: int) -> void:
	print("Pair connecté : ", peer_id)
	if multiplayer.is_server():
		_broadcast_player_list()
		_send_map_to_client.rpc_id(peer_id, current_map_scene)

@rpc("authority", "reliable")
func _send_map_to_client(map_path: String) -> void:
	current_map_scene = map_path

func _on_peer_disconnected(peer_id: int) -> void:
	player_info.erase(peer_id)
	player_list_changed.emit()
	print("Pair déconnecté : ", peer_id)

# ─── Utilitaires ─────────────────────────────────────────────────────────────
func is_server() -> bool:
	return multiplayer.is_server()

func get_local_id() -> int:
	return multiplayer.get_unique_id()

func get_player_count() -> int:
	return player_info.size()
