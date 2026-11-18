# A collectible dropped on the battlefield. The player picks it up by driving
# over it. REPAIR restores health; ARMOR adds a layer of armor and permanently
# upgrades the tank's armor capacity, so the upgrade carries between waves.
extends Area2D
class_name Pickup

enum Kind { REPAIR, ARMOR }

@export var kind: Kind = Kind.REPAIR
## Health restored by a repair kit.
@export var repair_amount: float = 30.0
## Armor an armor kit adds to the tank's capacity (and refills by the same).
@export var armor_amount: float = 40.0
## Seconds before the kit disappears if not collected. 0 keeps it forever.
@export var lifetime: float = 30.0
@export var bob_speed: float = 4.0
@export var bob_amount: float = 0.08

var _age: float = 0.0

@onready var repair_sprite: Sprite2D = $RepairSprite
@onready var armor_sprite: Sprite2D = $ArmorSprite

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	repair_sprite.visible = kind == Kind.REPAIR
	armor_sprite.visible = kind == Kind.ARMOR

func _process(delta: float) -> void:
	_age += delta
	if lifetime > 0.0 and _age >= lifetime:
		queue_free()
		return
	var s := 1.0 + sin(_age * bob_speed) * bob_amount
	scale = Vector2(s, s)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	match kind:
		Kind.REPAIR:
			if body.has_method("heal"):
				body.heal(repair_amount)
		Kind.ARMOR:
			if body.has_method("add_armor"):
				body.add_armor(armor_amount)
	queue_free()