class_name PlayerPlane
extends PlaneInterface

const BODY_TO_LOCAL_TRANSF = Basis(
	Vector3( 0,-1, 0), 
	Vector3( 1, 0, 0), 
	Vector3( 0, 0, 1)
)

const LOCAL_TO_BODY_TRANSF = Basis(
	Vector3( 0,-1, 0), 
	Vector3( 1, 0, 0), 
	Vector3( 0, 0, 1)
)

@export var thrust_to_weight = .8
@export_range(0, 1, 0.01, "or_greater", "hide_slider", "suffix:kg") var mass: float = 1
@export var inertia_tensor: Basis = Basis.IDENTITY
@export var min_lock_angle_deg: float

@export_group("References")
@export var flight_dynamics: Node
@export var engine_transform: Node3D

@onready var pause_menu = $"/root/PauseMenu"
@onready var input_manager = $"/root/InputManager"

@onready var center_of_mass = $COG.position
@onready var inverse_mass = 1 / mass
@onready var inverse_inertia_tensor = inertia_tensor.inverse()

var throttle: float
var locked_target: PlaneInterface = null

var angular_acceleration: Vector3
var linear_acceleration: Vector3
var prev_linear_velocity: Vector3
var prev_angular_velocity: Vector3
var fealt_acceleration: Vector3

var angular_velocity: Vector3


func _process(dt: float):
	super._process(dt)
	
	debug_drawer.draw_basis(global_transform.basis, Vector3.ZERO, Color.DARK_GRAY)
	
	throttle = input_manager.get_throttle()
	debug_drawer.draw_line(Vector3.ZERO, Vector3.BACK * throttle * 5, Color.LIGHT_BLUE)
	
	var observed_linear_acceleration = (velocity - prev_linear_velocity) / dt
	var observed_angular_acceleration = (angular_velocity - prev_angular_velocity) / dt
	prev_linear_velocity = velocity
	prev_angular_velocity = angular_velocity
	fealt_acceleration = observed_linear_acceleration - common_physics.get_acc(position, velocity)
	var pilot_arm = $Pilot.position - center_of_mass
	fealt_acceleration += observed_angular_acceleration.cross(pilot_arm)  # cylinder is not accelerating
	
	visual_ypr = input_manager.get_yaw_pitch_roll(true)
	visual_throttle = throttle

func _input(event: InputEvent):
	if event.is_action_pressed("Gun"):
		gun.start_fire()
	elif event.is_action_released("Gun"):
		gun.cease_fire()
	
	if event.is_action_pressed("lock"):
		var min_angle = deg_to_rad(min_lock_angle_deg)
		var lock_candidate: PlaneInterface = null
		for plane in get_tree().get_nodes_in_group("Planes"):
			if plane == self or plane.is_hidden():
				continue
			if plane.allegency_flags & 0x02 == 0:
				continue
			var angle = basis.z.angle_to(plane.global_position - global_position)
			if angle < min_angle:
				lock_candidate = plane
				min_angle = angle
		if is_instance_valid(lock_candidate):
			locked_target = lock_candidate

func update_velocity_rotation(dt: float, manual: bool):
	super.update_velocity_rotation(dt, manual)
	const between_steps = 3
	
	var force_moment = [Vector3.ZERO, Vector3.ZERO]
	var thrust_force = -engine_transform.global_transform.basis.y * throttle * thrust_to_weight * 9.81 * mass
	var thrust_moment = thrust_force.cross(basis * (engine_transform.position - center_of_mass))
	
	$DebugDrawer.draw_line_global(global_position, global_position + engine_transform.global_transform.basis.y, Color.DARK_GREEN)
	
	#printt(engine_transform.position, center_of_mass, engine_transform.position - center_of_mass)
	#printt(thrust_force, thrust_moment)
	
	var t0 = Time.get_ticks_usec()
	for i in range(between_steps):
		var step = dt / between_steps
		
		var linear_velocity_next = velocity
		var angular_velocity_next = angular_velocity
		
		# Back euler
		for j in range(2):
			force_moment = flight_dynamics.get_kinematics(linear_velocity_next, angular_velocity_next)
			force_moment[0] += thrust_force
			force_moment[1] += thrust_moment
			
			linear_acceleration = inverse_mass * force_moment[0] + common_physics.get_acc(position, linear_velocity_next)
			angular_acceleration = inverse_inertia_tensor * force_moment[1]
			
			linear_velocity_next = velocity + linear_acceleration * step
			angular_velocity_next = angular_velocity + angular_acceleration * step
		
		velocity = linear_velocity_next
		angular_velocity = angular_velocity_next
		# more or less exactly from godot_body_3d.cpp
		var rot = Basis(angular_velocity.normalized(), angular_velocity.length() * step)
		var one_minus_rot = Basis(Vector3.RIGHT - rot.x, Vector3.UP - rot.y, Vector3.BACK - rot.z)
		# velocity += (one_minus_rot * basis) * center_of_mass / step;
		basis = rot * basis;
	
	$DebugDrawer.draw_line_global(global_position, global_position + force_moment[0] * 0.001, Color.RED)
	$DebugDrawer.draw_line_global(global_position, global_position + force_moment[1] * 0.001, Color.YELLOW)
	
func get_air_velocity() -> Vector3:
	#if pause_menu.get_setting("coreolis force", true):
	#	return linear_velocity - global_position.cross(Vector3.FORWARD).normalized() * 5
	return velocity

