# Drops repair and armor kits at random spots during play. It runs for the
# whole game, so kits keep appearing during and between waves.
extends Node2D
class_name PickupSpawner

@export var pickup_scene: PackedScene = preload("res://pickup.tscn")

@export_group("Timing")
@export var first_delay: float = 6.0
@export var min_interval: float = 6.0
@export var max_interval: float = 12.0

@export_group("Contents")
## Chance that a dropped kit is armor instead of a repair kit.
@export_range(0.0, 1.0) var armor_chance: float = 0.4
@export var max_active: int = 4
## Repair kits stop spawning while the player's health is at least this ratio.
@export var suppress_repair_above_hp: float = 0.9

@export_group("Placement")
@export var margin: float = 90.0

func _ready() -> void:
	_spawn_loop()

func _spawn_loop() -> void:
	await get_tree().create_timer(first_delay).timeout
	while true:
		await get_tree().create_timer(randf_range(min_interval, max_interval)).timeout
		if get_tree().get_nodes_in_group("pickups").size() >= max_active:
			continue
		_spawn_pickup()

func _spawn_pickup() -> void:
	var pickup: Pickup = pickup_scene.instantiate()
	pickup.kind = _pick_kind()
	pickup.position = _random_position()
	add_child(pickup)

func _pick_kind() -> Pickup.Kind:
	var want_repair := randf() > armor_chance
	if want_repair:
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("get_health_ratio"):
			if player.get_health_ratio() >= suppress_repair_above_hp:
				want_repair = false
	return Pickup.Kind.REPAIR if want_repair else Pickup.Kind.ARMOR

func _random_position() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	return Vector2(randf_range(margin, size.x - margin), randf_range(margin, size.y - margin))