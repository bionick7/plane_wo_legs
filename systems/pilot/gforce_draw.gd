extends ColorRect

@export var blackout_curve: BlackoutCurve

func _process(dt: float):
	material.set_shader_parameter("greyout", blackout_curve.get_greyout())
	material.set_shader_parameter("redout", blackout_curve.get_redout())
	material.set_shader_parameter("tunnel", blackout_curve.get_tunnel())
	material.set_shader_parameter("blackout", blackout_curve.get_blackout())
	
