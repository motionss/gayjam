extends Camera2D

const DEFAULT_SHAKE_INTENSITY = 5

@onready var player = $"../Player"
@onready var move_to := global_position

var fast_noise : FastNoiseLite

var follow_axis : String
@export var follow_player := Enums.FollowPlayer.No :
	set(value):
		follow_player = value
		# reactively set the axis to follow based on the value of follow_player
		# so we don't need to calculate it in _physics_process
		if value != Enums.FollowPlayer.No:
			follow_axis = Enums.FollowPlayer.keys()[follow_player].to_lower()
		else:
			follow_axis = ''

var has_to_move := false

func _ready():
	fast_noise = FastNoiseLite.new()

func _physics_process(delta):
	# has_to_move means the camera will move to the next screen
	if has_to_move:
		if move_to != global_position:
			# while the camera is moving, the player is disabled to prevent "unforeseen events"
			player.process_mode = Node.PROCESS_MODE_DISABLED
			global_position = global_position.lerp(move_to, 9 * delta)
			# is camera is <= 1 pixel to destination, it gets moved to the move_to position
			# and the player is enabled back
			if global_position.distance_to(move_to) <= 1.0:
				global_position = move_to
				player.process_mode = Node.PROCESS_MODE_INHERIT
				has_to_move = false
	elif follow_player != Enums.FollowPlayer.No:
		# it won't follow the player further than the initial camera position
		if player.global_position[follow_axis] < move_to[follow_axis]:
			global_position[follow_axis] = global_position[follow_axis]
		else:
			global_position[follow_axis] = player.global_position[follow_axis]

func shake_camera(intensity_to_apply := DEFAULT_SHAKE_INTENSITY, duration := 0.2):
	var shake_tween = get_tree().create_tween()
	shake_tween.tween_method(apply_camera_shake, intensity_to_apply, 0.0, duration)

func apply_camera_shake(intensity: float):
	var shake_offset = fast_noise.get_noise_1d(Time.get_ticks_msec()) * intensity
	offset = Vector2(shake_offset, shake_offset)
