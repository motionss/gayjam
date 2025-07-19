extends Camera2D

const DEFAULT_SHAKE_INTENSITY = 5

@onready var player = $"../Player"

var fast_noise : FastNoiseLite

var follow_axis : String
@export var camera_anchor : Vector2
@export var follow_player := Enums.FollowPlayer.No :
	set(value):
		follow_player = value
		# reactively set the axis to follow based on the value of follow_player
		# so we don't need to calculate it in _physics_process
		if value != Enums.FollowPlayer.No:
			follow_axis = Enums.FollowPlayer.keys()[follow_player].to_lower()
		else:
			follow_axis = ''
@export var freeze_player_while_moving := true
@export var follow_offset := 30.0

var has_to_move := false

func _ready():
	await get_parent().ready
	fast_noise = FastNoiseLite.new()
	
	if GameData.data.has("last_camera_state") and GameData.data.last_camera_state != null:
		follow_player = GameData.data.last_camera_state.follow_player
		camera_anchor = GameData.data.last_camera_state.camera_anchor
		freeze_player_while_moving = GameData.data.last_camera_state.freeze_player_while_moving
		global_position = GameData.data.last_camera_state.camera_position
	
	get_tree().get_first_node_in_group("main").dissolve_out()

func _physics_process(delta):
	# has_to_move means the camera will move to the next screen
	var follow_axis_target = null
	if follow_player != Enums.FollowPlayer.No:
		var offset_to_add = follow_offset if follow_player == Enums.FollowPlayer.X else -follow_offset
		follow_axis_target = player.global_position[follow_axis] + offset_to_add
		# it won't follow the player further than the initial camera position
		if follow_axis_target < camera_anchor[follow_axis]:
			follow_axis_target = camera_anchor[follow_axis]
	if has_to_move:
		var move_to = camera_anchor
		if follow_player != Enums.FollowPlayer.No:
			move_to[follow_axis] = follow_axis_target
		if move_to != global_position:
			# while the camera is moving, the player is disabled to prevent "unforeseen events"
			if freeze_player_while_moving:
				player.process_mode = Node.PROCESS_MODE_DISABLED
			global_position = global_position.lerp(move_to, 9 * delta)
			# is camera is <= 1 pixel to destination, it gets moved to the move_to position
			# and the player is enabled back
			if global_position.distance_to(move_to) <= 1.0:
				global_position = move_to
				if freeze_player_while_moving:
					player.process_mode = Node.PROCESS_MODE_INHERIT
				has_to_move = false
	elif follow_player != Enums.FollowPlayer.No:
		global_position[follow_axis] = lerpf(global_position[follow_axis], follow_axis_target, 9 * delta)

func shake_camera(intensity_to_apply := DEFAULT_SHAKE_INTENSITY, duration := 0.2):
	var shake_tween = get_tree().create_tween()
	shake_tween.tween_method(apply_camera_shake, intensity_to_apply, 0.0, duration)

func apply_camera_shake(intensity: float):
	var shake_offset = fast_noise.get_noise_1d(Time.get_ticks_msec()) * intensity
	offset = Vector2(shake_offset, shake_offset)
