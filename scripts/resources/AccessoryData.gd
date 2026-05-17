class_name AccessoryData
extends Resource

enum Slot { OPTIC, BARREL, UNDERBARREL, MAGAZINE, STOCK }

@export var id:              String = ""
@export var display_name:    String = ""
@export var description:     String = ""
@export var slot:            Slot   = Slot.OPTIC
@export var unlock_level:    int    = 1

# Multiplicateurs de stats (1.0 = neutre)
@export var damage_mult:     float = 1.0
@export var range_mult:      float = 1.0
@export var recoil_mult:     float = 1.0
@export var ads_speed_mult:  float = 1.0
@export var move_speed_mult: float = 1.0
@export var mag_size_add:    int   = 0
@export var zoom_level:      float = 1.0
@export var suppressed:      bool  = false
@export var compatible_weapons: Array = []  # vide = universel
