class_name MissileReadiness
extends MeshInstance3D

func set_player(p_player_plane: PlayerPlane) -> void:
	p_player_plane.missile_certainty_calculated.connect(_set_certainty)
	p_player_plane = p_player_plane

func _set_certainty(weight: float) -> void:
	if weight < 0.0:
		hide()
		return
	show()
	var freq: = 0.0 if weight > 0.0 else 4.0
	material_override.set_shader_parameter("outside_radius", lerp(0.01, 0.2, weight))
	material_override.set_shader_parameter("blinking_frequency", freq)
	
