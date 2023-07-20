extends Node

const g = 9.81  # m/ s²
const ang_vel = Vector3.FORWARD * sqrt(g / 4000)

var is_in_cylinder = true

@onready var pause_menu = $"/root/PauseMenu"

func get_air_density(pos: Vector3) -> float:
	return 1.225

func get_acc(pos: Vector3, vel: Vector3) -> Vector3:
	if is_in_cylinder:
		return get_cylinder_acc(pos, vel)
	else:
		return g * Vector3.DOWN
		
func get_cylinder_acc(pos: Vector3, vel: Vector3) -> Vector3:
	# returns centrifugal and coriolis pseudo forces
	if pause_menu.get_setting("coreolis force", true):
		return - 2 * ang_vel.cross(vel) - ang_vel.cross(ang_vel.cross(pos))
	else:
		return -ang_vel.cross(ang_vel.cross(pos))

func get_centrifugal_acc(pos: Vector3) -> Vector3:
	return -ang_vel.cross(ang_vel.cross(pos))
	
func get_coreolis_acc(vel: Vector3) -> Vector3:
	return - 2 * ang_vel.cross(vel)

func distance_to_bounds(pos: Vector3) -> float:
	# Basically inverse sdf
	if is_in_cylinder:
		return min(6000 - abs(pos.z), 4000 - Vector2(pos.x, pos.y).length())
	else:
		return pos.y

func is_oob(pos: Vector3) -> bool:
	return distance_to_bounds(pos) < 0.
