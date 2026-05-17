class_name OperatorData
extends Resource

enum Faction { ASSAULT, RECON, SUPPORT }

@export var id:                  String  = ""
@export var display_name:        String  = ""
@export var description:         String  = ""
@export var faction:             Faction = Faction.ASSAULT
@export_range(80, 200) var max_health:   int   = 100
@export_range(0,  50)  var armor:        int   = 0
@export_range(0.6, 1.6) var move_speed: float = 1.0
@export var ability_name:        String  = ""
@export var ability_description: String  = ""
@export_range(5.0, 120.0) var ability_cooldown: float = 30.0
@export var unlock_level:        int    = 1
