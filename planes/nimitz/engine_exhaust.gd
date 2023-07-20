extends MeshInstance3D

@export var material: ShaderMaterial

@onready var input_manager = $"/root/InputManager"

func _ready():
	assert(is_instance_valid(material))

func _process(dt: float):
	var throttle = input_manager.get_throttle()
	material.set_shader_parameter("throttle", throttle)
