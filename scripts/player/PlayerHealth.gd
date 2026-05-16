extends Node
class_name PlayerHealth

# ─── Constantes ──────────────────────────────────────────────────────────────
const MAX_HP           := 100.0
const MAX_ARMOR        := 100.0
const REGEN_DELAY      := 5.0
const REGEN_RATE       := 15.0
const ARMOR_ABSORB     := 0.4

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal health_changed(current: float, max_hp: float)
signal armor_changed(current: float, max_armor: float)
signal damaged(amount: float, source_id: int)
signal died(source_id: int)
signal healed(amount: float)

# ─── État ────────────────────────────────────────────────────────────────────
var hp: float = MAX_HP
var armor: float = 0.0
var _regen_timer: float = 0.0
var _is_dead: bool = false

@onready var _player: CharacterBody3D = get_parent()

func _process(delta: float) -> void:
	if _is_dead or hp >= MAX_HP:
		return
	_regen_timer -= delta
	if _regen_timer <= 0.0:
		_do_regen(delta)

func _do_regen(delta: float) -> void:
	var old_hp := hp
	hp = minf(hp + REGEN_RATE * delta, MAX_HP)
	if hp != old_hp:
		health_changed.emit(hp, MAX_HP)

func take_damage(amount: float, source_id: int) -> void:
	if _is_dead:
		return
	_regen_timer = REGEN_DELAY
	var actual := amount
	if armor > 0.0:
		var absorbed := minf(actual * ARMOR_ABSORB, armor)
		armor -= absorbed
		actual -= absorbed
		armor_changed.emit(armor, MAX_ARMOR)
	hp = maxf(hp - actual, 0.0)
	health_changed.emit(hp, MAX_HP)
	damaged.emit(actual, source_id)
	if hp <= 0.0:
		_die(source_id)

func heal(amount: float) -> void:
	if _is_dead:
		return
	hp = minf(hp + amount, MAX_HP)
	health_changed.emit(hp, MAX_HP)
	healed.emit(amount)

func add_armor(amount: float) -> void:
	armor = minf(armor + amount, MAX_ARMOR)
	armor_changed.emit(armor, MAX_ARMOR)

func reset() -> void:
	hp = MAX_HP
	armor = 0.0
	_is_dead = false
	_regen_timer = 0.0
	health_changed.emit(hp, MAX_HP)
	armor_changed.emit(armor, MAX_ARMOR)

func _die(source_id: int) -> void:
	_is_dead = true
	died.emit(source_id)
	_spawn_death_vfx()
	if _player.has_method("die"):
		_player.die(source_id)

func _spawn_death_vfx() -> void:
	if not is_instance_valid(_player):
		return
	var root := get_tree().current_scene
	var pos  := _player.global_position + Vector3.UP * 0.9
	var blood := CPUParticles3D.new()
	root.add_child(blood)
	blood.global_position      = pos
	blood.one_shot             = true
	blood.explosiveness        = 0.85
	blood.amount               = 22
	blood.lifetime             = 0.7
	blood.initial_velocity_min = 2.5
	blood.initial_velocity_max = 7.0
	blood.spread               = 65.0
	blood.gravity              = Vector3(0.0, -14.0, 0.0)
	blood.scale_amount_min     = 0.022
	blood.scale_amount_max     = 0.058
	blood.color                = Color(0.65, 0.03, 0.03, 1.0)
	blood.emitting             = true
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(blood): blood.queue_free())

func is_dead() -> bool:
	return _is_dead

func get_health_percent() -> float:
	return hp / MAX_HP
