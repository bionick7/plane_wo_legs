class_name MissileGuidanceBehaviour
extends Resource

@export var cruise_aiming_method: Missile.AimingMethod
@export var final_aiming_method: Missile.AimingMethod
@export_range(0, 1000, 1, "or_greater", "hide_slider", "suffix:m") var transition_distance: float = 300
@export_range(0, 1000, 1, "or_greater", "hide_slider", "suffix:m") var maximum_distance: float = 3000
@export_range(0, 1000, 1, "or_greater", "hide_slider", "suffix:m/s²") var acceleration: float = 100
@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s²") var angular_acceleration: float = 80

@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s") var cruise_speed: float = 300
@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s") var final_speed: float = 250
@export_range(0, 180, 0.1, "radians", "degrees") var view_cone = PI / 3
