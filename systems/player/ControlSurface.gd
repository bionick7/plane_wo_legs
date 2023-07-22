extends Node3D

@export var control_matrix: Basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

@onready var initial_basis = basis

func _on_update_ypr(ypr: Vector3, throttle: float):
	var rot = control_matrix * ypr
	if rot.length_squared() > 0:
		basis = initial_basis * Basis(rot.normalized(), rot.length())
