extends CharacterBody2D
class_name Player

const SPEED := 80.0
const JUMP_VELOCITY := -150.0
const SPRING_JUMP_VELOCITY := -250.0
const MAX_FALL_VELOCITY := 180.0

const COYOTE_TIME_TICKS := 100
const JUMP_BUFFERING_TICKS := 60

@onready var flying_particles = $FlyingParticles
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var collision_shape_2d = $CollisionShape2D
@onready var collision_shape_initial_position = collision_shape_2d.position
@onready var feet_marker = $FeetMarker
@onready var head_top_right_in: RayCast2D = $HeadTopRightIn
@onready var head_top_right_out: RayCast2D = $HeadTopRightOut
@onready var head_top_left_in: RayCast2D = $HeadTopLeftIn
@onready var head_top_left_out: RayCast2D = $HeadTopLeftOut
@onready var gun = $Gun
@onready var gun_pivot = %GunPivot

var pressed_jump_tick := 0
var last_tick_on_floor := 0
var prev_velocity : Vector2

var falling := false
var jumping := false
var is_on_spring := false
var hooked := false :
	get():
		return gun.hooked

func _physics_process(delta):
	var current_tick = Time.get_ticks_msec()
	
	if jumping:
		# Jump corner correction
		#if !falling:
			print(head_top_left_in.is_colliding() and !head_top_left_out.is_colliding(), head_top_right_in.is_colliding() and !head_top_right_out.is_colliding())
			if head_top_left_in.is_colliding() and !head_top_left_out.is_colliding():
				var collider = head_top_left_in.get_collider()
				if collider is TileMapLayer:
					var tile_global_position := get_tile_global_position(collider, head_top_left_in.global_position)
					var x_diff := head_top_left_in.global_position.x - (tile_global_position.x + float(collider.tile_set.tile_size.x))
					global_position.x = floor(global_position.x - x_diff) + 0.01
					velocity = prev_velocity
			if head_top_right_in.is_colliding() and !head_top_right_out.is_colliding():
				var collider = head_top_right_in.get_collider()
				if collider is TileMapLayer:
					var tile_global_position := get_tile_global_position(collider, head_top_right_in.global_position)
					var x_diff := head_top_right_in.global_position.x - tile_global_position.x
					global_position.x = floor(global_position.x - x_diff) - 0.01
					velocity = prev_velocity
	
	# Save falling state
	if velocity.y > 0:
		falling = true
	elif velocity.y < 0 or is_on_floor():
		if falling and prev_velocity.y >= 170.0:
			animated_sprite_2d.scale = Vector2(1.3, 0.6)
			instantiate_jump_particles()
		falling = false
	
	# Set floor dependant values
	if is_on_floor():
		last_tick_on_floor = current_tick
		jumping = false
		is_on_spring = false

	# Get the input_direction and handle the movement/deceleration
	var input_direction := Input.get_axis("move_left", "move_right")
	if input_direction or velocity.x:
		animated_sprite_2d.play('walk')
		if input_direction < 0.0 or velocity.x < 0.0:
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
		velocity += get_gravity() * (1 if falling or hooked else 0.6) * delta
		if falling and !hooked:
			velocity.y = minf(velocity.y, MAX_FALL_VELOCITY)
	elif !hooked:
		velocity.y = 0
	
	# Horizontal velocity
	if input_direction == 0 and is_on_floor():
		velocity.x = 0
	else:
		velocity.x = lerpf(
			velocity.x,
			SPEED * (1 if is_on_floor() else 1.1) * input_direction,
			(7 if is_on_floor() else 6) * delta
		)

	# Handle jump
	if pressed_jump_tick > 0 and !jumping and \
		# Jump buffer
		((is_on_floor() and (current_tick - pressed_jump_tick <= JUMP_BUFFERING_TICKS)) or \
		# Coyote time
		(!is_on_floor() and (current_tick - last_tick_on_floor <= COYOTE_TIME_TICKS))):
			jump()
	if Input.is_action_just_released("ui_accept") and !falling and !is_on_spring:
		velocity.y = 0
	
	# Animations
	if is_on_floor():
		if input_direction:
			animated_sprite_2d.play('walk')
		else:
			animated_sprite_2d.play('idle')
	else:
		if velocity.y < -20.0:
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

func jump(jump_velocity := JUMP_VELOCITY, particles := true):
	jumping = true
	velocity.y = jump_velocity
	pressed_jump_tick = 0
	
	animated_sprite_2d.scale.x = 0.6
	
	# Jump particles
	if particles:
		instantiate_jump_particles()

func spring_jump():
	is_on_spring = true
	jump(SPRING_JUMP_VELOCITY, false)
	move_and_slide()

func instantiate_jump_particles():
	const JUMP_PARTICLES = preload("res://particles/jump_particles.tscn")
	var particles = JUMP_PARTICLES.instantiate()
	particles.global_position = feet_marker.global_position
	get_parent().add_child(particles)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		pressed_jump_tick = Time.get_ticks_msec()
	if event.is_action_released("ui_accept"):
		pressed_jump_tick = 0

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
