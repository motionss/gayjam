extends GPUParticles2D

func _ready():
	one_shot = true
	emitting = true
	finished.connect(queue_free)
