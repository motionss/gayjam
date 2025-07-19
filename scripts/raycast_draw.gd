extends RayCast2D

func _ready():
	enabled = true 

func _physics_process(delta):
	queue_redraw() # Request a redraw in _draw()

func _draw():
	# Draw the raycast line
	var start_point = Vector2.ZERO
	var end_point = target_position
	var color = Color.WHITE # Default color

	if is_colliding():
		color = Color.RED # Change color on collision
		end_point = to_local(get_collision_point()) # Draw to the actual collision point
		draw_circle(end_point, 1, Color.YELLOW) # Draw a small circle at the collision point

	draw_line(start_point, end_point, color, 1) # Draw the line with thickness 2
