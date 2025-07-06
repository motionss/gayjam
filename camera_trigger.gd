extends Area2D

@onready var marker_2d := $Marker2D
@onready var camera_2d := get_tree().get_first_node_in_group("camera")

@export var follow_player := Enums.FollowPlayer.No

var can_trigger := true

func _ready():
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)

func on_body_entered(_player: Player):
	# if the camera is already where this trigger wants it to be, it doesdn't run
	if !can_trigger or camera_2d.move_to == marker_2d.global_position:
		return
	
	camera_2d.follow_player = follow_player
	camera_2d.move_to = marker_2d.global_position
	camera_2d.has_to_move = true
	can_trigger = false

func on_body_exited(_player: Player):
	can_trigger = true
