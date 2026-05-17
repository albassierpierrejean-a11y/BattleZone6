extends "res://scripts/game_modes/GameModeBase.gd"

@export var kill_limit: int = 100

func _ready() -> void:
	mode_name      = "Équipes Deathmatch"
	round_duration = 600.0
	super._ready()
	GameManager.player_died_event.connect(_on_player_died)

func _on_player_died(victim_id: int, killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var killer := GameManager.get_player_data(killer_id)
	if killer:
		GameManager.team_scores[killer.team] = GameManager.team_scores.get(killer.team, 0) + 1
		GameManager.scores_updated.emit(
			GameManager.team_scores.get(GameManager.Team.ALPHA, 0),
			GameManager.team_scores.get(GameManager.Team.BRAVO, 0)
		)
	check_win_condition()

func check_win_condition() -> void:
	var alpha: int = int(GameManager.team_scores.get(GameManager.Team.ALPHA, 0))
	var bravo: int = int(GameManager.team_scores.get(GameManager.Team.BRAVO, 0))
	if alpha >= kill_limit:
		end_round(GameManager.Team.ALPHA)
	elif bravo >= kill_limit:
		end_round(GameManager.Team.BRAVO)
