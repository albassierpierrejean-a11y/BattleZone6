extends RigidBody3D
class_name Grenade

@export var fuse_time: float     = 3.5
@export var explosion_radius: float = 5.0
@export var explosion_damage: float = 120.0
@export var throw_force: float   = 15.0

var _owner_id: int = 1
var _exploded: bool = false

func _ready() -> void:
	await get_tree().create_timer(fuse_time).timeout
	explode()

func throw_from(origin: Vector3, direction: Vector3, owner_id: int) -> void:
	_owner_id = owner_id
	global_position = origin
	apply_central_impulse(direction * throw_force + Vector3.UP * 4.0)

func explode() -> void:
	if _exploded:
		return
	_exploded = true
	_do_explosion()
	queue_free()

func _do_explosion() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = global_transform
	var hits: Array = space.intersect_shape(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if not collider or not (collider is Node3D):
			continue
		var node: Node3D = collider
		var dist: float = (node.global_position - global_position).length()
		var falloff: float = 1.0 - clamp(dist / explosion_radius, 0.0, 1.0)
		var dmg: float = explosion_damage * falloff
		if collider.has_method("take_damage"):
			collider.take_damage(dmg, _owner_id)
		if collider.has_method("apply_damage"):
			collider.apply_damage(dmg, global_position)
