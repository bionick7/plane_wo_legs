class_name ShooterBehavior
extends Resource

@export_group("Gun")
@export var use_gun: bool
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m") var gun_shoot_distance: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m") var gun_shoot_delta: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_min_burst_length: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_max_burst_length: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:s") var gun_cooldown: float
@export_range(0, 1, 0.001, "or_greater") var gun_preaim_factor: float

@export_group("Detection")
@export var sees_all: bool
@export var sees_through_clouds: bool = false
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "radians", "degrees") var view_cone_angle: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider", "suffix:m") var view_cone_radius: float:
	set(x): view_cone_radius_sqr = x*x
@export var search_interval: float

var view_cone_radius_sqr: float
