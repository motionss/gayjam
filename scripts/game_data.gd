extends Node

var initial_data := {
	"last_checkpoint": null,
	"last_camera_state": null,
	"has_gun": false
}
var data := initial_data

func save_data():
	var file = FileAccess.open("user://game_data.dat", FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_data() -> Dictionary:
	var loaded_data
	if FileAccess.file_exists("user://game_data.dat"):
		var file = FileAccess.open("user://game_data.dat", FileAccess.READ)
		if file:
			var data = file.get_var()
			loaded_data = data
			file.close()
	else:
		save_data()
	self.data = initial_data if loaded_data == null else loaded_data
	return self.data
