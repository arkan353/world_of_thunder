# Enemy AI tank. Moves and shoots exactly like the player
# (turn + drive forward), but the controls come from AI: it hunts the
# player, keeps a firing distance and shoots when its barrel is aimed.
class_name Enemy
extends CharacterBody2D

@export var bullet_scene: PackedScene = preload("res://area_2d.tscn")

@export var forward_direction: Vector2 = Vector2(0, -1)

@export_group("Movement")
@export var max_speed: float = 200.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

@export var max_turn_speed: float = 120.0
@export var turn_acceleration: float = 400.0
@export var turn_friction: float = 500.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var bullet_damage: float = 10.0
@export var shoot_cooldown: float = 1.5
@export var shoot_range: float = 600.0
@export var aim_tolerance_deg: float = 10.0

@export_group("AI")
@export var detect_range: float = 1200.0
@export var preferred_distance: float = 250.0

var health: float = 100.0
var current_speed: float = 0.0
var current_turn_speed: float = 0.0

var _shoot_timer: float = 0.0
var _target: Node2D = null

@onready var muzzle: Marker2D = $Muzzle
@onready var hp_label: Label = $HPLabel

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	health = max_health
	hp_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_update_hp_label()
	_acquire_target()

func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	if not is_instance_valid(_target):
		_acquire_target()

	var turn_input: float = 0.0
	var move_input: float = 0.0
	var want_shoot: bool = false

	if is_instance_valid(_target):
		var forward := forward_direction.rotated(rotation)
		var to_target: Vector2 = _target.global_position - global_position
		var distance := to_target.length()

		if distance > 0.001 and distance <= detect_range:
			var angle_diff := wrapf(to_target.angle() - forward.angle(), -PI, PI)
			var tolerance := deg_to_rad(aim_tolerance_deg)

			# Turn the hull toward the player (sign of the angle gives direction).
			if absf(angle_diff) > tolerance * 0.5:
				turn_input = signf(angle_diff)

			# Drive forward when far, back off when the player is too close.
			if distance > preferred_distance:
				move_input = 1.0
			elif distance < preferred_distance * 0.6:
				move_input = -1.0

			# Fire only when the barrel is actually aimed at the player.
			if absf(angle_diff) <= tolerance and distance <= shoot_range:
				want_shoot = true

	_handle_rotation(turn_input, delta)
	_handle_movement(move_input, delta)

	hp_label.rotation = -rotation

	if want_shoot:
		shoot()

# --- Movement (same tank model as the player) ---

func _handle_rotation(turn: float, delta: float) -> void:
	var target_turn := turn * deg_to_rad(max_turn_speed)

	if turn != 0.0:
		current_turn_speed = move_toward(
			current_turn_speed, target_turn, deg_to_rad(turn_acceleration) * delta
		)
	else:
		current_turn_speed = move_toward(
			current_turn_speed, 0.0, deg_to_rad(turn_friction) * delta
		)

	rotation += current_turn_speed * delta

func _handle_movement(move: float, delta: float) -> void:
	var target_speed := move * max_speed

	if move != 0.0:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	var forward := forward_direction.rotated(rotation)
	velocity = forward * current_speed
	move_and_slide()

	current_speed = velocity.dot(forward)

# --- Shooting ---

func shoot() -> void:
	if _shoot_timer > 0.0:
		return
	_shoot_timer = shoot_cooldown

	var forward := forward_direction.rotated(rotation)
	var bullet := bullet_scene.instantiate()
	bullet.direction = forward
	bullet.damage = bullet_damage
	bullet.source = self
	bullet.target_group = "player"
	bullet.global_position = muzzle.global_position
	bullet.rotation = forward.angle()
	get_parent().add_child(bullet)

# --- Targeting ---

func _acquire_target() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		_target = player

# --- HP ---

func take_damage(amount: float) -> void:
	set_health(health - amount)

func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	_update_hp_label()
	if health <= 0.0:
		die()

func _update_hp_label() -> void:
	hp_label.text = "HP: %d" % int(health)

func die() -> void:
	queue_free()