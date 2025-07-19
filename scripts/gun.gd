extends Node2D
class_name Gun

@onready var gun_pivot = %GunPivot
@onready var loaded_gun = $GunPivot/LoadedGun
@onready var unloaded_gun = $GunPivot/UnloadedGun
@onready var shooting_point = $GunPivot/ShootingPoint
@onready var grapple_point = $GrapplePoint
@onready var player = $".."

@onready var hook_launch_audio = $HookLaunchAudio

@export var rest_length = 0.0
@export var stiffness = 50.0
@export var damping = 10.0

var can_shoot := true :
	set(value):
		if can_shoot == value:
			return
		can_shoot = value
		if is_instance_valid(loaded_gun):
			loaded_gun.visible = value
		if is_instance_valid(unloaded_gun):
			unloaded_gun.visible = !value
var current_hook : GrapplingHook
var hooked := false :
	get():
		return current_hook.hooked if current_hook != null else false
var angle_to_hook : float :
	get():
		return current_hook.angle_to_hook if current_hook != null else false
var hook_position :
	get():
		return current_hook.hook_pos if current_hook != null else null

var angle : float

func _process(delta):
	if current_hook == null or current_hook.grabbed_node != null:
		var mouse_position := get_global_mouse_position()
		var direction_to_mouse := global_position.direction_to(mouse_position)
		angle = atan2(direction_to_mouse.y, direction_to_mouse.x)
	else:
		angle = current_hook.angle_to_hook
	var is_facing_left = gun_pivot.scale.x == -1.0
	var final_angle = angle
	if is_facing_left:
		final_angle += deg_to_rad(180)
		var degs = rad_to_deg(final_angle)
		if degs > 90.0 and degs < 270.0:
			gun_pivot.scale.y = -1.0
		else:
			gun_pivot.scale.y = 1.0
	else:
		var degs = rad_to_deg(final_angle)
		if degs < -90.0 or degs > 90.0:
			gun_pivot.scale.y = -1.0
		else:
			gun_pivot.scale.y = 1.0
	gun_pivot.global_rotation = final_angle
	
func _physics_process(delta):
	grapple_point.global_position = shooting_point.global_position
	
	if !hooked or !hook_position:
		return
	
	var target_dir = player.global_position.direction_to(hook_position)
	var target_dist = player.global_position.distance_to(hook_position)
	
	var displacement = target_dist - rest_length
	
	var force = Vector2.ZERO
	
	if displacement > 0:
		var spring_force_magnitude = stiffness * displacement
		var spring_force = target_dir * spring_force_magnitude
		
		var velocity_along_target_dir = player.velocity.dot(target_dir)
		var damping_force_magnitude = -damping * velocity_along_target_dir
		var damping_force = target_dir * damping_force_magnitude
		
		force = spring_force + damping_force
	
	player.velocity += force * delta

func _input(event):
	if (event.is_action_pressed("shoot")):
		shoot()
	if (event.is_action_released("shoot") and current_hook != null):
		retract()

func shoot():
	if !can_shoot:
		return
	
	can_shoot = false
	
	hook_launch_audio.play()
	
	const GRAPPLING_HOOK = preload("res://scenes/grappling_hook.tscn")
	var grappling_hook = GRAPPLING_HOOK.instantiate()
	grappling_hook.global_rotation = gun_pivot.global_rotation
	grappling_hook.retracted.connect(on_hook_retracted)
	grappling_hook.gun_pivot = self
	grapple_point.add_child(grappling_hook)
	current_hook = grappling_hook
	
func retract():
	if current_hook == null:
		return
	
	current_hook.retract()

func on_hook_retracted():
	can_shoot = true
	current_hook = null
