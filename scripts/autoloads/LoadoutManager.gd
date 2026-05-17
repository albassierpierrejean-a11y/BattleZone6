extends Node

signal loadout_changed

const SAVE_PATH     := "user://loadout.cfg"
const OperatorData  = preload("res://scripts/resources/OperatorData.gd")
const ItemData      = preload("res://scripts/resources/ItemData.gd")
const AccessoryData = preload("res://scripts/resources/AccessoryData.gd")
const WeaponData    = preload("res://scripts/resources/WeaponData.gd")
const WeaponBase    = preload("res://scripts/weapons/WeaponBase.gd")

# ─── Registres ────────────────────────────────────────────────────────────────
var operators:   Dictionary = {}   # id -> OperatorData
var items:       Dictionary = {}   # id -> ItemData
var accessories: Dictionary = {}   # id -> AccessoryData
var weapons:     Dictionary = {}   # id -> WeaponData

# ─── Loadout actif ────────────────────────────────────────────────────────────
var operator_id: String = "ghost"
var tactical_id: String = "smoke_grenade"
var lethal_id:   String = "frag_grenade"
var primary_id:  String = "assault_rifle"
var secondary_id: String = "pistol"
var accessories_by_weapon: Dictionary = {}  # weapon_id -> Array[String] (5 slots, ordre AccessoryData.Slot)

func _ready() -> void:
	_build_operators()
	_build_items()
	_build_accessories()
	_build_weapons()
	_load()

# ──────────────────────────────────────────────────────────────────────────────
# OPÉRATEURS
# ──────────────────────────────────────────────────────────────────────────────
func _build_operators() -> void:
	# ── ASSAULT ──────────────────────────────────────────────────────────────
	_op("ghost",  "GHOST",
		"Infiltrateur silencieux. Neutralise toute signature sonore en mouvement.",
		OperatorData.Faction.ASSAULT, 100, 0, 1.15,
		"SILENT STEP", "Pas inaudibles et vitesse +20 % pendant 6 s.", 30.0, 1)

	_op("viper",  "VIPER",
		"Médecin de combat. Stabilise les blessés sous le feu ennemi.",
		OperatorData.Faction.ASSAULT, 115, 5, 0.95,
		"STIM PACK", "Soin instantané de 60 PV + immunité aux saignements 8 s.", 35.0, 3)

	_op("iron",   "IRON",
		"Briseur de lignes blindé. Absorbe les dégâts en première ligne.",
		OperatorData.Faction.ASSAULT, 140, 30, 0.82,
		"FORTIFY", "Déploie un bouclier balistique portable — bloque les balles de face.", 45.0, 6)

	# ── RECON ─────────────────────────────────────────────────────────────────
	_op("phantom", "PHANTOM",
		"Tireur d'élite fantôme. Opère en dehors du rayon de détection ennemi.",
		OperatorData.Faction.RECON, 90, 0, 1.05,
		"RECON DRONE", "Lance un drone qui révèle les ennemis sur la minimap 10 s.", 40.0, 5)

	_op("cipher",  "CIPHER",
		"Spécialiste de la guerre électronique. Contrôle l'espace informationnel.",
		OperatorData.Faction.RECON, 95, 0, 1.00,
		"BLACKOUT", "Brouille la minimap et les HUD ennemis dans un rayon de 25 m pendant 8 s.", 50.0, 8)

	_op("shade",   "SHADE",
		"Agent de renseignement furtif. Expert de la couverture et de la dissimulation.",
		OperatorData.Faction.RECON, 98, 5, 1.10,
		"SMOKE SCREEN", "Déploie 3 grenades fumigènes simultanément en éventail.", 28.0, 10)

	# ── SUPPORT ───────────────────────────────────────────────────────────────
	_op("forge",   "FORGE",
		"Logisticien de terrain. Ravitaille l'équipe en munitions et équipements.",
		OperatorData.Faction.SUPPORT, 110, 10, 0.92,
		"RESUPPLY DROP", "Largue une caisse de munitions utilisable par toute l'équipe.", 60.0, 4)

	_op("bastion", "BASTION",
		"Défenseur fortifié. Transforme n'importe quelle position en point de résistance.",
		OperatorData.Faction.SUPPORT, 135, 20, 0.88,
		"BARRICADE", "Déploie instantanément deux barricades blindées devant lui.", 40.0, 7)

	_op("nova",    "NOVA",
		"Technicienne d'assaut. Exploite les failles tactiques avec des gadgets offensifs.",
		OperatorData.Faction.SUPPORT, 100, 0, 1.08,
		"EMP BURST", "Émet une impulsion EMP qui désactive les gadgets ennemis proches 6 s.", 45.0, 12)

func _op(id: String, name: String, desc: String,
		faction: OperatorData.Faction, hp: int, armor: int, speed: float,
		abl_name: String, abl_desc: String, cooldown: float, unlock: int) -> void:
	var o := OperatorData.new()
	o.id                 = id
	o.display_name       = name
	o.description        = desc
	o.faction            = faction
	o.max_health         = hp
	o.armor              = armor
	o.move_speed         = speed
	o.ability_name       = abl_name
	o.ability_description = abl_desc
	o.ability_cooldown   = cooldown
	o.unlock_level       = unlock
	operators[id]        = o

# ──────────────────────────────────────────────────────────────────────────────
# ITEMS
# ──────────────────────────────────────────────────────────────────────────────
func _build_items() -> void:
	# ── Létaux ────────────────────────────────────────────────────────────────
	_item("frag_grenade",  "Grenade Frag",    ItemData.ItemType.LETHAL,
		"Explosion à fragmentation. Rayon de 4 m, dégâts décroissants.",   2, 1.2, 0.0, 1)
	_item("c4",            "Charge C4",       ItemData.ItemType.LETHAL,
		"Explosif télécommandé. Pose au contact, détonation manuelle.",     1, 2.0, 0.0, 9)
	_item("claymore",      "Claymore",        ItemData.ItemType.LETHAL,
		"Mine directionnelle. Se déclenche au passage d'un ennemi.",        1, 3.0, 0.0, 6)
	_item("thermite",      "Grenade Thermite", ItemData.ItemType.LETHAL,
		"Brûle les surfaces et les véhicules. Ignore l'armure.",            1, 1.5, 0.0, 14)

	# ── Tactiques ─────────────────────────────────────────────────────────────
	_item("smoke_grenade", "Grenade Fumée",   ItemData.ItemType.TACTICAL,
		"Couvre une zone de fumée opaque pendant 10 s.",                    2, 1.0, 0.0, 1)
	_item("flash_grenade", "Grenade Flash",   ItemData.ItemType.TACTICAL,
		"Aveugle et étourdit les ennemis dans un cône de 6 m.",             2, 1.0, 0.0, 2)
	_item("stun_grenade",  "Grenade Étourdissante", ItemData.ItemType.TACTICAL,
		"Désactive les mouvements et la visée 3 s sans aveugler.",          2, 1.0, 0.0, 5)
	_item("decoy",         "Leurre Sonore",   ItemData.ItemType.TACTICAL,
		"Simule des pas et des tirs pour distraire l'ennemi.",              1, 1.5, 0.0, 8)

	# ── Support ────────────────────────────────────────────────────────────────
	_item("med_kit",       "Kit Médical",     ItemData.ItemType.SUPPORT,
		"Soin progressif de 80 PV sur 4 s. Annulé si touché.",             1, 3.5, 15.0, 1)
	_item("ammo_pack",     "Pack Munitions",  ItemData.ItemType.SUPPORT,
		"Recharge toutes les armes à 75 % de leur réserve max.",            1, 2.0, 20.0, 3)

	# ── Killstreaks ───────────────────────────────────────────────────────────
	_item("airstrike",     "Frappe Aérienne", ItemData.ItemType.KILLSTREAK,
		"Balise de désignation de cible. Déclenche un bombardement 4 s après pose.", 1, 2.5, 0.0, 15)
	_item("recon_pack",    "Pack Reco",       ItemData.ItemType.KILLSTREAK,
		"Révèle tous les ennemis dans un rayon de 50 m pendant 12 s.",      1, 2.0, 0.0, 11)

func _item(id: String, name: String, type: ItemData.ItemType,
		desc: String, stack: int, use_time: float, cooldown: float, unlock: int) -> void:
	var it := ItemData.new()
	it.id           = id
	it.display_name = name
	it.item_type    = type
	it.description  = desc
	it.max_stack    = stack
	it.use_time     = use_time
	it.cooldown     = cooldown
	it.unlock_level = unlock
	items[id]       = it

# ──────────────────────────────────────────────────────────────────────────────
# ACCESSOIRES
# ──────────────────────────────────────────────────────────────────────────────
func _build_accessories() -> void:
	# ── Optiques ──────────────────────────────────────────────────────────────
	_acc("red_dot",       "Point Rouge",       AccessoryData.Slot.OPTIC,
		"Viseur à point rouge. ADS rapide, mise en joue +15 %.",
		1.0, 1.0, 1.0, 1.15, 1.0, 0, 1.5, false, [], 1)
	_acc("holographic",   "Holographique",     AccessoryData.Slot.OPTIC,
		"Réticule holographique. Précision +10 %, ADS +8 %.",
		1.0, 1.0, 0.95, 1.08, 1.0, 0, 1.5, false, [], 4)
	_acc("acog",          "Lunette ACOG x4",   AccessoryData.Slot.OPTIC,
		"Grossissement ×4. Portée +40 %, ADS plus lent.",
		1.0, 1.4, 1.0, 0.75, 0.95, 0, 4.0, false, [], 7)
	_acc("sniper_scope",  "Lunette 8x",        AccessoryData.Slot.OPTIC,
		"Longue portée extrême. Portée +80 %, mouvement –10 %.",
		1.0, 1.8, 1.0, 0.55, 0.90, 0, 8.0, false, ["sniper_rifle"], 10)

	# ── Canons ────────────────────────────────────────────────────────────────
	_acc("suppressor",    "Silencieux",        AccessoryData.Slot.BARREL,
		"Tirs inaudibles. Dégâts –5 %, précision +12 %.",
		0.95, 1.0, 0.88, 1.0, 1.0, 0, 1.0, true, [], 5)
	_acc("muzzle_brake",  "Frein de Bouche",   AccessoryData.Slot.BARREL,
		"Réduit le recul vertical de 20 %.",
		1.0, 1.0, 0.80, 1.0, 1.0, 0, 1.0, false, [], 2)
	_acc("flash_hider",   "Cache-Flamme",      AccessoryData.Slot.BARREL,
		"Élimine le flash de bouche. Recul latéral –15 %.",
		1.0, 1.0, 0.90, 1.05, 1.0, 0, 1.0, false, [], 3)
	_acc("heavy_barrel",  "Canon Lourd",       AccessoryData.Slot.BARREL,
		"Dégâts +10 %, portée +15 %, recul +20 %.",
		1.10, 1.15, 1.20, 0.90, 0.95, 0, 1.0, false, [], 8)

	# ── Sous-canons ───────────────────────────────────────────────────────────
	_acc("foregrip",      "Poignée Avant",     AccessoryData.Slot.UNDERBARREL,
		"Recul vertical –18 %, stabilisation ADS +10 %.",
		1.0, 1.0, 0.82, 1.10, 1.0, 0, 1.0, false, [], 2)
	_acc("bipod",         "Bipied",            AccessoryData.Slot.UNDERBARREL,
		"Précision maximale en position couchée. ADS –10 % debout.",
		1.0, 1.0, 0.70, 0.90, 1.0, 0, 1.0, false, [], 6)
	_acc("angled_grip",   "Poignée Angulée",   AccessoryData.Slot.UNDERBARREL,
		"ADS +12 %, recul latéral –10 %.",
		1.0, 1.0, 0.90, 1.12, 1.0, 0, 1.0, false, [], 4)

	# ── Chargeurs ─────────────────────────────────────────────────────────────
	_acc("extended_mag",  "Chargeur Étendu",   AccessoryData.Slot.MAGAZINE,
		"+10 cartouches. Rechargement +0.3 s.",
		1.0, 1.0, 1.0, 0.95, 1.0, 10, 1.0, false, [], 3)
	_acc("drum_mag",      "Chargeur Tambour",  AccessoryData.Slot.MAGAZINE,
		"+30 cartouches. Rechargement nettement plus lent.",
		1.0, 1.0, 1.0, 0.80, 0.92, 30, 1.0, false, ["assault_rifle"], 9)
	_acc("fmj_rounds",    "Balles FMJ",        AccessoryData.Slot.MAGAZINE,
		"Pénétration des matériaux. Dégâts sur véhicules +20 %.",
		1.05, 1.0, 1.0, 1.0, 1.0, 0, 1.0, false, [], 7)

	# ── Crosses ───────────────────────────────────────────────────────────────
	_acc("lightweight_stock", "Crosse Légère", AccessoryData.Slot.STOCK,
		"Mobilité +8 %, ADS +10 %. Légèrement moins stable.",
		1.0, 1.0, 1.08, 1.10, 1.08, 0, 1.0, false, [], 2)
	_acc("tactical_stock",    "Crosse Tactique", AccessoryData.Slot.STOCK,
		"Recul vertical –15 %, stabilité ADS +12 %.",
		1.0, 1.0, 0.85, 1.12, 1.0, 0, 1.0, false, [], 5)
	_acc("no_stock",          "Sans Crosse",   AccessoryData.Slot.STOCK,
		"ADS +20 %, mobilité +12 %. Recul fortement augmenté.",
		1.0, 1.0, 1.35, 1.20, 1.12, 0, 1.0, false, ["pistol"], 1)

func _acc(id: String, name: String, slot: AccessoryData.Slot,
		desc: String, dmg: float, range_m: float, recoil: float,
		ads: float, move: float, mag_add: int, zoom: float,
		supp: bool, compat: Array, unlock: int) -> void:
	var a := AccessoryData.new()
	a.id                  = id
	a.display_name        = name
	a.slot                = slot
	a.description         = desc
	a.damage_mult         = dmg
	a.range_mult          = range_m
	a.recoil_mult         = recoil
	a.ads_speed_mult      = ads
	a.move_speed_mult     = move
	a.mag_size_add        = mag_add
	a.zoom_level          = zoom
	a.suppressed          = supp
	a.compatible_weapons  = compat
	a.unlock_level        = unlock
	accessories[id]       = a

# ──────────────────────────────────────────────────────────────────────────────
# ACCESSEURS
# ──────────────────────────────────────────────────────────────────────────────
func get_operator() -> OperatorData:
	return operators.get(operator_id)

func get_tactical() -> ItemData:
	return items.get(tactical_id)

func get_lethal() -> ItemData:
	return items.get(lethal_id)

func get_accessory_in_slot(weapon_id: String, slot: AccessoryData.Slot) -> AccessoryData:
	var slots: Array = accessories_by_weapon.get(weapon_id, [])
	if slot >= slots.size() or slots[slot].is_empty():
		return null
	return accessories.get(slots[slot])

func get_unlocked_operators() -> Array[OperatorData]:
	var lvl := ProgressionManager.level
	var result: Array[OperatorData] = []
	for op: OperatorData in operators.values():
		if op.unlock_level <= lvl:
			result.append(op)
	return result

func get_unlocked_accessories(slot: AccessoryData.Slot) -> Array[AccessoryData]:
	var lvl := ProgressionManager.level
	var result: Array[AccessoryData] = []
	for acc: AccessoryData in accessories.values():
		if acc.slot == slot and acc.unlock_level <= lvl:
			result.append(acc)
	return result

func get_unlocked_items(type: ItemData.ItemType) -> Array[ItemData]:
	var lvl := ProgressionManager.level
	var result: Array[ItemData] = []
	for it: ItemData in items.values():
		if it.item_type == type and it.unlock_level <= lvl:
			result.append(it)
	return result

# ──────────────────────────────────────────────────────────────────────────────
# MUTATIONS
# ──────────────────────────────────────────────────────────────────────────────
func set_operator(id: String) -> void:
	if id in operators:
		operator_id = id
		_save()
		loadout_changed.emit()

func set_tactical(id: String) -> void:
	if id in items:
		tactical_id = id
		_save()
		loadout_changed.emit()

func set_lethal(id: String) -> void:
	if id in items:
		lethal_id = id
		_save()
		loadout_changed.emit()

# ──────────────────────────────────────────────────────────────────────────────
# ARMES
# ──────────────────────────────────────────────────────────────────────────────
func _build_weapons() -> void:
	# ── Primaires ──────────────────────────────────────────────────────────────
	_wpn("assault_rifle", "M416",         WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.ASSAULT_RIFLE,
		"Fusil d'assaut polyvalent. Fiable à toute distance.",             1,  45, 75, 55, 70, 60)
	_wpn("smg",           "MP5K",          WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.SMG,
		"SMG compact. Idéal en CQC, imprécis à longue portée.",            2,  30, 90, 30, 85, 55)
	_wpn("lmg",           "M249",          WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.LMG,
		"Mitrailleuse légère. Suppression massive, mobilité réduite.",      8,  55, 80, 60, 35, 40)
	_wpn("sniper_rifle",  "SR-98",         WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.SNIPER,
		"Précision chirurgicale. Un coup, une kill.",                       4,  95, 20, 100, 25, 95)
	_wpn("shotgun",       "Remington 870", WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.SHOTGUN,
		"Dévastateur au corps-à-corps. Inutile à distance.",               5,  80, 25, 20,  65, 35)
	_wpn("dmr",           "M14 EBR",       WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponType.DMR,
		"Fusil de précision semi-auto. Portée et cadence équilibrées.",    6,  70, 40, 75,  55, 80)
	# ── Secondaires ────────────────────────────────────────────────────────────
	_wpn("pistol",        "M9",            WeaponData.WeaponSlot.SECONDARY, WeaponData.WeaponType.PISTOL,
		"Pistolet fiable. Backup disponible en toutes circonstances.",      1,  35, 55, 35,  90, 50)
	_wpn("revolver",      "Colt Python",   WeaponData.WeaponSlot.SECONDARY, WeaponData.WeaponType.REVOLVER,
		"Revolver puissant. 6 cartouches — chaque tir doit compter.",       7,  80, 30, 45,  85, 60)
	_wpn("rpg",           "RPG-7",         WeaponData.WeaponSlot.SECONDARY, WeaponData.WeaponType.LAUNCHER,
		"Lance-roquettes. Destruction de véhicules et de zones.",           10, 100, 10, 80,  20, 30)
	_wpn("micro_uzi",     "Micro UZI",     WeaponData.WeaponSlot.SECONDARY, WeaponData.WeaponType.SMG,
		"SMG ultra-compact. Cadence folle, précision nulle.",               3,  22, 95, 20,  92, 30)

func _wpn(id: String, name: String, slot: WeaponData.WeaponSlot, type: WeaponData.WeaponType,
		desc: String, unlock: int,
		dmg: int, rate: int, range_v: int, mob: int, acc: int) -> void:
	var w := WeaponData.new()
	w.id            = id
	w.display_name  = name
	w.weapon_slot   = slot
	w.weapon_type   = type
	w.description   = desc
	w.unlock_level  = unlock
	w.stat_damage   = dmg
	w.stat_fire_rate = rate
	w.stat_range    = range_v
	w.stat_mobility = mob
	w.stat_accuracy = acc
	weapons[id]     = w

func get_unlocked_weapons(slot: WeaponData.WeaponSlot) -> Array[WeaponData]:
	var lvl := ProgressionManager.level
	var result: Array[WeaponData] = []
	for w: WeaponData in weapons.values():
		if w.weapon_slot == slot and w.unlock_level <= lvl:
			result.append(w)
	return result

func get_primary() -> WeaponData:
	return weapons.get(primary_id)

func get_secondary() -> WeaponData:
	return weapons.get(secondary_id)

func set_primary(id: String) -> void:
	if id in weapons:
		primary_id = id
		_save()
		loadout_changed.emit()

func set_secondary(id: String) -> void:
	if id in weapons:
		secondary_id = id
		_save()
		loadout_changed.emit()

func set_accessory(weapon_id: String, slot: AccessoryData.Slot, acc_id: String) -> void:
	if acc_id != "" and acc_id not in accessories:
		return
	if weapon_id not in accessories_by_weapon:
		accessories_by_weapon[weapon_id] = ["", "", "", "", ""]
	accessories_by_weapon[weapon_id][slot] = acc_id
	_save()
	loadout_changed.emit()

# ──────────────────────────────────────────────────────────────────────────────
# APPLICATION AU JOUEUR / AUX ARMES
# ──────────────────────────────────────────────────────────────────────────────
func apply_operator_to_player(player: Node) -> void:
	var op := get_operator()
	if not op:
		return
	var ph := player.get_node_or_null("PlayerHealth")
	if ph:
		ph.set("max_health", op.max_health)
		if ph.has_method("reset"):
			ph.reset()
	player.set_meta("op_speed_mult", op.move_speed)
	player.set_meta("op_armor",      op.armor)

func apply_accessories_to_weapon(weapon: WeaponBase, weapon_id: String) -> void:
	var slots: Array = accessories_by_weapon.get(weapon_id, [])
	for i in slots.size():
		if slots[i].is_empty():
			continue
		var acc: AccessoryData = accessories.get(slots[i])
		if not acc:
			continue
		if acc.compatible_weapons.size() > 0 and weapon_id not in acc.compatible_weapons:
			continue
		weapon.damage        *= acc.damage_mult
		weapon.range_max     *= acc.range_mult
		weapon.recoil_pitch  *= acc.recoil_mult
		weapon.recoil_yaw    *= acc.recoil_mult
		weapon.mag_size      += acc.mag_size_add
		weapon.current_ammo   = weapon.mag_size
		if acc.suppressed:
			weapon.set_meta("suppressed", true)
		if acc.zoom_level > 1.0:
			weapon.ads_fov_mult = 1.0 / acc.zoom_level

# ──────────────────────────────────────────────────────────────────────────────
# PERSISTANCE
# ──────────────────────────────────────────────────────────────────────────────
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "operator",    operator_id)
	cfg.set_value("loadout", "tactical",    tactical_id)
	cfg.set_value("loadout", "lethal",      lethal_id)
	cfg.set_value("loadout", "primary",     primary_id)
	cfg.set_value("loadout", "secondary",   secondary_id)
	cfg.set_value("loadout", "accessories", accessories_by_weapon)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	operator_id           = cfg.get_value("loadout", "operator",     "ghost")
	tactical_id           = cfg.get_value("loadout", "tactical",     "smoke_grenade")
	lethal_id             = cfg.get_value("loadout", "lethal",       "frag_grenade")
	primary_id            = cfg.get_value("loadout", "primary",      "assault_rifle")
	secondary_id          = cfg.get_value("loadout", "secondary",    "pistol")
	accessories_by_weapon = cfg.get_value("loadout", "accessories",  {})
	if operator_id not in operators:   operator_id   = "ghost"
	if tactical_id not in items:       tactical_id   = "smoke_grenade"
	if lethal_id   not in items:       lethal_id     = "frag_grenade"
	if primary_id  not in weapons:     primary_id    = "assault_rifle"
	if secondary_id not in weapons:    secondary_id  = "pistol"
