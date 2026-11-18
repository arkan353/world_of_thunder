# A solid battlefield obstacle. It blocks tanks and stops bullets.
# A single scene covers every obstacle look: ObstacleSpawner assigns the
# texture and the collision box, so the same node can be a rock, a crate,
# a stack of sandbags or a concrete barrier.
class_name Obstacle
extends StaticBody2D

## Assigns the look and the collision box. Called by the spawner right after
## the node is added to the tree.
func setup(texture: Texture2D, collision_size: Vector2) -> void:
	add_to_group("obstacles")
	($Sprite2D as Sprite2D).texture = texture
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	($CollisionShape2D as CollisionShape2D).shape = rect