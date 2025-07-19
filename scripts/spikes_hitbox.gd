extends Area2D

func _ready():
	body_entered.connect(on_body_entered)
	
func on_body_entered(player: Player):
	player.die()
