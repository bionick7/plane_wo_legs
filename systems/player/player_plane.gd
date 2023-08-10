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
@export var blackout_curve: BlackoutCurve

@export_group("References")
@export var flight_dynamics: Node
@export var engine_transform: Node3D
@export var missile_launcher: MissileLauncher
@export var missile_paths: Array[NodePath]

@onready var missile_stack = missile_paths.map(get_node)
@onready var center_of_mass = $COG.position
@onready var inverse_mass = 1 / mass
@onready var inverse_inertia_tensor = inertia_tensor.inverse()

var throttle: float
var locked_target: TrackingAnchor = null

var angular_acceleration: Vector3
var linear_acceleration: Vector3
var prev_linear_velocity: Vector3
var prev_angular_velocity: Vector3
var fealt_acceleration: Vector3

var angular_velocity: Vector3

signal set_missile_certainty(x: float)

func _ready():
	super._ready()
	#blackout_curve.test()
	flight_dynamics.W = mass * CommonPhysics.g
	flight_dynamics.analyse()

func _process(dt: float):
	super._process(dt)
	
	if not is_instance_valid(locked_target) or not locked_target.is_inside_tree():
		locked_target = null
	
	throttle = InputManager.get_throttle()
	missile_launcher.update(locked_target)
	
	#write_line("density: %5.4f" % CloudManager.get_cloud_density(global_position))
	debug_drawer.draw_basis(global_transform.basis, Vector3.ZERO, Color.DARK_GRAY)
	debug_drawer.draw_line(Vector3.ZERO, Vector3.BACK * throttle * 5, Color.LIGHT_BLUE)
	
	var observed_linear_acceleration = (velocity - prev_linear_velocity) / dt
	var observed_angular_acceleration = (angular_velocity - prev_angular_velocity) / dt
	prev_linear_velocity = velocity
	prev_angular_velocity = angular_velocity
	fealt_acceleration = observed_linear_acceleration - CommonPhysics.get_acc(position, velocity)
	var pilot_arm = $Pilot.position - center_of_mass
	fealt_acceleration += observed_angular_acceleration.cross(pilot_arm)  # cylinder is not accelerating
	blackout_curve.push_acceleration(basis.inverse() * fealt_acceleration, dt)
	InputManager.control_multiplier = blackout_curve.get_control()
	
	visual_ypr = InputManager.get_yaw_pitch_roll(true)
	visual_throttle = throttle
	
	var next_missile := missile_launcher.get_next_missile()

func _input(event: InputEvent):
	if event.is_action_pressed("Gun"):
		if Input.is_action_pressed("lock"):
			missile_launcher.launch_next_missile()
		else:
			gun.start_fire()
	elif event.is_action_released("Gun"):
		gun.cease_fire()
	
	if Input.is_action_pressed("lock"):
		var min_angle = deg_to_rad(min_lock_angle_deg)
		var lock_candidate: TrackingAnchor = null
		for trackable in get_tree().get_nodes_in_group("TrackingAnchors"):
			if (trackable.target_flags & TrackingAnchor.TGT_FLAGS.PLAYER_CAN_TARGET) == 0:
				continue
			if trackable.ref == self or trackable.is_hidden():
				continue
			if trackable.allegency_flags & 0x02 == 0:
				continue
			var angle = basis.z.angle_to(trackable.global_position - global_position)
			if angle < min_angle:
				lock_candidate = trackable
				min_angle = angle
		if is_instance_valid(lock_candidate):
			locked_target = lock_candidate
			var next_missile := missile_launcher.get_next_missile()
			if is_instance_valid(next_missile):
				var certainty = clamp((next_missile.sim_path(velocity, lock_candidate) - 10.0) / 40.0, 0.0, 1.0)
				emit_signal("set_missile_certainty", certainty)
	else:
		emit_signal("set_missile_certainty", -1)
		

func update_velocity_rotation(dt: float, manual: bool):
	super.update_velocity_rotation(dt, manual)
	# TODO: figure out dt analytically (How hard is it?)
	const between_steps = 3
	
	var force_moment = [Vector3.ZERO, Vector3.ZERO]
	var thrust_force = -engine_transform.global_transform.basis.y * throttle * thrust_to_weight * 9.81 * mass
	var thrust_moment = thrust_force.cross(basis * (engine_transform.position - center_of_mass))
	
	var external_acc = CommonPhysics.get_acc(global_position, velocity)
	flight_dynamics.W = mass * external_acc.length()
	
	$DebugDrawer.draw_line_global(global_position, global_position + engine_transform.global_transform.basis.y, Color.DARK_GREEN)
	
	#printt(engine_transform.position, center_of_mass, engine_transform.position - center_of_mass)
	#printt(thrust_force, thrust_moment)
	
	# var aero_force = basis.inverse() * flight_dynamics.get_kinematics(velocity, angular_velocity)[0]
	# var L_D = -aero_force.y / aero_force.z
	# logger.write_line("L/D = %f" % L_D)
		
	var t0 = Time.get_ticks_usec()
	for i in range(between_steps):
		var step = dt / between_steps
		
		# Fwd euler
		force_moment = flight_dynamics.get_kinematics(velocity, angular_velocity)
		force_moment[0] += thrust_force
		force_moment[1] += thrust_moment
		
		linear_acceleration = inverse_mass * force_moment[0] + external_acc
		angular_acceleration = inverse_inertia_tensor * force_moment[1]
		
		if not frozen or manual_step:
			velocity += linear_acceleration * step
			angular_velocity += angular_acceleration * step
		
		# more or less exactly from godot_body_3d.cpp
		if not angular_velocity.is_zero_approx():
			var rot = Basis(angular_velocity.normalized(), angular_velocity.length() * step)
			var one_minus_rot = Basis(Vector3.RIGHT - rot.x, Vector3.UP - rot.y, Vector3.BACK - rot.z)
			# velocity += (one_minus_rot * basis) * center_of_mass / step
			if not frozen or manual_step:
				basis = rot * basis
	
	#$DebugDrawer.draw_line_global(global_position, global_position + force_moment[0] * 0.001, Color.RED)
	#$DebugDrawer.draw_line_global(global_position, global_position + force_moment[1] * 0.001, Color.YELLOW)
	
func get_air_velocity() -> Vector3:
	#if pause_menu.get_setting("coreolis force", true):
	#	return linear_velocity - global_position.cross(Vector3.FORWARD).normalized() * 5
	return velocity

