extends TileMapLayer

@export var activated := false

var collision_layers : Array[int]

func _ready():
	tile_set = tile_set.duplicate(true)
	for n in range(tile_set.get_physics_layers_count()):
		collision_layers.insert(n, tile_set.get_physics_layer_collision_layer(n))
	trigger(!activated)

func trigger(value : bool = activated):
	activated = !value
	if activated:
		tile_set.get_source(0).texture = preload("res://resources/background.png")
		for n in range(tile_set.get_physics_layers_count()):
			tile_set.set_physics_layer_collision_layer(n, collision_layers[n])
		z_index = 10
	else:
		tile_set.get_source(0).texture = preload("res://resources/background_50.png")
		for n in range(tile_set.get_physics_layers_count()):
			tile_set.set_physics_layer_collision_layer(n, 0)
		z_index = -1
