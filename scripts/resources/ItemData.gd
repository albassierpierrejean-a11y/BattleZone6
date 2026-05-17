class_name ItemData
extends Resource

enum ItemType { LETHAL, TACTICAL, SUPPORT, KILLSTREAK }

@export var id:           String   = ""
@export var display_name: String   = ""
@export var description:  String   = ""
@export var item_type:    ItemType = ItemType.TACTICAL
@export var max_stack:    int      = 2
@export var use_time:     float    = 0.5
@export var cooldown:     float    = 0.0
@export var unlock_level: int      = 1
