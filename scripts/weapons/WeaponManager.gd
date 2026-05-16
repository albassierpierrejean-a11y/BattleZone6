extends Node3D
class_name WeaponManager

# ─── Constantes ──────────────────────────────────────────────────────────────
const MAX_WEAPONS := 3
const SWITCH_TIME := 0.22

# ─── Signaux ─────────────────────────────────────────────────────────────────
signal weapon_switched(slot: int, weapon: WeaponBase)
signal ammo_updated(current: int, reserve: int)

# ─── État ────────────────────────────────────────────────────────────────────
var weapons:      Array[WeaponBase] = []
var current_slot: int     = 0
var _switching:   bool    = false
var _sway_pos:    Vector3 = Vector3.ZERO
var _sway_rot_x:  float   = 0.0
var _sway_rot_y:  float   = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	for child in get_children():
		if child is WeaponBase:
			weapons.append(child)
	for i in weapons.size():
		weapons[i].visible = (i == 0)
		weapons[i].ammo_changed.connect(func(c, r): ammo_updated.emit(c, r))
	if weapons.size() > 0:
		weapons[0].equip()

func _process(delta: float) -> void:
	if not _is_local_player():
		_mouse_delta = Vector2.ZERO
		return
	if not _switching:
		_check_slot_input()
	_update_weapon_transform(delta)

func _input(event: InputEvent) -> void:
	if not _is_local_player():
		return
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative
	if _switching:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_prev()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_next()

func _check_slot_input() -> void:
	if Input.is_action_just_pressed("weapon_1"): switch_to(0)
	elif Input.is_action_just_pressed("weapon_2"): switch_to(1)
	elif Input.is_action_just_pressed("weapon_3"): switch_to(2)

func switch_to(slot: int) -> void:
	if slot == current_slot or slot >= weapons.size() or _switching:
		return
	_switching   = true
	_sway_pos    = Vector3.ZERO
	_sway_rot_x  = 0.0
	_sway_rot_y  = 0.0
	weapons[current_slot].unequip()
	current_slot = slot
	await get_tree().create_timer(SWITCH_TIME).timeout
	weapons[current_slot].equip()
	var w := weapons[current_slot]
	ammo_updated.emit(w.current_ammo, w.reserve_ammo)
	weapon_switched.emit(current_slot, w)
	_switching = false

func switch_next() -> void:
	switch_to((current_slot + 1) % weapons.size())

func switch_prev() -> void:
	switch_to((current_slot - 1 + weapons.size()) % weapons.size())

func get_current_weapon() -> WeaponBase:
	if weapons.is_empty(): return null
	return weapons[current_slot]

func add_weapon(weapon: WeaponBase) -> bool:
	if weapons.size() >= MAX_WEAPONS:
		return false
	add_child(weapon)
	weapons.append(weapon)
	weapon.visible = false
	weapon.ammo_changed.connect(func(c, r): ammo_updated.emit(c, r))
	return true

func add_ammo(weapon_name: String, amount: int) -> bool:
	for w in weapons:
		if w.weapon_name == weapon_name:
			w.reserve_ammo += amount
			ammo_updated.emit(w.current_ammo, w.reserve_ammo)
			return true
	return false

func _is_local_player() -> bool:
	var n := get_parent()
	while n:
		if n is PlayerController:
			return n.is_multiplayer_authority()
		n = n.get_parent()
	return false

func _find_player() -> CharacterBody3D:
	var n: Node = get_parent()
	while n:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null

func _update_weapon_transform(delta: float) -> void:
	var weapon := get_current_weapon()
	if not weapon:
		return
	var is_ads    := Input.is_action_pressed("aim")
	var base_pos  := weapon.ads_position if is_ads else weapon.hip_position
	var sway_mult := 0.2 if is_ads else 1.0

	# Balancement souris — l'arme retarde sur la caméra
	var t_rot_y  := clampf(-_mouse_delta.x * 0.00042, -0.055, 0.055)
	var t_rot_x  := clampf(-_mouse_delta.y * 0.00042, -0.038, 0.038)
	_mouse_delta  = _mouse_delta.lerp(Vector2.ZERO, delta * 14.0)
	_sway_rot_x   = lerpf(_sway_rot_x, t_rot_x, delta * 6.5)
	_sway_rot_y   = lerpf(_sway_rot_y, t_rot_y, delta * 6.5)

	# Balancement de mouvement depuis la vélocité du joueur
	var player := _find_player()
	if player:
		var vel     := player.velocity
		var t_pos_x := clampf(-vel.x * 0.0008, -0.018, 0.018)
		var t_pos_y := clampf(-absf(vel.length()) * 0.0005, -0.007, 0.0)
		_sway_pos.x  = lerpf(_sway_pos.x, t_pos_x, delta * 5.0)
		_sway_pos.y  = lerpf(_sway_pos.y, t_pos_y, delta * 5.0)

	weapon.position   = base_pos + _sway_pos * sway_mult + weapon.anim_offset
	weapon.rotation.x = lerpf(weapon.rotation.x, _sway_rot_x * sway_mult, delta * 18.0) + weapon.anim_rot_x
	weapon.rotation.y = lerpf(weapon.rotation.y, _sway_rot_y * sway_mult, delta * 18.0)
