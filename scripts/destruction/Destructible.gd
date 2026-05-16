extends Node3D
class_name Destructible

# ─── Exports ─────────────────────────────────────────────────────────────────
@export var max_health: float         = 100.0
@export var debris_scene: PackedScene
@export var debris_count: int         = 8
@export var debris_force: float       = 8.0
@export var destroy_sound: AudioStream
@export var damage_threshold: float   = 0.3  # show damage below this %
@export var stages: Array[Node3D]     = []   # LOD-like visual stages

# ─── Signals ─────────────────────────────────────────────────────────────────
signal damaged_event(remaining_hp: float)
signal destroyed_event

# ─── State ───────────────────────────────────────────────────────────────────
var hp: float
var _destroyed: bool = false
var _stage: int = 0

func _ready() -> void:
	hp = max_health
	_update_stage()

func apply_damage(amount: float, hit_pos: Vector3) -> void:
	take_damage(amount, 0)
	_spawn_chunks(hit_pos, amount * 0.05)

func take_damage(amount: float, _source: int) -> void:
	if _destroyed:
		return
	hp = maxf(hp - amount, 0.0)
	damaged_event.emit(hp)
	_update_stage()
	if hp <= 0.0:
		_destroy()

func _update_stage() -> void:
	if stages.is_empty():
		return
	var pct := hp / max_health
	var new_stage := 0
	if pct < 0.66:
		new_stage = 1
	if pct < 0.33:
		new_stage = 2
	if new_stage != _stage:
		_stage = new_stage
		for i in stages.size():
			stages[i].visible = (i == _stage)

func _destroy() -> void:
	if _destroyed:
		return
	_destroyed = true
	destroyed_event.emit()
	if destroy_sound:
		AudioManager.play_3d(destroy_sound, global_position, 0.0)
	_spawn_debris()
	_collapse()

func _spawn_chunks(origin: Vector3, count_f: float) -> void:
	if not debris_scene:
		return
	var count: int = clamp(int(count_f), 1, 3)
	for i in count:
		var chunk: RigidBody3D = debris_scene.instantiate()
		get_tree().current_scene.add_child(chunk)
		chunk.global_position = origin + Vector3(
			randf_range(-0.5, 0.5), randf_range(0, 0.5), randf_range(-0.5, 0.5)
		)
		chunk.apply_central_impulse(Vector3(
			randf_range(-1, 1), randf_range(1, 3), randf_range(-1, 1)
		) * debris_force * 0.3)
		var timer := chunk.get_tree().create_timer(8.0)
		timer.timeout.connect(chunk.queue_free)

func _spawn_debris() -> void:
	if not debris_scene:
		_fade_out()
		return
	for i in debris_count:
		var piece: RigidBody3D = debris_scene.instantiate()
		get_tree().current_scene.add_child(piece)
		piece.global_position = global_position + Vector3(
			randf_range(-1, 1), randf_range(0, 1.5), randf_range(-1, 1)
		)
		piece.apply_central_impulse(Vector3(
			randf_range(-1, 1), randf_range(2, 6), randf_range(-1, 1)
		) * debris_force)
		var timer := piece.get_tree().create_timer(15.0)
		timer.timeout.connect(piece.queue_free)

func _collapse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.4)
	tween.tween_property(self, "position:y", position.y - 1.0, 0.2)
	await tween.finished
	queue_free()

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func repair(amount: float) -> void:
	if _destroyed:
		return
	hp = minf(hp + amount, max_health)
	_update_stage()

func is_destroyed() -> bool:
	return _destroyed
