class_name NPCBehaviour
extends Resource

@export_group("Flight")
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var stall_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var max_level_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s") var max_vertical_speed: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s²") var max_acceleration: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m/s²") var thrust_acceleration: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:rad/s") var max_roll_rate: float

@export_range(0, 2, 0.001) var speed_overshoot: float
@export_range(0, 100, 0.001, "or_greater", "hide_slider", "suffix:m/s") var crash_safety_margin: float

@export_group("Gun")
@export var use_gun: bool
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m") var gun_shoot_distance: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_min_burst_length: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_max_burst_length: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_cooldown: float

var maneuver_speed: float:
	get: 
		return stall_speed * sqrt(max_acceleration)
