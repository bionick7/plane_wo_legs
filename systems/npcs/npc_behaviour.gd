class_name PlaneBehaviour
extends ShooterBehavior

@export_group("Performance")
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var stall_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var max_level_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var max_vertical_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s²") var max_acceleration: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s²") var thrust_acceleration: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "radians", "suffix:°/s") var max_roll_rate: float

@export_group("Flight behaviour")
@export_range(0, 2, 0.001) var speed_overshoot: float
@export_range(0, 100, 0.001, "or_greater", "hide_slider", "suffix:m") var crash_safety_margin: float
@export_range(0, 100, 0.001, "or_greater", "hide_slider", "suffix:m") var plane_safe_radius: float

@export_group("Detection")
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "radians", "degrees") var chase_cone_angle: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m") var chase_cone_radius: float:
	set(x): chase_cone_radius_sqr = x*x


var chase_cone_radius_sqr: float

var maneuver_speed: float:
	get: return stall_speed * sqrt(max_acceleration)
