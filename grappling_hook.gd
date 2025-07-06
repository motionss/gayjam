extends Node2D
class_name GrapplingHook

signal retracted

@export_flags_2d_physics var collision_mask_layers: int = 1
@export var collision_shape_resource: Shape2D

const MAX_DISTANCE = 80.0
const MAX_BOX_RELEASE_MAGNITUDE = 300.0

@onready var hook = $Hook
@onready var var_chains = $Chains

var gun_pivot : Gun
var noise: FastNoiseLite

@onready var direction := transform.x
@onready var hook_pos : Vector2 = hook.global_position
@onready var hook_destination := hook_pos + (direction * MAX_DISTANCE)
@onready var hook_local_pos := to_local(hook_pos)

var forward := true
var hooked := false :
	set(value):
		hooked = value
		if hooked:
			instantiate_particles()
			get_tree().get_first_node_in_group("camera").shake_camera()
var retracting := false
var grabbed_node
var last_frame_grabbed_pos: Vector2
var last_grabbed_pos_available : Vector2

var angle_to_hook : float

var travel_progress := 0.0
var travel_duration := 0.2

func _physics_process(delta):
	if !hooked or retracting or (grabbed_node != null):
		travel_progress += delta / travel_duration
		travel_progress = min(travel_progress, 1.0)

		var eased_progress: float
		if forward:
			eased_progress = 1.0 - pow(1.0 - travel_progress, 4)
		else:
			if grabbed_node != null:
				var direction = (hook_pos - global_position).normalized()
				hook_destination = global_position + (Vector2.from_angle(gun_pivot.angle) * 5)
			else:
				hook_destination = global_position
			eased_progress = pow(travel_progress, 4)

		var current_hook_global_pos = hook.global_position
		var target_hook_pos_from_lerp := hook_pos.lerp(hook_destination, eased_progress)
		var intended_movement = target_hook_pos_from_lerp - current_hook_global_pos
		var shape_offset = intended_movement.normalized() * 2

		if forward:
			# Detect if the next movement the hook wants to make could have a collision
			# This is done to prevent the hook from going through nodes
			var space_state = get_world_2d().direct_space_state
			var movement_query = PhysicsShapeQueryParameters2D.new()
			movement_query.shape = collision_shape_resource
			movement_query.transform = Transform2D(hook.global_rotation, current_hook_global_pos)
			movement_query.motion = intended_movement
			movement_query.collision_mask = collision_mask_layers
			
			var result = space_state.cast_motion(movement_query)
			var result_vector = Vector2(result[1], result[1])
			
			if result_vector != Vector2.ONE:
				hook_pos = current_hook_global_pos + (intended_movement * result_vector) + shape_offset
				
				# Detect what node the hook collided with
				var collision_query = PhysicsShapeQueryParameters2D.new()
				#var rect_shape = RectangleShape2D.new()
				#rect_shape.size = Vector2.ONE * 4
				collision_query.shape = collision_shape_resource
				collision_query.transform = Transform2D(hook.global_rotation - deg_to_rad(90), hook_pos + shape_offset)
				collision_query.collision_mask = collision_mask_layers
				
				if get_tree().is_debugging_collisions_hint():
					var debug_area = Area2D.new()
					debug_area.name = "DebugCollisionQuery"
					
					var debug_collision_shape = CollisionShape2D.new()
					debug_collision_shape.shape = collision_shape_resource
					debug_area.add_child(debug_collision_shape)
					
					debug_area.global_transform = collision_query.transform
					
					get_tree().get_root().add_child(debug_area)
				
				var collisions = space_state.intersect_shape(collision_query)
				
				if !collisions.is_empty():
					var first_collision = collisions[0]
					var collider_node = first_collision.collider
					if collider_node.is_in_group("level"):
						hooked = true
					else:
						grabbed_node = collider_node
						grabbed_node.grabbed = true
						grabbed_node.collision_shape_2d.disabled = true
						forward = false
			else:
				hook_pos = target_hook_pos_from_lerp
		else:
			hook_pos = target_hook_pos_from_lerp
		
		if grabbed_node != null:
			var body_rid = grabbed_node.get_rid()
			var target_grab_pos = hook_pos + (global_position.direction_to(hook_pos).normalized() * 5)
			
			var grabbed_node_collision_query = PhysicsShapeQueryParameters2D.new()
			grabbed_node_collision_query.shape = grabbed_node.collision_shape_2d.shape
			grabbed_node_collision_query.transform = Transform2D(grabbed_node.global_rotation, target_grab_pos)
			grabbed_node_collision_query.collision_mask = grabbed_node.collision_mask
			var space_state = get_world_2d().direct_space_state
			var grabbed_node_collisions = space_state.intersect_shape(grabbed_node_collision_query)
			
			if grabbed_node_collisions.is_empty():
				PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D.IDENTITY.translated(target_grab_pos))
				PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
				PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
				last_frame_grabbed_pos = target_grab_pos
				last_grabbed_pos_available = target_grab_pos

		var distance_to_destination = hook_pos.distance_to(hook_destination)
		if distance_to_destination < 1.0:
			hook_pos = hook_destination
			if forward:
				forward = false
				travel_progress = 0.0
			else:
				if grabbed_node == null:
					retracted.emit()
					queue_free()

	hook.global_position = hook_pos
	angle_to_hook = global_position.angle_to_point(hook_pos)
	if !hooked:
		hook.global_rotation = angle_to_hook
	var_chains.global_rotation = angle_to_hook - deg_to_rad(90)
	var_chains.region_rect.size.y = hook_pos.distance_to(var_chains.global_position)
	hook_local_pos = to_local(hook_pos)

func retract():
	if hooked:
		instantiate_particles()
	if grabbed_node != null:
		# Calculate the linear velocity of the grabbed node after releasing it
		var calculated_linear_velocity : Vector2 = (last_frame_grabbed_pos - grabbed_node.global_position) / get_physics_process_delta_time()
		if calculated_linear_velocity.length() > MAX_BOX_RELEASE_MAGNITUDE:
			calculated_linear_velocity = calculated_linear_velocity.normalized() * MAX_BOX_RELEASE_MAGNITUDE
		PhysicsServer2D.body_set_state(grabbed_node.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, calculated_linear_velocity)
		
		grabbed_node.grabbed = false
		grabbed_node.collision_shape_2d.disabled = false
		grabbed_node = null
	retracting = true
	forward = false
	hooked = false

func instantiate_particles():
	const JUMP_PARTICLES = preload("res://particles/jump_particles.tscn")
	var particles = JUMP_PARTICLES.instantiate()
	particles.global_position = hook_pos
	particles.global_rotation = -angle_to_hook
	get_tree().get_first_node_in_group("main").add_child(particles)
