@tool
class_name ProcAnim2Order
extends Resource

@export var enabled: bool
@export var keep_normalized: bool

@export_group("Parameters")
@export_range(0, 1, 0.001, "or_greater", "hide_slider") var frequency: float = 1
@export var damping_ratio: float = 1
@export var r: float = 2
@export_range(0, 1, 0.001, "or_greater", "hide_slider") var noise: float
@export_range(0, 1, 0.001, "or_greater", "hide_slider") var delta_limit: float = 0.1

@export_group("Step Response (Inspection Only)")
@export var step_response_time: float = 1
@export var generate_step_response: bool:
	set(x):
		_update_step_response()
@export var step_respones_output: Curve

var stiffness = 0
var damping_y = 0
var damping_x = 0
var noise_amplitude = 0
var dt_crit = 1

var y = Vector3.ZERO
var dydt = Vector3.ZERO
var x = Vector3.ZERO
var dxdt = Vector3.ZERO

func force_update(_x: Vector3, dt: float) -> Vector3:
	dxdt = (_x - x) / dt
	x = _x
	y = x
	if keep_normalized:
		y = y.normalized()
	dydt = dxdt
	if keep_normalized and not is_zero_approx(dydt.dot(y)):
		dydt -= dydt.project(y)
	return y

func update(_x: Vector3, dt: float) -> Vector3:
	if not enabled:
		return force_update(_x, dt)
	if dt < dt_crit:
		return _anim_update(_x, dt)
	var steps = ceili(dt / dt_crit)
	for i in range(steps):
		_anim_update(_x, dt / steps)
	return y
	
func _anim_update(_x: Vector3, dt: float) -> Vector3:
	dxdt = (_x - x) / dt
	x = _x
	
	y += dydt * dt
	if keep_normalized:
		y = y.normalized()
	
	var d2ydt2 = (x - y).limit_length(delta_limit) * stiffness -dydt * damping_y -dxdt * damping_x
	d2ydt2 += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * noise_amplitude
	dydt += d2ydt2 * dt
	if keep_normalized and not is_zero_approx(dydt.dot(y)):
		dydt -= dydt.project(y)
	return y

func initialize_to(y0: Vector3, dydt0: Vector3) -> void:
	stiffness = (TAU*frequency)**2
	damping_y = 2 * damping_ratio * PI * frequency
	damping_x = -r * damping_ratio * PI * frequency
	noise_amplitude = noise
	
	y = y0
	dydt = dydt0
	x = Vector3.ZERO
	dxdt = Vector3.ZERO
	
	var k2 = 1 / stiffness
	var k1 = damping_y / stiffness
	dt_crit = sqrt(4 * k2 + k1*k1) - k1

func _update_step_response() -> void:
	if not Engine.is_editor_hint():
		return
	var _keep_normalized = keep_normalized
	keep_normalized = false
	initialize_to(y, dydt)
	print("dt_crit = %f s" % dt_crit)
	if not is_instance_valid(step_respones_output):
		step_respones_output = Curve.new()
		step_respones_output.min_value = 0
		step_respones_output.max_value = 2
	else:
		step_respones_output.clear_points()
	step_respones_output.add_point(Vector2(0, y.x))
	for i in range(50):
		var dt = step_response_time / 50
		if i < 3:
			update(Vector3.ZERO, dt)
		else:
			update(Vector3.ONE, dt)
		step_respones_output.add_point(Vector2(i / 50.0, y.x))
	step_respones_output.bake()
	keep_normalized = _keep_normalized
