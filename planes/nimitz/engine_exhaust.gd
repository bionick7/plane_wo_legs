extends MeshInstance3D

func _ready():
	assert(is_instance_valid(material_override))

func _on_update_ypr(ypr: Vector3, throttle: float):
	material_override.set_shader_parameter("throttle", throttle)
