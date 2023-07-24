extends Node

const g = 9.81  # m/s²
const ang_vel = Vector3.FORWARD * sqrt(g / 4000)
const R = 287  # J/(kg K)
const ɣ = 1.4  # cp / cv

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
		return -2 * ang_vel.cross(vel) - ang_vel.cross(ang_vel.cross(pos))
	else:
		return -ang_vel.cross(ang_vel.cross(pos))

func get_centrifugal_acc(pos: Vector3) -> Vector3:
	return -ang_vel.cross(ang_vel.cross(pos))
	
func get_coreolis_acc(vel: Vector3) -> Vector3:
	return -2 * ang_vel.cross(vel)

func get_up(pos: Vector3) -> Vector3:
	if is_in_cylinder:
		var res = -(pos - Vector3.BACK * pos.z).normalized()
		if res.is_normalized():  # will fail is res ~= 0
			return res
	return Vector3.UP
		
func get_altitude(pos: Vector3) -> float:
	var pos2d: Vector3 = pos - pos.project(Vector3.FORWARD)
	if is_in_cylinder:
		return 4000 - pos2d.length()
	else:
		return pos.y

func get_soundspeed(pos: Vector3) -> float:
	var temperature = 288.15
	return sqrt(ɣ * R * temperature)

func distance_to_bounds(pos: Vector3) -> float:
	# Basically inverse sdf
	if is_in_cylinder:
		return min(6000 - abs(pos.z), 4000 - Vector2(pos.x, pos.y).length())
	else:
		return pos.y

func get_mach_correction_factor(pos: Vector3, speed: float) -> float:
	return 1.

func is_oob(pos: Vector3) -> bool:
	return distance_to_bounds(pos) < 0.
