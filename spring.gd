extends Area2D

@onready var animation_player = $AnimationPlayer

func _ready():
	body_entered.connect(player_entered)
	
func player_entered(node):
	if node is Player:
		node.spring_jump()
	elif node is RigidBody2D:
		if node.grabbed:
			return
		node.sleeping = false
		node.linear_velocity.y = 0.0
		node.apply_central_impulse(Vector2.UP * 250)
	animation_player.stop()
	animation_player.play("activate")
