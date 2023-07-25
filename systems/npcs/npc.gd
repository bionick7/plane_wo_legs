class_name NPCPlane
extends PlaneInterface

@export var target: PlaneInterface
@export var behaviour: NPCBehaviour
@export_flags("Good Guys", "Bad Guys", "3rd Party") var hostility_flags: int

@export_group("Debug")
@export var log_summary: bool
@export var log_speed: bool
@export var draw_avoidance: bool
@export var avoidance_color: Color = Color.YELLOW
@export_placeholder("Only for reading") var _ai_text_summary: String = ""

var _next_velocity = Vector3.ZERO
var angular_velocity = Vector3.ZERO

var speed = 200 # m/s
var tgt_speed = 200  # m/s
var avoidance_point = Vector3.ZERO
var roll_speed = 0
var roll_acceleration = 0

var plane_up = Vector3.UP

var allow_fire = true

func _ready():
	super._ready()
	velocity = basis.z * speed
	if not _is_target_valid():
		_search_new_target_async()
		
func _get_hostile_planes() -> Array[PlaneInterface]:
	var res: Array[PlaneInterface] = []
	for plane in get_tree().get_nodes_in_group("Planes"):
		if plane.allegency_flags & hostility_flags == 0:
			continue
		res.append(plane)
	return res
	
func _is_target_valid() -> bool:
	return is_instance_valid(target) and _is_visible(target)
	
func _is_visible(plane: PlaneInterface) -> bool:
	if not behaviour.sees_all:
		var rel_pos = plane.global_position - global_position
		if rel_pos.length_squared() > behaviour.view_cone_angle_rad:
			return false
		if velocity.angle_to(rel_pos) > behaviour.view_cone_radius_sqr:
			return false
	if not behaviour.sees_through_clouds and plane.is_hidden():
		return false
	return true
	
func _search_new_target_async() -> void:
	while true:
		var possible_targets = _get_hostile_planes()
		if possible_targets.size() > 0:
			target = possible_targets.pick_random()
			return
		else:
			target = null
		await get_tree().create_timer(behaviour.search_interval).timeout
	
	
func update_velocity_rotation(dt: float, manual: bool) -> void:
	super.update_velocity_rotation(dt, manual)
		
	_ai_logic(dt)
	if log_summary:
		logger.write_line(name + ": " + _ai_text_summary)
		
	# Speed
	var lerp_weight = clamp((velocity / speed).dot(up_direction), 0, 1)
	var max_speed = lerp(behaviour.max_level_speed, behaviour.max_vertical_speed, lerp_weight)
	var steady_speed = clamp(tgt_speed, behaviour.stall_speed, max_speed)
	speed = clamp(speed, behaviour.stall_speed, max_speed)
	speed = move_toward(speed, steady_speed, behaviour.thrust_acceleration * dt)	
	if log_speed:
		logger.write_line("%s: %5.1f m/s -> %5.1f m/s " % [name, speed, tgt_speed])
		
	# Visuals
	if frozen and not manual:
		visual_ypr = Vector3.ZERO
		velocity = basis.z * speed
	else:
		var tgt_acc = (_next_velocity - velocity) / dt
		var load_acc = tgt_acc - common_physics.get_acc(global_position, velocity)
		
		var fore = _next_velocity.normalized()
		var next_up = angular_move_toward(plane_up, load_acc, dt * behaviour.max_roll_rate_rad).normalized()
		roll_speed = next_up.signed_angle_to(plane_up, fore) / dt
		roll_acceleration = 0  # ??? how to smooth out 
		plane_up = next_up
		
		plane_up = (plane_up - plane_up.project(fore))
		var new_basis = Basis(
			plane_up.cross(fore),
			plane_up,
			fore
		)
		# var inv_basis = basis.inverse()
		# var delta_rot = (new_basis * inv_basis).get_rotation_quaternion()
		# var new_angular_velocity: Vector3 = (delta_rot.get_angle() / dt) * delta_rot.get_axis().normalized()
		# var angular_acceleration: Vector3 = (new_angular_velocity - angular_velocity) / dt
		# if angular_acceleration.is_zero_approx():
		# 	visual_ypr = Vector3.ZERO
		# angular_velocity = new_angular_velocity
		visual_ypr = Vector3(0., load_acc.dot(plane_up) * -2e-2, roll_acceleration * 2)
		visual_throttle = speed / max_speed
		basis = new_basis
		
		velocity = _next_velocity
		
	#debug_drawer.draw_line_global(global_position, global_position + _next_velocity, Color.LIGHT_SKY_BLUE)

func _ai_logic(dt: float) -> void:
	if not _is_target_valid():
		_search_new_target_async()
	if _test_terrain_collision():
		tgt_speed = behaviour.maneuver_speed
		_exact_update_face_dir((avoidance_point - global_position).normalized(), dt)
		_ai_text_summary = "Avoid terrain"
		return
	for plane in get_tree().get_nodes_in_group("Planes"):
		if _test_plane_collision(plane):
			_avoid_plane_collision(plane, dt)
			_ai_text_summary = "Avoid plane \"%s\"" % plane.name
			return
	for plane in _get_hostile_planes():
		if _is_beeing_chased_by(plane):
			_evade_from(plane, dt)
			_ai_text_summary = "Evade plane \"%s\"" % plane.name
			return
	if _is_target_valid():
		_chase_target(dt)
		_ai_text_summary = "Chase target \"%s\"" % target.name
		return
	_idle()

func _test_terrain_collision() -> bool:
	avoidance_point = Vector3(0, 0, clamp(global_position.z, -2e3, 2e3))
	var sim_pos = global_position
	var sim_vel = velocity
	var avoidance_path = PackedVector3Array()
	var avoidance_direction = (avoidance_point - sim_pos).normalized()
	var sim_step = 0.3
	var sim_time = 0
	var sim_speed = max(speed, behaviour.maneuver_speed)
	while (sim_vel / sim_speed).dot(avoidance_direction) < cos(.01) and sim_time < 15:
		avoidance_direction = (avoidance_point - sim_pos).normalized()
		sim_vel = _step_face_direction(sim_vel / sim_speed, avoidance_direction, sim_speed, sim_step)
		sim_pos += sim_vel * sim_step
		sim_time += sim_step
		if draw_avoidance:
			avoidance_path.append(sim_pos)
		if common_physics.distance_to_bounds(sim_pos) < behaviour.crash_safety_margin:
			return true
	if draw_avoidance and avoidance_path.size() >= 2:
		debug_drawer.draw_path_global(avoidance_path, avoidance_color)
	return false
	
func _test_plane_collision(test: PlaneInterface) -> bool:
	var rel_pos = test.global_position - global_position
	var rel_vel = test.velocity - velocity
	var min_delta = rel_pos + rel_vel * max(get_closest_approach(rel_pos, rel_vel), 0)
	
	return min_delta.length_squared() < behaviour.plane_safe_radius*behaviour.plane_safe_radius
	
func _is_beeing_chased_by(test: PlaneInterface) -> bool:
	var rel_pos = test.global_position - global_position
	if velocity.angle_to(-rel_pos) > behaviour.chase_cone_angle_rad:
		return false
	if rel_pos.length_squared() > behaviour.chase_cone_radius_sqr:
		return false
	return true

func _idle() -> void:
	_next_velocity = velocity

func _evade_from(chaser: PlaneInterface, dt: float) -> void:
	var rel_pos = chaser.global_position - global_position
	tgt_speed = behaviour.max_level_speed
	_exact_update_face_dir(rel_pos.normalized(), dt)

func _avoid_plane_collision(plane: PlaneInterface, dt: float) -> void:
	var rel_pos = plane.global_position - global_position
	var rel_vel = plane.velocity - velocity
	var time_at_closest_approach = max(get_closest_approach(rel_pos, rel_vel), 0)
	var plane_pos = plane.global_position + plane.velocity * time_at_closest_approach
	var self_pos = global_position + velocity * time_at_closest_approach
	
	var vel_dir = velocity / speed
	var evasion_delta = (plane_pos - self_pos).project(vel_dir) - (plane_pos - self_pos)
	if evasion_delta.is_zero_approx():
		evasion_delta = Vector3.UP - Vector3.UP.project(vel_dir)  # breaks if vel_dir and plane dir are both up
	
	#var target_pt = self_pos + evasion_delta.normalized() * behaviour.plane_safe_radius - global_position
	var target_pt = evasion_delta.normalized() * behaviour.plane_safe_radius
	#debug_drawer.draw_line_global(global_position, global_position + target_pt, Color.SPRING_GREEN)
	_exact_update_face_dir(rel_pos.normalized(), dt)

var face_dir = Vector3.ZERO  # TODO
var face_dir_vel = Vector3.ZERO  # TODO

func _chase_target(dt: float) -> void:
	var rel_pos = target.global_position - global_position
	var rel_vel = target.velocity - velocity
	var preaim_time = preaim_simple(rel_pos, rel_vel, gun.muzzle_velocity)
	var ideal_face_dir: Vector3
	if preaim_time >= 0:
		ideal_face_dir = (rel_pos + rel_vel * preaim_time).normalized()
	else:
		# No possibility to hit target (e.g. target will outrun bullets
		ideal_face_dir = rel_pos.normalized()  # Just chase directly
	
	
	if preaim_time >= 0 and behaviour.use_gun and \
		allow_fire and face_dir.angle_to(velocity) * rel_pos.length() < behaviour.gun_shoot_distance:
		_give_burst()
	tgt_speed = max(target.velocity.length() * behaviour.speed_overshoot, behaviour.maneuver_speed)
	#debug_drawer.draw_line_global(global_position, global_position + face_dir * 10, Color.RED)
	_sloppy_update_face_dir(ideal_face_dir, dt)

func _exact_update_face_dir(ideal_face_dir: Vector3, dt: float) -> void:
	face_dir_vel = (ideal_face_dir - face_dir) / dt
	face_dir = ideal_face_dir
	face_dir_vel -= face_dir_vel.project(face_dir)
	_next_velocity = _step_face_direction(velocity / speed, face_dir, speed, dt)

func _sloppy_update_face_dir(ideal_face_dir: Vector3, dt: float) -> void:
	if not behaviour.enable_sloppy_aiming:
		_exact_update_face_dir(ideal_face_dir, dt)
		return
	var delta_fd = ideal_face_dir - face_dir
	var fd_spring_component = -delta_fd.normalized() * clamp(behaviour.sloppy_aim_stiffness * pow(delta_fd.length_squared(), behaviour.sloppy_aim_stiffness_power / 2), 0.5, 100)
	var fd_damper_component = -face_dir_vel * behaviour.sloppy_aim_damping
	var fd_noise = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * behaviour.sloppy_aim_noise_amplitude
	var fd_acceleration = fd_damper_component + fd_spring_component + fd_noise
	face_dir_vel += fd_acceleration * dt
	face_dir += face_dir_vel * dt
	face_dir = face_dir.normalized()
	face_dir_vel -= face_dir_vel.project(face_dir)
	
	_next_velocity = _step_face_direction(velocity / speed, ideal_face_dir, speed, dt)

func _step_face_direction(current_dir: Vector3, dir: Vector3, turn_speed: float, dt: float) -> Vector3:
	var acc = clamp((turn_speed*turn_speed / (behaviour.stall_speed*behaviour.stall_speed) - 1.0) * 9.81, 1, behaviour.max_acceleration)
	return angular_move_toward(current_dir, dir, acc * dt / turn_speed, up_direction) * turn_speed

func _give_burst() -> void:
	if frozen:
		return
	allow_fire = false
	gun.start_fire()
	var tween: Tween = get_tree().create_tween().bind_node(self)
	tween.tween_interval(randf_range(behaviour.gun_min_burst_length, behaviour.gun_max_burst_length))
	tween.tween_callback(gun.cease_fire)
	tween.tween_interval(behaviour.gun_cooldown)
	tween.tween_callback(func (): allow_fire = true)

static func angular_move_toward(from: Vector3, to: Vector3, delta_angle: float, fallback_axis=Vector3.UP) -> Vector3:
	var axis = from.cross(to).normalized()
	if not axis.is_normalized():  # only when from and to are roughly aligned
		axis = fallback_axis
	var angle = from.signed_angle_to(to, axis)
	if angle < delta_angle:
		return to
	return from.rotated(axis, delta_angle)

# TODO: UNTESTED!
static func preaim(pos: Vector3, vel: Vector3, muzzle_vel: float, acc: Callable) -> Vector3:
	# Returns expected time to impact and direction of aiming in *global axis system* 
	# Assuming no acceleration acts on the target
	var t = preaim_simple(pos, vel, muzzle_vel)
	var tgtpos = pos + vel * t
	var error = Vector3.ONE * 100
	var dt = 0.01
	while error.length_squared() > 1:
		var sim_pos = Vector3.ZERO
		var sim_vel = muzzle_vel * tgtpos.normalized()
		var sim_t = 0
		while sim_pos.length_squared() < (pos + vel * sim_t).length_squared():
			sim_vel += acc.call(sim_pos, sim_vel) * dt
			sim_pos += sim_vel * dt
			sim_t += dt
		error = sim_pos - (pos + vel * sim_t)
		tgtpos += error
		t = sim_t
	return t

static func preaim_simple(pos: Vector3, vel: Vector3, muzzle_vel: float) -> float:
	# Returns expected time to impact in *global axis system* 
	# Assuming no acceleration acts on the bullet or target
	if muzzle_vel <= 0 :
		push_error("Muzzleveloxity cannot be 0")
		return -1
	# Quadratic equation: (v² - w²) t² + 2vx t + x² = 0, (w is muzzlevelocity)
	var a = vel.dot(vel) - muzzle_vel*muzzle_vel
	var b = 2 * pos.dot(vel)
	var c = pos.dot(pos)
	var discr = b*b - 4*a*c
	if discr < 0:
		# Failure: no solutions
		return -1
	# Always fastest solution, since sqrt > 0 and a > 0
	var t = (-b - sqrt(discr)) / (2*a)
	if t < 0:  # Check slower solution
		t = (-b + sqrt(discr)) / (2*a)
	return t

static func get_closest_approach(pos: Vector3, vel: Vector3) -> float:
	# returns time at closest approach
	# Minimize: v² t² + 2vx t + x² = 0
	var a = vel.dot(vel)
	var b = 2 * pos.dot(vel)
	var c = pos.dot(pos)
	#2a t + b = 0
	return -b / (2*a)
