extends Node
class_name LagCompensation

# ─── Constants ───────────────────────────────────────────────────────────────
const HISTORY_DURATION := 0.5   # seconds of position history to keep
const SNAPSHOT_RATE    := 0.05  # 20 snapshots/sec

# ─── State ───────────────────────────────────────────────────────────────────
var _history: Dictionary = {}   # peer_id → Array[{time, pos, rot}]
var _snapshot_timer: float = 0.0

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_RATE:
		_snapshot_timer = 0.0
		_record_snapshot()
	_prune_history()

func _record_snapshot() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for player in get_tree().get_nodes_in_group("players"):
		var pid := player.get_multiplayer_authority()
		if pid not in _history:
			_history[pid] = []
		_history[pid].append({
			"time": now,
			"pos": player.global_position,
			"rot": player.global_rotation,
		})

func _prune_history() -> void:
	var cutoff := Time.get_ticks_msec() / 1000.0 - HISTORY_DURATION
	for pid in _history:
		_history[pid] = _history[pid].filter(func(s): return s["time"] >= cutoff)

func get_player_position_at(peer_id: int, timestamp: float) -> Vector3:
	var history: Array = _history.get(peer_id, [])
	if history.is_empty():
		return Vector3.ZERO
	for i in range(history.size() - 1, -1, -1):
		if history[i]["time"] <= timestamp:
			if i + 1 < history.size():
				var a: Dictionary = history[i]
				var b: Dictionary = history[i + 1]
				var t: float = (timestamp - a["time"]) / (b["time"] - a["time"])
				return a["pos"].lerp(b["pos"], t)
			return history[i]["pos"]
	return history[0]["pos"]

func validate_hit(shooter_id: int, target_id: int, shooter_timestamp: float, claimed_pos: Vector3) -> bool:
	var expected := get_player_position_at(target_id, shooter_timestamp)
	var max_dist := 2.0 + (Time.get_ticks_msec() / 1000.0 - shooter_timestamp) * 5.0
	return expected.distance_to(claimed_pos) <= max_dist
