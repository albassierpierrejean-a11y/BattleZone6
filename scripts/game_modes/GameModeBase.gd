extends Node
class_name GameModeBase

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var mode_name: String     = "Mode de jeu"
@export var round_duration: float = 600.0   # secondes
@export var warmup_time: float    = 15.0

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal round_started
signal round_ended(winner: int)
signal timer_updated(remaining: float)

# ─── État ────────────────────────────────────────────────────────────────────
var _time_remaining: float = 0.0
var _running: bool = false
var _warmup: bool = false

func _ready() -> void:
	if multiplayer.is_server():
		_begin_warmup()

func _process(delta: float) -> void:
	if not _running or not multiplayer.is_server():
		return
	_time_remaining -= delta
	timer_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_on_time_expired()

func _begin_warmup() -> void:
	_warmup = true
	_time_remaining = warmup_time
	_running = true
	await get_tree().create_timer(warmup_time).timeout
	start_round()

func start_round() -> void:
	_warmup = false
	_time_remaining = round_duration
	_running = true
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	round_started.emit()
	_on_round_start()

func end_round(winner: int) -> void:
	_running = false
	GameManager.set_game_state(GameManager.GameState.ROUND_END)
	round_ended.emit(winner)
	_on_round_end(winner)

func check_win_condition() -> void:
	pass

func _on_round_start() -> void:
	pass

func _on_round_end(_winner: int) -> void:
	pass

func _on_time_expired() -> void:
	var winner := _determine_winner_by_score()
	end_round(winner)

func _determine_winner_by_score() -> int:
	var alpha: int = int(GameManager.team_scores.get(GameManager.Team.ALPHA, 0))
	var bravo: int = int(GameManager.team_scores.get(GameManager.Team.BRAVO, 0))
	if alpha > bravo:
		return GameManager.Team.ALPHA
	elif bravo > alpha:
		return GameManager.Team.BRAVO
	return 0

func get_time_string() -> String:
	var mins := int(_time_remaining) / 60
	var secs := int(_time_remaining) % 60
	return "%02d:%02d" % [mins, secs]
