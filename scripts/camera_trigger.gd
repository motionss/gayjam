extends Area2D

@onready var camera_2d := get_tree().get_first_node_in_group("camera")

@export var follow_player := Enums.FollowPlayer.No
@export var freeze_player_while_moving := true

var can_trigger := true

func _ready():
	body_entered.connect(on_body_entered)

func on_body_entered(_player: Player):
	# if the camera is already where this trigger wants it to be, it doesdn't run
	if !can_trigger or camera_2d.camera_anchor == get_parent().global_position:
		return
	
	camera_2d.follow_player = follow_player
	camera_2d.camera_anchor = get_parent().global_position
	camera_2d.has_to_move = true
	camera_2d.freeze_player_while_moving = freeze_player_while_moving
	
	GameData.data.last_camera_state = {
		"follow_player": camera_2d.follow_player,
		"camera_anchor": camera_2d.camera_anchor,
		"freeze_player_while_moving": camera_2d.freeze_player_while_moving,
		"camera_position": camera_2d.global_position
	}
	GameData.save_data()

func on_body_exited(_player: Player):
	can_trigger = true
