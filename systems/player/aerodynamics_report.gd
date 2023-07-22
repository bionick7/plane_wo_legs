extends Node

const BODY_TO_LOCAL_TRANSF = Basis(
	Vector3( 0, 0, 1), 
	Vector3(-1, 0, 0), 
	Vector3( 0,-1, 0)
)

@export var enabled: bool = true
@export var use_control_multiplier: bool = true
@export var use_auto_trim: bool = true
@export_group("References")
@export var player_plane: PlayerPlane
@export var fm: Resource

@export_group("Control")
@export var elevator_limits_degrees: Vector2 = Vector2(-25, 25)
@export var aileron_limits_degrees: Vector2 = Vector2(-10, 10)
@export var rudder_limits_degrees: Vector2 = Vector2(-25, 25)

@onready var input_manager = $"/root/InputManager"
@onready var common_physics = $"/root/CommonPhysics"
@onready var debug_drawer = $"../DebugDrawer"

var stall_progress = 0
var last_query_time = 0
var current_ingame_time = 0

var prev_α = 0. / 0.

func _ready():
	fm.init()

func _process(dt: float):
	current_ingame_time += dt

func get_kinematics(vel: Vector3, ang_vel_glob: Vector3) -> Array:
	if not enabled:
		return [Vector3.ZERO, Vector3.ZERO]
	
	var dt = current_ingame_time - last_query_time
	last_query_time = current_ingame_time
	
	var basis = player_plane.global_transform.basis
	var Q = common_physics.get_air_density(player_plane.global_position) * vel.length_squared() * 0.5
	var α = (vel - vel.project(basis.x)).signed_angle_to(basis.z, -basis.x)
	var β = (vel - vel.project(basis.y)).signed_angle_to(basis.z, basis.y)
	var V = vel.length()
	
	fm.update_stall_progress(α, dt)
	stall_progress = fm.stall_progress
	var α_dot = 0
	if not is_nan(prev_α) and dt > 0:
		α_dot = (prev_α - α) / dt
	prev_α = α
	
	var control_multiplier = 1
	if use_control_multiplier and Q > 0:
		control_multiplier = min(1000 / Q, 1)
	
	var trim = 0
	if V > 5 and use_auto_trim:
		trim = fm.get_trim(α)
	input_manager.pitch_trim = clamp(trim, -2, 2)
	var ypr = input_manager.get_yaw_pitch_roll(false) * control_multiplier
	var δr = _limit(-ypr.x, rudder_limits_degrees * deg_to_rad(1))
	var δe = _limit(ypr.y, elevator_limits_degrees * deg_to_rad(1)) + trim
	var δa = _limit(-ypr.z, aileron_limits_degrees * deg_to_rad(1))
	var br = input_manager.get_airbrake()
	var ang_vel = basis.inverse() * ang_vel_glob
	var p = fm.b / V *  ang_vel.z
	var q = fm.c / V * -ang_vel.x
	var r = fm.b / V * -ang_vel.y
	if V == 0:
		p = 0
		q = 0
		r = 0
	
	var L = Q * fm.S * fm.b * fm.Cl(β, p, r, δr, δa)
	var M = Q * fm.S * fm.c * fm.Cm(α, α_dot, q, δe, br)
	var N = Q * fm.S * fm.b * fm.Cn(β, p, r, δr, δa)
	
	var X = Q * fm.S * fm.Cx(α, q, δe, br)
	var Y = Q * fm.S * fm.Cy(α, β, p, r, δr, δa, br)
	var Z = Q * fm.S * fm.Cz(α, q, δe, br)
	
	var aero_force = basis * BODY_TO_LOCAL_TRANSF * Vector3(X, Y, Z)
	var aero_moment = basis * BODY_TO_LOCAL_TRANSF * Vector3(L, M, N)
		
	#debug_drawer.draw_line(Vector3.ZERO, aero_force / 1000, Color.RED)
	#debug_drawer.draw_line(Vector3.ZERO, aero_moment / 1000, Color.YELLOW)
	
	var from = get_parent().global_position
	debug_drawer.draw_line_global(from, from + basis * BODY_TO_LOCAL_TRANSF * Vector3.RIGHT * X * 0.001, Color.RED)
	debug_drawer.draw_line_global(from, from + basis * BODY_TO_LOCAL_TRANSF * Vector3.UP * Y * 0.001, Color.GREEN)
	debug_drawer.draw_line_global(from, from + basis * BODY_TO_LOCAL_TRANSF * Vector3.BACK * Z * 0.001, Color.BLUE)
	
	#debug_drawer.write_line("%10.5f -- %10.5f" % [rad_to_deg(α), stall_progress])
	
	#printt(Q, α, β, trim)
	#printt("=>", lerp(aero_force, stall_force, stall_progress), lerp(aero_moment, stall_moment, stall_progress))
	
	return [aero_force, aero_moment]

static func _limit(x: float, limit: Vector2) -> float:
	return lerp(limit.x, limit.y, x * 0.5 + 0.5)
