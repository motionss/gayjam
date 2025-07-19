extends StaticBody2D


@onready var button_not_pressed = $ButtonNotPressed
@onready var button_pressed = $ButtonPressed

@onready var point_light_2d = $PointLight2D
@onready var area_2d = $Area2D
@onready var label = $Label

@export var permanent := false
@export var pressed := false :
	set(value):
		if pressed == value or (pressed and permanent):
			return
		
		pressed = value
		
		if is_instance_valid(label):
			label.text = 'ON' if value else 'OFF'
		if is_instance_valid(button_pressed):
			button_pressed.visible = value
		if is_instance_valid(button_not_pressed):
			button_not_pressed.visible = !value
		if is_instance_valid(point_light_2d):
			point_light_2d.enabled = value
		
		for node in trigger_nodes:
			node.trigger(value)

@export var trigger_nodes : Array[Node2D]

func _process(delta):
	pressed = area_2d.get_overlapping_bodies().size() > 0
