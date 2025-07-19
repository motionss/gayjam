extends Area2D

@onready var sprite_2d = $Sprite2D

func _ready():
	body_entered.connect(on_body_entered)
	
	var tween = get_tree().create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite_2d, "position:y", sprite_2d.position.y - 5.0, 1.0).from(sprite_2d.position.y)
	tween.tween_property(sprite_2d, "position:y", sprite_2d.position.y, 1.0)

func on_body_entered(player: Player):
	player.has_gun = true
	GameData.data.has_gun = true
	queue_free()
