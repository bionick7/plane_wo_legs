extends Resource
class_name BlackoutCurve

enum Axis {
	PARRALELL_PLUS,
	PARRALELL_MINUS,
	TRANSVERSE,
	LATERAL,
}

@export_group("Paralell +")
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_plus_at_100ms
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_plus_at_1s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_plus_at_3s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_plus_at_10s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_plus_minimum

@export_group("Paralell -")
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_minus_at_100ms
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_minus_at_1s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_minus_at_3s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_minus_at_10s
@export_range(0.0, 40.0, 0.01, "suffix:G") var paralell_minus_minimum

@export_group("Transverse")
@export_range(0.0, 40.0, 0.01, "suffix:G") var transverse_at_100ms
@export_range(0.0, 40.0, 0.01, "suffix:G") var transverse_at_1s
@export_range(0.0, 40.0, 0.01, "suffix:G") var transverse_at_3s
@export_range(0.0, 40.0, 0.01, "suffix:G") var transverse_at_10s
@export_range(0.0, 40.0, 0.01, "suffix:G") var transverse_minimum

@export_group("Lateral")
@export_range(0.0, 40.0, 0.01, "suffix:G") var lateral_at_100ms
@export_range(0.0, 40.0, 0.01, "suffix:G") var lateral_at_1s
@export_range(0.0, 40.0, 0.01, "suffix:G") var lateral_at_3s
@export_range(0.0, 40.0, 0.01, "suffix:G") var lateral_at_10s
@export_range(0.0, 40.0, 0.01, "suffix:G") var lateral_minimum

const TIME_WINDOWS = [0.1, 1.0, 3.0, 10.0]
var avgerages = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
var g_factor = Vector4.ZERO
var indecies = PackedInt32Array([0, 0, 0, 0])

var current_time: float = 0

var impulse_arr = PackedVector3Array()
var time_arr = PackedFloat64Array()

func push_acceleration(acc: Vector3, dt: float) -> void:
	current_time += dt
	var impulse = acc * dt
	impulse_arr.append(impulse)
	time_arr.append(current_time)
	
	g_factor = Vector4.ZERO
	
	for time_window in range(4):
		avgerages[time_window] += impulse
		var next_idx = time_arr.bsearch(current_time - TIME_WINDOWS[time_window]) + 1
		for i in range(indecies[time_window], next_idx):
			avgerages[time_window] -= impulse_arr[i]
		indecies[time_window] = next_idx
	
		var g_loads = Vector4(
			abs(avgerages[time_window].x) / (TIME_WINDOWS[time_window] * 9.81),
			max(avgerages[time_window].y, 0) / (TIME_WINDOWS[time_window] * 9.81),
			max(-avgerages[time_window].y, 0) / (TIME_WINDOWS[time_window] * 9.81),
			abs(avgerages[time_window].z) / (TIME_WINDOWS[time_window] * 9.81)
		)
		var local_g_factor: Vector4 = g_loads / _limit_acc(time_window)
		g_factor = Vector4(
			max(local_g_factor.x, g_factor.x),
			max(local_g_factor.y, g_factor.y),
			max(local_g_factor.z, g_factor.z),
			max(local_g_factor.w, g_factor.w),
		)
		
	# cut out junk we don't need out of the array
	if time_arr[0] - current_time > 20:
		var clean_index = time_arr.bsearch(current_time - 10)
		impulse_arr = impulse_arr.slice(clean_index)
		time_arr = time_arr.slice(clean_index)
		for time_window in range(4):
			indecies[time_window] -= clean_index
	
func get_greyout() -> float:
	var g_max = g_factor[g_factor.max_axis_index()]
	return smoothstep(0.6, 0.9, g_max)
	
func get_blackout() -> float:
	var g_max = max(g_factor.x, g_factor.y, g_factor.z)
	return smoothstep(0.8, 1.0,g_max)
	
func get_redout() -> float:
	var g_max = g_factor.z
	return smoothstep(0.4, 1.0, g_max)
	
func get_tunnel() -> float:
	var g_max = max(g_factor.y, g_factor.z)
	return smoothstep(0.7, 0.95, g_max)
	
func get_control() -> float:
	var g_max = g_factor[g_factor.max_axis_index()]
	return smoothstep(1.1, 0.5, g_max)
	
func _limit_acc(time_window: int) -> Vector4:
	match time_window:
		0:
			return Vector4(
				lateral_at_100ms,
				paralell_plus_at_100ms,
				paralell_minus_at_100ms,
				transverse_at_100ms)
		1:
			return Vector4(
				lateral_at_1s,
				paralell_plus_at_1s,
				paralell_minus_at_1s,
				transverse_at_1s)
		2:
			return Vector4(
				lateral_at_3s,
				paralell_plus_at_3s,
				paralell_minus_at_3s,
				transverse_at_3s)
		3:
			return Vector4(
				lateral_at_10s,
				paralell_plus_at_10s,
				paralell_minus_at_10s,
				transverse_at_10s)
	return Vector4.ZERO
	
"""
func get_g_limit(axis: Axis, time: float) -> float:
	match axis:
		Axis.PARRALELL_PLUS:
			return _get_g_limit_from_points(
				paralell_plus_at_100ms,
				paralell_plus_at_1s,
				paralell_plus_at_3s,
				paralell_plus_at_10s,
				paralell_plus_minimum,
				time)
		Axis.PARRALELL_MINUS:
			return _get_g_limit_from_points(
				paralell_minus_at_100ms,
				paralell_minus_at_1s,
				paralell_minus_at_3s,
				paralell_minus_at_10s,
				paralell_minus_minimum,
				time)
		Axis.TRANSVERSE:
			return _get_g_limit_from_points(
				transverse_at_100ms,
				transverse_at_1s,
				transverse_at_3s,
				transverse_at_10s,
				transverse_minimum,
				time)
		Axis.LATERAL:
			return _get_g_limit_from_points(
				lateral_at_100ms,
				lateral_at_1s,
				lateral_at_3s,
				lateral_at_10s,
				lateral_minimum,
				time)
	return 1
	

func _get_g_limit_from_points(p_100ms: float, p_1s: float, p_3s: float, p_10s: float, p_inf: float, time: float) -> float:
	if time < 0.1: return p_100ms
	if time < p_1s: return _log_lerp(.1, 1, p_100ms, p_1s, time)
	if time < p_3s: return _log_lerp(1, 3, p_1s, p_3s, time)
	if time < p_10s: return _log_lerp(3, 10, p_3s, p_10s, time)
	return _log_lerp(10, 1000, p_10s, p_inf, clamp(time, 0, 1000))
	
func _log_lerp(x1: float, x2: float, y1: float, y2: float, x: float) -> float:
	var a = (y1 - y2) / log(x1 / x2)
	var b = y1 - a * log(x1)
	return a * log(x) + b
"""
	
func test() -> void:
	var t0 = Time.get_ticks_usec()
	for i in range(2050):
		var acc = Vector3.ONE * sin(i * .01)
		push_acceleration(acc, .01)
	var dt = (Time.get_ticks_usec() - t0) / 2050
	print("average acc push: %f µs" % dt)
	var t_end = 2049 * .01
	printt(avgerages[0].x, -cos(t_end) + cos(t_end - .1))
	printt(avgerages[1].x, -cos(t_end) + cos(t_end - 1.))
	printt(avgerages[2].x, -cos(t_end) + cos(t_end - 3.))
	printt(avgerages[3].x, -cos(t_end) + cos(t_end - 10.))
