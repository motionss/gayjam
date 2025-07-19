extends ColorRect

@export var center : Vector2

@onready var animation_player = $AnimationPlayer

func _ready():
	animation_player.play("expand")

func _process(_delta):
	var center_relative_to_camera = center - get_viewport().get_camera_2d().global_position
	material.set_shader_parameter("global_position", center_relative_to_camera)
