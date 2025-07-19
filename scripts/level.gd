extends Node2D

@onready var dissolve_rect = $CanvasLayer/DissolveRect
@onready var player = $Player

@onready var yellow_rect = $CanvasLayer/YellowRect
@onready var you_did_it = $CanvasLayer/YouDidIt
@onready var dark_rect = $CanvasLayer/DarkRect

func _ready():
	GameData.load_data()
	
	var noise_texture = dissolve_rect.material.get_shader_parameter("dissolve_texture")
	noise_texture.noise.seed += 1
	dissolve_rect.material.set_shader_parameter("dissolve_texture", noise_texture)

func dissolve_in():
	var dissolve_tween = get_tree().create_tween()
	dissolve_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	dissolve_tween.tween_method(set_dissolve_value, 0.0, 1.0, 1)
	dissolve_tween.play()

func dissolve_out():
	var dissolve_tween = get_tree().create_tween()
	dissolve_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	dissolve_tween.tween_method(set_dissolve_value, 1.0, 0.0, 1)
	dissolve_tween.play()

func set_dissolve_value(value: float):
	dissolve_rect.material.set_shader_parameter("dissolve_value", value)

func win():
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(yellow_rect, "modulate:a", 1.0, 1.0).set_delay(1.0)
	tween.tween_property(you_did_it, "modulate:a", 1.0, 1.0).set_delay(1.0)
	tween.tween_property(you_did_it, "modulate:a", .0, 1.0).set_delay(2.0)
	tween.tween_property(dark_rect, "modulate:a", 1.0, 1.0).set_delay(1.0)
