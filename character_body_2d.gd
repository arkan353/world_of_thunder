# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Copyright 2026 Dmitry Sukhoruchenkov
extends CharacterBody2D

## Emitted once when the player's health reaches zero.
signal died

@export var bullet_scene: PackedScene = preload("res://area_2d.tscn")

@export var forward_direction: Vector2 = Vector2.RIGHT

@export_group("Movement")
@export var max_speed: float = 300.0
@export var acceleration: float = 800.0
@export var friction: float = 600.0

@export var max_turn_speed: float = 120.0
@export var turn_acceleration: float = 400.0
@export var turn_friction: float = 500.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var bullet_damage: float = 10.0

@export_group("Armor")
## Armor the tank starts with. Grows as armor kits are collected.
@export var starting_armor: float = 0.0
## Highest armor capacity the tank can ever reach.
@export var max_armor_cap: float = 500.0

@export_group("Perks")
## Health stolen per bullet hit, per Vampirism stack (fraction of damage dealt).
@export var lifesteal_per_stack: float = 0.15
## Bullet damage bonus per Extra Damage stack (fraction of base damage).
@export var damage_per_stack: float = 0.25
## Real-time cooldown of the Multifire volley, in seconds.
@export var multifire_cooldown: float = 60.0
## How many piercing shells the Multifire volley throws around the tank.
@export var multifire_bullet_count: int = 18
## Shield added per Shield stack, and how fast it regenerates out of combat.
@export var shield_per_stack: float = 40.0
@export var shield_regen_rate: float = 8.0
@export var shield_regen_delay: float = 4.0

var health: float = 100.0
var armor: float = 0.0
var max_armor: float = 0.0
var is_dead: bool = false

var perk_stacks: Dictionary = {}
var lifesteal_ratio: float = 0.0
var damage_mult: float = 1.0
var multifire_unlocked: bool = false
var shield: float = 0.0
var max_shield: float = 0.0
var _multifire_timer: float = 0.0
var _shield_regen_timer: float = 0.0

var current_speed: float = 0.0
var current_turn_speed: float = 0.0

@onready var muzzle: Marker2D = $Muzzle
@onready var hp_label: Label = $HPLabel
@onready var hud: Node = get_node_or_null("HUD")

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	health = max_health
	max_armor = starting_armor
	armor = starting_armor
	hp_label.add_theme_color_override("font_color", Color.GREEN)
	_update_hp_label()
	if hud != null:
		hud.set_max_hp(int(max_health))
		hud.set_hp(int(health))
		hud.set_max_armor(int(max_armor))
		hud.set_armor(int(armor))
	_update_perk_label()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_handle_rotation(delta)
	_handle_movement(delta)
	_update_perks(delta)
	hp_label.rotation = -rotation

func _handle_rotation(delta: float) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	var target_turn := turn * deg_to_rad(max_turn_speed)

	if turn != 0:
		current_turn_speed = move_toward(
			current_turn_speed, target_turn, deg_to_rad(turn_acceleration) * delta
		)
	else:
		current_turn_speed = move_toward(
			current_turn_speed, 0.0, deg_to_rad(turn_friction) * delta
		)

	rotation += current_turn_speed * delta

func _handle_movement(delta: float) -> void:
	var move := Input.get_axis("ui_down", "ui_up")
	var target_speed := move * max_speed

	if move != 0:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	var forward := forward_direction.rotated(rotation)
	velocity = forward * current_speed
	move_and_slide()

	current_speed = velocity.dot(forward)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("shoot") or event.is_action_pressed("ui_accept"):
		shoot()
	if event.is_action_pressed("multifire"):
		trigger_multifire()

func shoot() -> void:
	if is_dead:
		return
	var forward := forward_direction.rotated(rotation)
	var bullet := bullet_scene.instantiate()
	bullet.direction = forward
	bullet.damage = _effective_damage()
	bullet.source = self
	bullet.target_group = "enemies"
	bullet.global_position = muzzle.global_position
	bullet.rotation = forward.angle()
	get_parent().add_child(bullet)

# --- HP & armor ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	# Taking a hit restarts the shield's out-of-combat regeneration timer.
	_shield_regen_timer = shield_regen_delay
	# Shield, then armor, then health soak damage in that order.
	var remaining := amount
	if shield > 0.0:
		var shield_absorbed := minf(shield, remaining)
		shield -= shield_absorbed
		remaining -= shield_absorbed
		_update_shield()
	if remaining > 0.0 and armor > 0.0:
		var absorbed := minf(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
		_update_armor()
	if remaining > 0.0:
		set_health(health - remaining)

func heal(amount: float) -> void:
	if is_dead:
		return
	set_health(health + amount)

## Armor kit: raises the armor capacity and refills the new layer.
func add_armor(amount: float) -> void:
	if is_dead:
		return
	max_armor = minf(max_armor + amount, max_armor_cap)
	armor = minf(armor + amount, max_armor)
	_update_armor()

func get_health_ratio() -> float:
	return health / maxf(max_health, 0.001)

func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	_update_hp_label()
	if hud != null:
		hud.set_hp(int(health))
	if health <= 0.0:
		die()

func _update_armor() -> void:
	_update_hp_label()
	if hud != null:
		hud.set_max_armor(int(max_armor))
		hud.set_armor(int(armor))

func _update_hp_label() -> void:
	var text := "HP: %d" % int(health)
	if max_armor > 0.0:
		text += "  AR: %d" % int(armor)
	if max_shield > 0.0:
		text += "  SH: %d" % int(shield)
	hp_label.text = text

# --- Perks ---

## Called by bullets when one of the player's shots deals damage.
func on_deal_damage(amount: float) -> void:
	if is_dead or lifesteal_ratio <= 0.0:
		return
	heal(amount * lifesteal_ratio)

## Applies one pick of a perk. Every perk except Multifire stacks.
func apply_perk(perk_id: int) -> void:
	var stacks: int = int(perk_stacks.get(perk_id, 0)) + 1
	perk_stacks[perk_id] = stacks
	match perk_id:
		Perks.Id.VAMPIRISM:
			lifesteal_ratio = lifesteal_per_stack * stacks
		Perks.Id.EXTRA_DAMAGE:
			damage_mult = 1.0 + damage_per_stack * stacks
		Perks.Id.MULTIFIRE:
			multifire_unlocked = true
		Perks.Id.SHIELD:
			max_shield = shield_per_stack * stacks
			shield = max_shield
			_update_shield()
	_update_perk_label()
	_update_perks(0.0)

func get_perk_stacks(perk_id: int) -> int:
	return int(perk_stacks.get(perk_id, 0))

func _effective_damage() -> float:
	return bullet_damage * damage_mult

## Fires a ring of piercing shells in every direction. Multifire perk only.
func trigger_multifire() -> void:
	if is_dead or not multifire_unlocked or _multifire_timer > 0.0:
		return
	_multifire_timer = multifire_cooldown
	var count: int = maxi(multifire_bullet_count, 1)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var direction := Vector2.RIGHT.rotated(angle)
		var bullet := bullet_scene.instantiate()
		bullet.direction = direction
		bullet.damage = _effective_damage()
		bullet.source = self
		bullet.target_group = "enemies"
		bullet.pierce = true
		bullet.speed = 700.0
		bullet.lifetime = 1.4
		bullet.global_position = global_position
		bullet.rotation = angle
		get_parent().add_child(bullet)

func _update_perks(delta: float) -> void:
	if _multifire_timer > 0.0:
		_multifire_timer = maxf(_multifire_timer - delta, 0.0)
	if max_shield > 0.0 and shield < max_shield:
		if _shield_regen_timer > 0.0:
			_shield_regen_timer = maxf(_shield_regen_timer - delta, 0.0)
		else:
			shield = minf(shield + shield_regen_rate * delta, max_shield)
			_update_shield()
	if hud != null and hud.has_method("set_multifire"):
		hud.set_multifire(multifire_unlocked, _multifire_timer, multifire_cooldown)

func _update_shield() -> void:
	_update_hp_label()
	if hud != null and hud.has_method("set_shield"):
		hud.set_max_shield(int(max_shield))
		hud.set_shield(int(shield))

func _update_perk_label() -> void:
	if hud != null and hud.has_method("set_perks"):
		hud.set_perks(_perk_summary())

func _perk_summary() -> String:
	var parts: Array[String] = []
	for id in Perks.all_ids():
		var stacks: int = int(perk_stacks.get(id, 0))
		if stacks > 0:
			parts.append("%s x%d" % [Perks.title(id), stacks])
	return "   ".join(parts)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	remove_from_group("player")
	visible = false
	emit_signal("died")