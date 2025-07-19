extends Area2D

@export var trigger_nodes : Array[Node2D]

func _ready():
	body_entered.connect(on_body_entered)

func on_body_entered():
	for node in trigger_nodes:
		node.trigger()
