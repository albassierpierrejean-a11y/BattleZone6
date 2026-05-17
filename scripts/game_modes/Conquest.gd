extends GameModeBase
class_name ConquestMode

# ─── Constantes ──────────────────────────────────────────────────────────────
const TICKET_DRAIN_RATE  := 1.0    # tickets/sec par avantage de drapeaux
const CAPTURE_RADIUS     := 6.0
const CAPTURE_TIME       := 10.0
const FLAG_SCORE_BONUS   := 50

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var alpha_tickets: int = 300
@export var bravo_tickets: int = 300
@export var min_tickets: int   = 0

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal tickets_changed(alpha: int, bravo: int)
signal flag_captured(flag_id: int, team: int)
signal flag_contested(flag_id: int)
signal flag_neutralized(flag_id: int)

# ─── Classe interne ───────────────────────────────────────────────────────────
class FlagData:
	var id: int
	var node: Node3D
	var owner_team: int = 0   # 0 = neutre
	var capture_progress: float = 0.0  # -1=bravo, +1=alpha
	var flag_name: String = "Drapeau"

	func _init(p_id: int, p_node: Node3D, p_name: String) -> void:
		id = p_id
		node = p_node
		flag_name = p_name

# ─── État ────────────────────────────────────────────────────────────────────
var flags: Array = []
var _ticket_drain_timer: float = 0.0

func _ready() -> void:
	mode_name      = "Conquest"
	round_duration = 900.0
	super._ready()
	_discover_flags.call_deferred()

func _discover_flags() -> void:
	var flag_nodes := get_tree().get_nodes_in_group("capture_points")
	for i in flag_nodes.size():
		var n: Node3D = flag_nodes[i]
		var cp := FlagData.new(i, n, n.name)
		flags.append(cp)

func _process(delta: float) -> void:
	super._process(delta)
	if not _running or not multiplayer.is_server():
		return
	_update_flags(delta)
	_drain_tickets(delta)

func _update_flags(delta: float) -> void:
	var all_players := get_tree().get_nodes_in_group("players")
	for cp in flags:
		var alpha_count := _count_players_at(cp.node.global_position, GameManager.Team.ALPHA, all_players)
		var bravo_count := _count_players_at(cp.node.global_position, GameManager.Team.BRAVO, all_players)
		var net := float(alpha_count - bravo_count)

		if net == 0.0:
			continue

		var speed := delta / CAPTURE_TIME
		cp.capture_progress = clamp(cp.capture_progress + net * speed, -1.0, 1.0)

		var new_owner: int = GameManager.Team.NONE
		if cp.capture_progress >= 1.0:
			new_owner = GameManager.Team.ALPHA
		elif cp.capture_progress <= -1.0:
			new_owner = GameManager.Team.BRAVO

		if new_owner != cp.owner_team and new_owner != GameManager.Team.NONE:
			_on_flag_captured(cp, new_owner)

		_update_flag_visual(cp)

func _count_players_at(pos: Vector3, team: int, players: Array) -> int:
	var count := 0
	for p in players:
		if p is PlayerController:
			var pd := GameManager.get_player_data(p.peer_id)
			if pd and pd.team == team:
				if p.global_position.distance_squared_to(pos) <= CAPTURE_RADIUS * CAPTURE_RADIUS:
					count += 1
	return count

func _on_flag_captured(cp: FlagData, new_team: int) -> void:
	cp.owner_team = new_team
	GameManager.add_score(new_team, FLAG_SCORE_BONUS)
	flag_captured.emit(cp.id, new_team)
	_sync_flag_state.rpc(cp.id, new_team, cp.capture_progress)
	print("Drapeau %s capturé par l'équipe %d" % [cp.flag_name, new_team])

func _update_flag_visual(cp: FlagData) -> void:
	if cp.node.has_method("set_capture_progress"):
		cp.node.set_capture_progress(cp.capture_progress, cp.owner_team)

func _drain_tickets(delta: float) -> void:
	_ticket_drain_timer += delta
	if _ticket_drain_timer < 1.0:
		return
	_ticket_drain_timer = 0.0

	var alpha_flags := _count_team_flags(GameManager.Team.ALPHA)
	var bravo_flags := _count_team_flags(GameManager.Team.BRAVO)

	if bravo_flags > alpha_flags:
		var deficit := bravo_flags - alpha_flags
		alpha_tickets -= int(TICKET_DRAIN_RATE * deficit)
	elif alpha_flags > bravo_flags:
		var deficit := alpha_flags - bravo_flags
		bravo_tickets -= int(TICKET_DRAIN_RATE * deficit)

	alpha_tickets = maxi(alpha_tickets, min_tickets)
	bravo_tickets = maxi(bravo_tickets, min_tickets)
	tickets_changed.emit(alpha_tickets, bravo_tickets)
	_sync_tickets.rpc(alpha_tickets, bravo_tickets)
	check_win_condition()

func _count_team_flags(team: int) -> int:
	var count := 0
	for cp in flags:
		if cp.owner_team == team:
			count += 1
	return count

func check_win_condition() -> void:
	if alpha_tickets <= min_tickets:
		end_round(GameManager.Team.BRAVO)
	elif bravo_tickets <= min_tickets:
		end_round(GameManager.Team.ALPHA)

@rpc("authority", "reliable")
func _sync_flag_state(flag_id: int, team: int, progress: float) -> void:
	if flag_id < flags.size():
		flags[flag_id].owner_team = team
		flags[flag_id].capture_progress = progress

@rpc("authority", "reliable")
func _sync_tickets(a: int, b: int) -> void:
	alpha_tickets = a
	bravo_tickets = b
	tickets_changed.emit(a, b)

func get_alpha_tickets() -> int:
	return alpha_tickets

func get_bravo_tickets() -> int:
	return bravo_tickets

func get_flag_count() -> int:
	return flags.size()
