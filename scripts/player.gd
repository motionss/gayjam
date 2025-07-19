extends CharacterBody2D
class_name Player

const SPEED := 85.0
const JUMP_VELOCITY := -160.0
const SPRING_JUMP_VELOCITY := -250.0
const MAX_FALL_VELOCITY := 180.0
const MIN_JUMP_TIME := 0.05

const COYOTE_TIME_TICKS := 100
const JUMP_BUFFERING_TICKS := 60

@export var has_gun := true :
	set(value):
		has_gun = value
		if is_instance_valid(animated_sprite_2d):
			handle_gun()

@export var load_checkpoint := true

@onready var hurt_box = $CollisionShape2D/HurtBox
@onready var flying_particles: GPUParticles2D = $FlyingParticles
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var collision_shape_initial_position := collision_shape_2d.position
@onready var left_wall_area: Area2D = $CollisionShape2D/LeftWallArea
@onready var right_wall_area: Area2D = $CollisionShape2D/RightWallArea
@onready var feet_marker: Marker2D = $FeetMarker
@onready var head_top_right_in: RayCast2D = $HeadTopRightIn
@onready var head_top_right_out: RayCast2D = $HeadTopRightOut
@onready var head_top_left_in: RayCast2D = $HeadTopLeftIn
@onready var head_top_left_out: RayCast2D = $HeadTopLeftOut
@onready var gun: Gun = $Gun
@onready var gun_pivot: Marker2D = %GunPivot

@onready var run_audio = $RunAudio
@onready var land_audio = $LandAudio
@onready var jump_audio = $JumpAudio
@onready var stab_audio = $StabAudio
@onready var death_audio = $DeathAudio
@onready var death_explosion_audio = $DeathExplosionAudio

var pressed_jump_tick := 0
var released_jump_tick := 0
var jump_time := 0.0
var last_tick_on_floor := 0
var prev_velocity : Vector2

var inert := false
var falling := false
var jumping := false
var wall_jump_amount := 0
var wall_jumping := false
var looking_left := false
var is_on_spring := false
var hooked := false :
	get():
		return gun.hooked
		
var soup_position : Vector2

func _ready():
	await get_parent().ready
	hurt_box.body_entered.connect(_on_body_entered)
	set_blink_intensity(0.0)
	gun.process_mode = Node.PROCESS_MODE_INHERIT
	
	if load_checkpoint:
		var game_data = GameData.data
		has_gun = game_data.has_gun
		if game_data.last_checkpoint != null:
			global_position = game_data.last_checkpoint
	
	handle_gun()

func handle_gun():
	if has_gun:
		animated_sprite_2d.sprite_frames = preload("res://scenes/res/player_one_hand.tres")
		gun.visible = true
		gun.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		animated_sprite_2d.sprite_frames = preload("res://scenes/res/player_two_hand.tres")
		gun.visible = false
		gun.process_mode = Node.PROCESS_MODE_DISABLED
	

func _on_body_entered(node: Node2D):
	if inert:
		return
	die()

func _physics_process(delta):
	if inert:
		return
	
	var current_tick = Time.get_ticks_msec()
	
	# Set floor dependant values
	if is_on_floor():
		last_tick_on_floor = current_tick
		jumping = false
		is_on_spring = false
		wall_jumping = false
		wall_jump_amount = 0
	
	var touching_left_wall = left_wall_area.get_overlapping_bodies().size() > 0
	var touching_right_wall = right_wall_area.get_overlapping_bodies().size() > 0
	
	if jumping:
		jump_time += delta
		# Jump corner correction
		var collider = null
		var inner_position : Vector2
		if head_top_left_in.is_colliding() and !head_top_left_out.is_colliding():
			collider = head_top_left_in.get_collider()
			inner_position = head_top_left_in.global_position
		if head_top_right_in.is_colliding() and !head_top_right_out.is_colliding():
			collider = head_top_right_in.get_collider()
			inner_position = head_top_right_in.global_position
		if collider is TileMapLayer:
			var correct_right = inner_position.x > global_position.x
			var tile_global_position := get_tile_global_position(collider, inner_position)
			var x_diff := inner_position.x - (tile_global_position.x + (.0 if correct_right else float(collider.tile_set.tile_size.x)))
			global_position.x = floor(global_position.x - x_diff) + (0.01 * (1 if correct_right else -1))
			falling = false
			#velocity = prev_velocity
	
	# Save falling state
	if velocity.y > 0:
		falling = true
	elif velocity.y < 0 or is_on_floor():
		if falling and prev_velocity.y >= 100.0:
			animated_sprite_2d.scale = Vector2(1.3 if prev_velocity.y >= 150.0 else 1.1, 0.6)
			instantiate_jump_particles()
			if prev_velocity.y >= 150.0:
				play_land_audio()
		falling = false

	# Get the input_direction and handle direction dependant variables
	var input_direction := Input.get_axis("move_left", "move_right")
	if input_direction and is_on_floor():
		if !run_audio.playing:
			run_audio.play()
	elif run_audio.playing:
		run_audio.stop()
	if input_direction or velocity.x:
		looking_left = input_direction < 0.0 or velocity.x < 0.0
	
	if !is_on_floor():
		if touching_left_wall:
			looking_left = true
		if touching_right_wall:
			looking_left = false
	
	if looking_left:
		$AnimatedSprite2D.flip_h = true
		gun_pivot.position.x = 3.0
		gun_pivot.scale.x = -1.0
		collision_shape_2d.position = collision_shape_initial_position + Vector2.LEFT
	else:
		$AnimatedSprite2D.flip_h = false
		gun_pivot.position.x = -3.0
		gun_pivot.scale.x = 1.0
		collision_shape_2d.position = collision_shape_initial_position
	
	# Add the gravity
	if not is_on_floor():
		var gravity_multiplier = 1
		if falling and (touching_left_wall or touching_right_wall):
			gravity_multiplier = 0.3
		elif !(falling or hooked):
			gravity_multiplier = 0.6
		velocity += get_gravity() * gravity_multiplier * delta
		
		var fall_velocity_multiplier = 1
		if touching_left_wall or touching_right_wall:
			fall_velocity_multiplier *= 0.7
		if falling and !hooked:
			velocity.y = minf(velocity.y, MAX_FALL_VELOCITY * fall_velocity_multiplier)
	elif !hooked:
		velocity.y = 0
	
	# Horizontal velocity
	#if (input_direction == 0 and is_on_floor()):
		#velocity.x = 0
	#else:
	velocity.x = lerpf(
		velocity.x,
		SPEED * (1 if is_on_floor() else 1.1) * input_direction,
		((9 if input_direction else 15) if is_on_floor() else 7) * delta
	)

	# Handle jump
	if pressed_jump_tick > 0 and \
		# Jump buffer
		((is_on_floor() and (current_tick - pressed_jump_tick <= JUMP_BUFFERING_TICKS)) or \
		# Coyote time
		(!is_on_floor() and (current_tick - last_tick_on_floor <= COYOTE_TIME_TICKS)) or \
		# Wall jump
		(!is_on_floor() and (touching_left_wall or touching_right_wall))):
		pressed_jump_tick = 0
		released_jump_tick = 0
		if (!is_on_floor() and (touching_left_wall or touching_right_wall)) and wall_jump_amount < 2:
			jump(JUMP_VELOCITY, true, -1 if touching_left_wall else 1)
			wall_jumping = true
			wall_jump_amount += 1
		elif !jumping:
			jump()
		play_jump_audio()
	if released_jump_tick > 0 and !falling and !is_on_spring and jump_time >= MIN_JUMP_TIME:
		released_jump_tick = 0
		velocity.y = 0
	
	# Animations
	if is_on_floor():
		if input_direction:
			animated_sprite_2d.play('walk')
		else:
			animated_sprite_2d.play('idle')
	else:
		if falling and (touching_left_wall or touching_right_wall):
			animated_sprite_2d.play("wall_grab")
		elif velocity.y < -20.0:
			animated_sprite_2d.play('jump')
		elif velocity.y < 5.0:
			animated_sprite_2d.play('about_to_fall')
		elif velocity.y >= 5.0:
			animated_sprite_2d.play('fall')
	
	prev_velocity = velocity
	
	move_and_slide()
	
	flying_particles.emitting = velocity.length() > 180.0

func _process(delta):
	animated_sprite_2d.scale = animated_sprite_2d.scale.lerp(Vector2.ONE, 8 * delta)

func play_jump_audio():
	jump_audio.pitch_scale = randf_range(.8, 1.2)
	jump_audio.play()

func play_land_audio():
	land_audio.pitch_scale = randf_range(.8, 1.2)
	land_audio.play()

func play_death_explosion_audio():
	death_explosion_audio.play()

func jump(jump_velocity := JUMP_VELOCITY, particles := true, horizontal_side := 0):
	jumping = true
	velocity.y = jump_velocity
	if horizontal_side:
		velocity.x = horizontal_side * jump_velocity
	pressed_jump_tick = 0
	jump_time = 0
	animated_sprite_2d.scale.x = 0.6
	
	# Jump particles
	if particles:
		if !horizontal_side:
			instantiate_jump_particles()
		else:
			if horizontal_side == 1:
				instantiate_jump_particles(right_wall_area.global_position, deg_to_rad(-90))
			else:
				instantiate_jump_particles(left_wall_area.global_position, deg_to_rad(90))

func spring_jump():
	is_on_spring = true
	jump(SPRING_JUMP_VELOCITY, false)
	get_tree().get_first_node_in_group("camera").shake_camera()
	move_and_slide()
	
func win(pos : Vector2):
	soup_position = pos
	inert = true
	has_gun = false
	
	animated_sprite_2d.play("about_to_fall")
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", soup_position, 3.5)
	
	var level = get_tree().get_first_node_in_group("main")
	level.win()

func die(direction := Vector2.UP):
	inert = true
	
	var level = get_tree().get_first_node_in_group("main")
	var checkpoints = level.get_node('Checkpoints').get_children()
	
	var closest_checkpoint = checkpoints[0].global_position
	var closest_distance = closest_checkpoint.distance_to(global_position)
	for checkpoint in checkpoints:
		var checkpoint_distance = checkpoint.global_position.distance_to(global_position)
		if checkpoint_distance < closest_distance:
			closest_distance = checkpoint_distance
			closest_checkpoint = checkpoint.global_position
	
	GameData.data.last_checkpoint = closest_checkpoint
	var camera = get_tree().get_first_node_in_group("camera")
	GameData.data.last_camera_state.camera_position = camera.global_position
	
	GameData.save_data()
	
	animated_sprite_2d.play("die")
	has_gun = false
	
	run_audio.stop()
	death_audio.play()
	stab_audio.play()
	
	var rotate = 45.0
	var duration = .5
	var die_tween = get_tree().create_tween()
	die_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	die_tween.tween_property(self, "global_position", global_position + (direction * 20), duration)
	die_tween.parallel()
	die_tween.tween_property(self, "global_rotation", global_rotation + deg_to_rad(-rotate if looking_left else rotate), duration)
	die_tween.parallel()
	die_tween.tween_method(set_blink_intensity, 0.0, 1.0, duration * .25).set_delay(duration * .75)
	die_tween.chain()
	die_tween.tween_property(self, "visible", false, 0.0)
	die_tween.parallel()
	die_tween.tween_callback(instantiate_shockwave)
	die_tween.parallel()
	die_tween.tween_callback(instantiate_die_particles)
	die_tween.parallel()
	die_tween.tween_callback(play_death_explosion_audio)
	die_tween.parallel()
	die_tween.tween_callback(get_tree().get_first_node_in_group("main").dissolve_in).set_delay(.5)
	die_tween.tween_callback(get_tree().reload_current_scene).set_delay(.5)
	die_tween.play()

func set_blink_intensity(value : float):
	animated_sprite_2d.material.set_shader_parameter("intensity", value)

func instantiate_die_particles():
	const DIE_PARTICLES = preload("res://scenes/particles/die_particles.tscn")
	var particles = DIE_PARTICLES.instantiate()
	particles.global_position = global_position
	get_parent().add_child(particles)
	particles.restart()

func instantiate_jump_particles(position := feet_marker.global_position, rotation := 0.0):
	const JUMP_PARTICLES = preload("res://scenes/particles/jump_particles.tscn")
	var particles = JUMP_PARTICLES.instantiate()
	particles.global_position = position
	particles.rotation = rotation
	get_parent().add_child(particles)

func instantiate_shockwave():
	const SHOCKWAVE = preload("res://scenes/shockwave.tscn")
	var shockwave = SHOCKWAVE.instantiate()
	shockwave.center = global_position
	get_tree().get_first_node_in_group("shockwave_canvas").add_child(shockwave)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		pressed_jump_tick = Time.get_ticks_msec()
	if event.is_action_released("ui_accept"):
		released_jump_tick = Time.get_ticks_msec()
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		wall_jumping = false

func get_tile_global_position(tilemap: TileMapLayer, collision_point: Vector2) -> Vector2:
	# 1. Convert global collision point to TileMap's local coordinates
	var collision_point_local_to_tilemap := tilemap.to_local(collision_point)

	# 2. Convert TileMap local point to tilemap cell coordinates (Vector2i)
	var tile_coords := tilemap.local_to_map(collision_point_local_to_tilemap)

	# 3. Convert tilemap cell coordinates back to TileMap's local position (center of the tile)
	# This gives you the local position of the *top-left* corner of the tile in the TileMap's space.
	# If you want the center, you'd add half the tile_size.
	var tile_local_position := tilemap.map_to_local(tile_coords)

	# To get the center of the tile, add half of the tile_set's tile_size
	var tile_size_half := tilemap.tile_set.tile_size / 2.0
	var tile_center_local_position := tile_local_position + tile_size_half

	# 4. Convert that TileMap local position (of the tile's center) to global coordinates
	var tile_global_position := tilemap.to_global(tile_center_local_position) - Vector2(tilemap.tile_set.tile_size)
	
	return tile_global_position
