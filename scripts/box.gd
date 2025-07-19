extends RigidBody2D

@onready var collision_polygon_2d = $CollisionPolygon2D
@onready var collision_shape_2d = $Area2D/CollisionShape2D

var grabbed := false

func _physics_process(delta):
	var colliding_bodies = get_colliding_bodies()
	for body in colliding_bodies:
		if body is Player and body.global_position.y > global_position.y:
			linear_velocity.y = 0
			apply_central_impulse(Vector2.UP * 100)
