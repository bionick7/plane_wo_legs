extends Node3D

@export var control_matrix: Basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

@onready var input_manager = $"/root/InputManager"
@onready var initial_basis = basis

func _process(dt):
	var rot = control_matrix * input_manager.get_yaw_pitch_roll(false)
	if rot.length_squared() > 0:
		basis = initial_basis * Basis(rot.normalized(), rot.length())
