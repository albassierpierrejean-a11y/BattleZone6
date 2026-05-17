class_name WeaponData
extends Resource

enum WeaponSlot { PRIMARY, SECONDARY }
enum WeaponType { ASSAULT_RIFLE, SMG, LMG, SNIPER, SHOTGUN, DMR, PISTOL, REVOLVER, LAUNCHER }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var weapon_slot: WeaponSlot = WeaponSlot.PRIMARY
@export var weapon_type: WeaponType = WeaponType.ASSAULT_RIFLE
@export var unlock_level: int = 1

# Barres de stats 0–100 (affichage uniquement)
@export var stat_damage:    int = 50
@export var stat_fire_rate: int = 50
@export var stat_range:     int = 50
@export var stat_mobility:  int = 50
@export var stat_accuracy:  int = 50
