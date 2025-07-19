extends StaticBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var point_light_2d = $PointLight2D

@export var trigger_nodes : Array[Node2D]

var activated := false

func activate():
	if activated:
		return
	
	activated = true
	animated_sprite_2d.play("on")
	point_light_2d.enabled = true
	
	for node in trigger_nodes:
		node.trigger()
