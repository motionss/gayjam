@tool
extends EditorScript

# Set the layer you want to check for (0-31)
@export var target_collision_layer: int = 3

func _run():
	print("Searching for nodes with collision layer " + str(target_collision_layer) + " activated...")
	
	var project_path = ProjectSettings.globalize_path("res://")
	var dir = DirAccess.open("res://")
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				var scene_path = "res://" + file_name
				check_scene_for_collision_layer(scene_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	print("Search complete.")

func check_scene_for_collision_layer(scene_path: String):
	var packed_scene = load(scene_path)
	if packed_scene is PackedScene:
		var scene_instance = packed_scene.instantiate()
		
		# Recursively check nodes in the scene
		find_nodes_with_collision_layer(scene_instance, target_collision_layer, scene_path)
		
		# Free the instance to prevent memory leaks in the editor
		scene_instance.free()

func find_nodes_with_collision_layer(node: Node, layer_to_check: int, scene_path: String):
	# Check if the node has collision_layer property (e.g., PhysicsBody2D/3D, Area2D/3D)
	if node.has_method("get_collision_layer"):
		var collision_layers = node.get_collision_layer()
		
		# Check if the target layer bit is set
		if (collision_layers & (1 << layer_to_check)) != 0:
			print("Found node '" + node.name + "' in scene '" + scene_path + "' with layer " + str(layer_to_check) + " activated.")
	
	# Recursively check children
	for child in node.get_children():
		find_nodes_with_collision_layer(child, layer_to_check, scene_path)
