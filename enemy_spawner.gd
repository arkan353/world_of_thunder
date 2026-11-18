# Wave manager. Spawns enemies in waves, makes each wave harder than the last
# and ends the game at wave 10 (victory) or when the player is destroyed.
extends Node2D
class_name WaveManager

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int)
signal game_won
signal game_lost

@export var enemy_scene: PackedScene = preload("res://character_body_2d_2.tscn")

@export_group("Waves")
## The last wave. Surviving it wins the game.
@export var max_wave: int = 10
@export var first_wave_delay: float = 2.0
@export var between_waves_delay: float = 3.0
@export var spawn_interval: float = 0.7
## How far from the screen edge enemies spawn.
@export var spawn_margin: float = 60.0

@export_group("Difficulty per wave")
@export var health_growth: float = 0.20
@export var speed_growth: float = 0.06
@export var damage_growth: float = 0.12
## Shoot cooldown shrinks each wave, down to cooldown_floor.
@export var cooldown_growth: float = 0.07
@export var cooldown_floor: float = 0.4

@export_group("Between waves")
## HP the player regains after clearing each wave.
@export var heal_per_wave: float = 30.0
## If true the player is fully healed after every wave instead.
@export var full_heal_each_wave: bool = false

var current_wave: int = 0
var is_game_over: bool = false

var _player: Node = null

func _ready() -> void:
	add_to_group("wave_manager")
	_player = get_tree().get_first_node_in_group("player")
	if _player != null and _player.has_signal("died"):
		_player.connect("died", Callable(self, "_on_player_died"))
	_start_game()

# --- Game flow ---

func _start_game() -> void:
	await get_tree().create_timer(first_wave_delay).timeout

	while current_wave < max_wave:
		if is_game_over:
			return

		current_wave += 1
		await _run_wave(current_wave)

		if is_game_over:
			return

		if current_wave >= max_wave:
			_win()
			return

		var healed: float = _heal_player()
		if healed > 0.0:
			_show_message("Wave %d cleared!  +%d HP" % [current_wave, int(healed)], Color(0.5, 1.0, 0.5))
		else:
			_show_message("Wave %d cleared!" % current_wave, Color(0.5, 1.0, 0.5))
		await get_tree().create_timer(between_waves_delay).timeout
		if is_game_over:
			return
		_hide_message()
		await _offer_perk()
		if is_game_over:
			return

func _run_wave(wave: int) -> void:
	emit_signal("wave_started", wave, max_wave)
	_update_wave_hud(wave)
	_show_message("Wave %d" % wave, Color.WHITE)
	await get_tree().create_timer(1.0).timeout
	if is_game_over:
		return
	_hide_message()

	var count: int = _enemy_count_for_wave(wave)
	for i in range(count):
		if is_game_over:
			return
		_spawn_enemy(wave)
		await get_tree().create_timer(spawn_interval).timeout

	# Hold the wave until every enemy is gone.
	while not is_game_over and _alive_enemy_count() > 0:
		await get_tree().create_timer(0.25).timeout

	emit_signal("wave_completed", wave)

# --- Perks between waves ---

## Shows three perk cards and waits for the player to pick one, then applies it.
func _offer_perk() -> void:
	var hud: Node = _hud()
	if hud == null or _player == null or not is_instance_valid(_player):
		return
	if not hud.has_method("show_perk_choices") or not hud.has_signal("perk_chosen"):
		return
	var choices: Array = _pick_perk_choices(3)
	if choices.is_empty():
		return
	hud.show_perk_choices(choices)
	var chosen: int = await hud.perk_chosen
	if is_game_over:
		return
	if _player.has_method("apply_perk"):
		_player.apply_perk(chosen)

## Random perk ids the player can still take, up to count.
func _pick_perk_choices(count: int) -> Array:
	var pool: Array = []
	for id in Perks.all_ids():
		var have: int = 0
		if _player != null and _player.has_method("get_perk_stacks"):
			have = _player.get_perk_stacks(id)
		if have < Perks.max_stacks(id):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func _win() -> void:
	is_game_over = true
	_show_message("VICTORY!  All %d waves survived!" % max_wave, Color(0.5, 1.0, 0.5))
	_show_restart()
	emit_signal("game_won")

func _on_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	_show_message("You were destroyed!\nReached wave %d" % current_wave, Color(1.0, 0.35, 0.35))
	_show_restart()
	emit_signal("game_lost")

# --- Healing ---

## Heals the player between waves and returns the amount actually restored.
func _heal_player() -> float:
	if _player == null or not is_instance_valid(_player) or _player.is_dead:
		return 0.0
	var before: float = _player.health
	if full_heal_each_wave:
		_player.heal(_player.max_health)
	else:
		_player.heal(heal_per_wave)
	return _player.health - before

# --- Spawning & difficulty ---

func _enemy_count_for_wave(wave: int) -> int:
	# Wave 1 -> 1 enemy, wave 10 -> 10 enemies.
	return wave

func _spawn_enemy(wave: int) -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	_apply_difficulty(enemy, wave)
	enemy.position = _random_spawn_position()
	add_child(enemy)

func _apply_difficulty(enemy: Enemy, wave: int) -> void:
	var step: float = float(wave - 1)

	enemy.max_health *= 1.0 + step * health_growth
	enemy.bullet_damage *= 1.0 + step * damage_growth
	enemy.max_speed *= 1.0 + step * speed_growth
	enemy.shoot_cooldown = maxf(cooldown_floor, enemy.shoot_cooldown * (1.0 - step * cooldown_growth))

func _random_spawn_position() -> Vector2:
	var size: Vector2 = get_viewport_rect().size
	var m: float = spawn_margin
	match randi() % 4:
		0:
			return Vector2(randf_range(m, size.x - m), m)
		1:
			return Vector2(randf_range(m, size.x - m), size.y - m)
		2:
			return Vector2(m, randf_range(m, size.y - m))
		_:
			return Vector2(size.x - m, randf_range(m, size.y - m))

func _alive_enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

# --- HUD helpers ---

func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")

func _update_wave_hud(wave: int) -> void:
	var hud: Node = _hud()
	if hud != null:
		hud.set_wave(wave, max_wave)

func _show_message(text: String, color: Color) -> void:
	var hud: Node = _hud()
	if hud != null:
		hud.show_message(text, color)

func _hide_message() -> void:
	var hud: Node = _hud()
	if hud != null:
		hud.hide_message()

func _show_restart() -> void:
	var hud: Node = _hud()
	if hud != null:
		hud.show_restart()