extends Area2D

@export var speed: float = 600.0
@export var lifetime: float = 1.0
@export var damage: float = 10.0
@export var target_group: String = ""
## Piercing bullets keep flying and can hit every enemy instead of vanishing.
@export var pierce: bool = false

var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var age: float = 0.0

var _hit: Array = []

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	age += delta
	global_position += direction * speed * delta
	if age >= lifetime:
		queue_free()

func _on_body_entered(body):
	# Obstacles stop every bullet, piercing or not.
	if body.is_in_group("obstacles"):
		queue_free()
		return
	if body == source:
		return
	if target_group != "" and not body.is_in_group(target_group):
		return
	if pierce and body in _hit:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# Let the shooter react to its own hits (e.g. Vampirism lifesteal).
		if source != null and is_instance_valid(source) and source.has_method("on_deal_damage"):
			source.on_deal_damage(damage)
		if pierce:
			_hit.append(body)
		else:
			queue_free()