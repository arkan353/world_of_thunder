# Places solid obstacles the moment a new wave starts. The set of obstacles and
# how many appear change as the waves climb, so the battlefield evolves from
# scattered rocks to a fortified concrete maze.
extends Node2D
class_name ObstacleSpawner

@export var obstacle_scene: PackedScene = preload("res://obstacle.tscn")

@export_group("Layout")
## Obstacles stay at least this far from the screen edge (keeps spawn lanes open).
@export var edge_margin: float = 140.0
## Minimum gap between two obstacles.
@export var min_gap: float = 155.0
## Area kept clear around the player's starting spot.
@export var player_clear_radius: float = 175.0

const ROCK := preload("res://assets/generated/obstacle_rock.png")
const CRATE := preload("res://assets/generated/obstacle_crate.png")
const SANDBAGS := preload("res://assets/generated/obstacle_sandbags.png")
const CONCRETE := preload("res://assets/generated/obstacle_concrete.png")
const CONCRETE_B := preload("res://assets/generated/obstacle_concrete_2.png")

var _player_start: Vector2 = Vector2(490.0, 178.0)

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		_player_start = (player as Node2D).global_position
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm != null and wm.has_signal("wave_started"):
		wm.wave_started.connect(_on_wave_started)

func _on_wave_started(wave: int, _total: int) -> void:
	_rebuild(wave)

func _rebuild(wave: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var pool := _types_for_wave(wave)
	var count := clampi(2 + wave, 3, 14)
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < count and attempts < count * 40:
		attempts += 1
		var pos := _random_position()
		if pos.distance_to(_player_start) < player_clear_radius:
			continue
		var ok := true
		for other in placed:
			if pos.distance_to(other) < min_gap:
				ok = false
				break
		if not ok:
			continue
		placed.append(pos)
		_spawn(pool[randi() % pool.size()], pos)

func _spawn(entry: Dictionary, pos: Vector2) -> void:
	var obstacle: Obstacle = obstacle_scene.instantiate()
	obstacle.position = pos
	obstacle.rotation = randf_range(0.0, TAU)
	add_child(obstacle)
	obstacle.setup(entry["texture"], entry["size"])

func _random_position() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(
		randf_range(edge_margin, size.x - edge_margin),
		randf_range(edge_margin, size.y - edge_margin)
	)

## Which obstacles fit a given wave. Later waves bring heavier defences.
func _types_for_wave(wave: int) -> Array:
	if wave <= 2:
		return [{"texture": ROCK, "size": Vector2(48, 44)}]
	if wave <= 4:
		return [
			{"texture": ROCK, "size": Vector2(48, 44)},
			{"texture": CRATE, "size": Vector2(52, 52)},
		]
	if wave <= 6:
		return [
			{"texture": SANDBAGS, "size": Vector2(60, 34)},
			{"texture": CRATE, "size": Vector2(52, 52)},
		]
	if wave <= 8:
		return [
			{"texture": CONCRETE, "size": Vector2(62, 30)},
			{"texture": SANDBAGS, "size": Vector2(60, 34)},
		]
	return [
		{"texture": CONCRETE, "size": Vector2(62, 30)},
		{"texture": CONCRETE_B, "size": Vector2(62, 30)},
		{"texture": ROCK, "size": Vector2(48, 44)},
	]