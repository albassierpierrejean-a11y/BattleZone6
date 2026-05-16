extends Node

# ─── Énumérations ────────────────────────────────────────────────────────────
enum Team { NONE = 0, ALPHA = 1, BRAVO = 2 }
enum GameState { LOBBY, COUNTDOWN, PLAYING, ROUND_END, GAME_OVER }

# ─── Constantes ──────────────────────────────────────────────────────────────
const RESPAWN_TIME    := 5.0
const MAX_PLAYERS     := 64
const TEAM_NAMES      := { Team.ALPHA: "Alpha", Team.BRAVO: "Bravo" }

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal game_state_changed(new_state: GameState)
signal player_spawned(player_id: int)
signal player_died_event(player_id: int, killer_id: int)
signal scores_updated(alpha: int, bravo: int)
signal round_ended(winner: Team)

# ─── État ────────────────────────────────────────────────────────────────────
var current_state: GameState = GameState.LOBBY
var players: Dictionary = {}         # peer_id → PlayerData
var team_scores: Dictionary = { Team.ALPHA: 0, Team.BRAVO: 0 }
var spawn_points: Dictionary = { Team.ALPHA: [], Team.BRAVO: [] }
var current_game_mode: Node = null
var round_time_remaining: float = 0.0
var local_player_id: int = 1

class PlayerData:
	var id: int
	var name: String
	var team: int
	var kills: int = 0
	var deaths: int = 0
	var score: int = 0
	var ping: int = 0
	var node: Node = null

	func _init(p_id: int, p_name: String, p_team: int) -> void:
		id = p_id
		name = p_name
		team = p_team

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func reset_for_new_map() -> void:
	spawn_points = { Team.ALPHA: [], Team.BRAVO: [] }
	players.clear()
	team_scores = { Team.ALPHA: 0, Team.BRAVO: 0 }
	current_state = GameState.LOBBY
	current_game_mode = null

# ─── Inscription des joueurs ──────────────────────────────────────────────────
func register_player(peer_id: int, player_name: String, team: int) -> void:
	var data := PlayerData.new(peer_id, player_name, team)
	players[peer_id] = data

func unregister_player(peer_id: int) -> void:
	players.erase(peer_id)

func get_player_data(peer_id: int) -> PlayerData:
	return players.get(peer_id, null)

# ─── État de la partie ────────────────────────────────────────────────────────
func set_game_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)

func is_playing() -> bool:
	return current_state == GameState.PLAYING

# ─── Système de réapparition ─────────────────────────────────────────────────
func register_spawn_point(team: int, point: Node3D) -> void:
	if team in spawn_points:
		spawn_points[team].append(point)

func get_spawn_position(team: int) -> Vector3:
	var points: Array = spawn_points.get(team, [])
	if points.is_empty():
		return Vector3(0, 2, 0)
	points.shuffle()
	return points[0].global_position

func request_respawn(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var data := get_player_data(peer_id)
	if not data:
		return
	data.deaths += 1
	await get_tree().create_timer(RESPAWN_TIME).timeout
	var pos := get_spawn_position(data.team)
	_do_respawn.rpc_id(peer_id, pos)

@rpc("authority", "reliable")
func _do_respawn(spawn_pos: Vector3) -> void:
	var player := _get_local_player()
	if player:
		player.respawn(spawn_pos)
	player_spawned.emit(multiplayer.get_unique_id())

# ─── Suivi des éliminations ───────────────────────────────────────────────────
@rpc("any_peer", "reliable")
func report_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server():
		return
	var killer := get_player_data(killer_id)
	var victim  := get_player_data(victim_id)
	if killer:
		killer.kills += 1
		killer.score += 100
	player_died_event.emit(victim_id, killer_id)
	request_respawn(victim_id)
	_broadcast_scores()

func _broadcast_scores() -> void:
	var alpha: int = int(team_scores.get(Team.ALPHA, 0))
	var bravo: int = int(team_scores.get(Team.BRAVO, 0))
	scores_updated.emit(alpha, bravo)

# ─── Score ────────────────────────────────────────────────────────────────────
func add_score(team: int, amount: int) -> void:
	team_scores[team] = team_scores.get(team, 0) + amount
	_broadcast_scores()
	if current_game_mode and current_game_mode.has_method("check_win_condition"):
		current_game_mode.check_win_condition()

func end_round(winner: Team) -> void:
	set_game_state(GameState.ROUND_END)
	round_ended.emit(winner)

# ─── Événements réseau ────────────────────────────────────────────────────────
func _on_peer_connected(peer_id: int) -> void:
	print("Pair connecté : ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	unregister_player(peer_id)
	print("Pair déconnecté : ", peer_id)

# ─── Utilitaires ─────────────────────────────────────────────────────────────
func _get_local_player() -> Node:
	return get_tree().get_first_node_in_group("local_player")

func get_team_player_count(team: int) -> int:
	var count := 0
	for p in players.values():
		if p.team == team:
			count += 1
	return count

func get_sorted_scoreboard() -> Array:
	var list := players.values()
	list.sort_custom(func(a, b): return a.score > b.score)
	return list
