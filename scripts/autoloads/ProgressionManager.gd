extends Node

signal xp_gained(total: int)
signal level_up(new_level: int, rank_title: String)

const SAVE_PATH := "user://progression.cfg"

const RANKS := [
	"RECRUE", "SOLDAT", "CAPORAL", "CAPORAL-CHEF",
	"SERGENT", "SERGENT-CHEF", "ADJUDANT", "ADJUDANT-CHEF",
	"SOUS-LIEUTENANT", "LIEUTENANT", "CAPITAINE",
	"COMMANDANT", "LIEUTENANT-COLONEL", "COLONEL", "GÉNÉRAL"
]

const XP_PER_KILL      := 30
const XP_PER_OBJECTIVE := 100
const XP_WIN_BONUS     := 500
const XP_PER_LEVEL     := 5000

var level:  int  = 1
var xp:     int  = 0
var kills:  int  = 0
var deaths: int  = 0
var wins:   int  = 0
var games:  int  = 0
var _session_kills: int = 0   # kills in current match only

func _ready() -> void:
	_load()

func get_rank_title() -> String:
	return RANKS[mini(level - 1, RANKS.size() - 1)]

func get_xp_for_level(lvl: int) -> int:
	return lvl * XP_PER_LEVEL

func get_xp_progress() -> float:
	var needed := get_xp_for_level(level)
	var prev   := get_xp_for_level(level - 1) if level > 1 else 0
	return float(xp - prev) / float(needed - prev)

func add_xp(amount: int) -> void:
	xp += amount
	xp_gained.emit(xp)
	var needed := get_xp_for_level(level)
	while xp >= needed:
		level += 1
		level_up.emit(level, get_rank_title())
		needed = get_xp_for_level(level)
	_save()

func record_kill() -> void:
	kills += 1
	_session_kills += 1
	add_xp(XP_PER_KILL)

func record_objective() -> void:
	add_xp(XP_PER_OBJECTIVE)

func record_match_end(won: bool) -> Dictionary:
	games += 1
	var breakdown := {}
	var kill_xp := _session_kills * XP_PER_KILL
	if kill_xp > 0:
		breakdown["Éliminations (%d)" % _session_kills] = kill_xp
	if won:
		wins += 1
		breakdown["Victoire d'équipe"] = XP_WIN_BONUS
		add_xp(XP_WIN_BONUS)   # only win bonus — kill XP already added in real-time
	_session_kills = 0
	_save()
	return breakdown

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progression", "level",  level)
	cfg.set_value("progression", "xp",     xp)
	cfg.set_value("progression", "kills",  kills)
	cfg.set_value("progression", "deaths", deaths)
	cfg.set_value("progression", "wins",   wins)
	cfg.set_value("progression", "games",  games)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	level  = cfg.get_value("progression", "level",  1)
	xp     = cfg.get_value("progression", "xp",     0)
	kills  = cfg.get_value("progression", "kills",  0)
	deaths = cfg.get_value("progression", "deaths", 0)
	wins   = cfg.get_value("progression", "wins",   0)
	games  = cfg.get_value("progression", "games",  0)
