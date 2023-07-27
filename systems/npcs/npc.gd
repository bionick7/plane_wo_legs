class_name NPCPlane
extends PlaneInterface

@export var target: TrackingAnchor
@export var behaviour: PlaneBehaviour
@export var aim_dynamics: ProcAnim2Order
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
		
	aim_dynamics.initialize_to(basis.z, Vector3.ZERO)
	
func update_velocity_rotation(dt: float, manual: bool) -> void:
	super.update_velocity_rotation(dt, manual)
		
	_ai_logic(dt)
	if log_summary:
		Logger.write_line(name + ": " + _ai_text_summary)
		
	# Speed
	var lerp_weight = clamp((velocity / speed).dot(up_direction), 0, 1)
	var max_speed = lerp(behaviour.max_level_speed, behaviour.max_vertical_speed, lerp_weight)
	var steady_speed = clamp(tgt_speed, behaviour.stall_speed, max_speed)
	speed = clamp(speed, behaviour.stall_speed, max_speed)
	speed = move_toward(speed, steady_speed, behaviour.thrust_acceleration * dt)	
	if log_speed:
		Logger.write_line("%s: %5.1f m/s -> %5.1f m/s " % [name, speed, tgt_speed])
		
	# Visuals
	if frozen and not manual:
		visual_ypr = Vector3.ZERO
		velocity = basis.z * speed
		return
		
	var tgt_acc = (_next_velocity - velocity) / dt
	var load_acc = tgt_acc - CommonPhysics.get_acc(global_position, velocity)
	
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
	
	visual_ypr = Vector3(0., load_acc.dot(plane_up) * -2e-2, roll_acceleration * 2)
	visual_throttle = speed / max_speed
	basis = new_basis
	
	velocity = _next_velocity

# <<= ==================================== =>>
# 				DECISION TREE
# <<= ==================================== =>>
func __DECISION_TREE__(): pass

func _ai_logic(dt: float) -> void:
	if not _is_target_valid():
		_search_new_target_async()
	if _test_terrain_collision():
		tgt_speed = behaviour.maneuver_speed
		_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.force_update((avoidance_point - global_position).normalized(), dt), speed, dt)
		_ai_text_summary = "Avoid terrain"
		return
	# Find most relevant plane-to-plane collision
	var max_collision_relevance = 0.0
	var max_collision_relevance_plane = null
	for plane in get_tree().get_nodes_in_group("Planes"):
		var collision_relevance = _get_collision_relevance(plane)
		if collision_relevance > max_collision_relevance:
			max_collision_relevance = collision_relevance
			max_collision_relevance_plane = plane
	# Evade, if any is found
	if max_collision_relevance_plane != null:
		_avoid_plane_collision(max_collision_relevance_plane, dt)
		_ai_text_summary = "Avoid plane \"%s\"" % max_collision_relevance_plane.name
		return
	for plane in _get_hostile_planes():
		if _is_beeing_chased_by(plane):
			_evade_from(plane, dt)
			_ai_text_summary = "Evade plane \"%s\"" % plane.name
			return
	if _is_target_valid():
		_chase_target(dt)
		_ai_text_summary = "Chase target \"%s\"" % target.ref.name
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
		if CommonPhysics.distance_to_bounds(sim_pos) < behaviour.crash_safety_margin:
			return true
	if draw_avoidance and avoidance_path.size() >= 2:
		debug_drawer.draw_path_global(avoidance_path, avoidance_color)
	return false
	
func _get_collision_relevance(test: PlaneInterface) -> float:
	# Negative means not worth evading
	# 1 is exact collision
	var rel_pos = test.global_position - global_position
	var rel_vel = test.velocity - velocity
	var min_delta = rel_pos + rel_vel * max(get_closest_approach(rel_pos, rel_vel), 0)
	
	return 1 - min_delta.length() / behaviour.plane_safe_radius
	
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
	_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.force_update(rel_pos.normalized(), dt), speed, dt)

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
	
	debug_drawer.draw_line_global(global_position, global_position + target_pt, Color.PINK)
	debug_drawer.draw_line_global(global_position, plane.global_position, Color.DEEP_PINK)
	_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.force_update(target_pt.normalized(), dt), speed, dt)

func _chase_target(dt: float) -> void:
	var rel_pos = target.global_position - global_position
	var rel_vel = target.get_velocity() - velocity
	var preaim_time = preaim_simple(rel_pos, rel_vel, gun.muzzle_velocity)
	var ideal_face_dir: Vector3
	if preaim_time >= 0:
		ideal_face_dir = lerp(rel_pos, rel_pos + rel_vel * preaim_time, behaviour.gun_preaim_factor).normalized()
	else:
		# No possibility to hit target (e.g. target will outrun bullets)
		ideal_face_dir = rel_pos.normalized()  # Just chase directly
	
	var deviation = ideal_face_dir.angle_to(velocity) * rel_pos.length()
	if preaim_time >= 0 and behaviour.use_gun and allow_fire and deviation < behaviour.gun_shoot_delta and rel_pos.length() < behaviour.gun_shoot_distance:
		_give_burst()
	tgt_speed = max(target.get_velocity().length() * behaviour.speed_overshoot, behaviour.maneuver_speed)
	# debug_drawer.draw_line_global(global_position, global_position + aim_dynamics.y * 10, Color.RED)
	# debug_drawer.draw_line_global(global_position + aim_dynamics.y * 10, global_position + aim_dynamics.y * 10 + aim_dynamics.dydt * 10, Color.RED)
	# debug_drawer.draw_line_global(global_position, global_position + aim_dynamics.x * 10, Color.ORANGE)
	# debug_drawer.draw_line_global(global_position + aim_dynamics.x * 10, global_position + aim_dynamics.x * 10 + aim_dynamics.dxdt * 10, Color.ORANGE)
	_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.update(ideal_face_dir, dt), speed, dt)

# <<= ==================================== =>>
# 				HELPER FUNCTIONS
# <<= ==================================== =>>
func __HELPER_FUNCTIONS__(): pass

func _step_face_direction(current_dir: Vector3, dir: Vector3, turn_speed: float, dt: float) -> Vector3:
	var acc = clamp((turn_speed*turn_speed / (behaviour.stall_speed*behaviour.stall_speed) - 1.0) * 9.81, 1, behaviour.max_acceleration)
	return angular_move_toward(current_dir, dir, acc * dt / turn_speed, up_direction) * turn_speed

func _get_possible_targets() -> Array[TrackingAnchor]:
	var res: Array[TrackingAnchor] = []
	for anchor in get_tree().get_nodes_in_group("TrackingAnchors"):
		if anchor.allegency_flags & hostility_flags == 0:
			continue
		res.append(anchor)
	return res

func _get_hostile_planes() -> Array[PlaneInterface]:
	var res: Array[PlaneInterface] = []
	for anchor in get_tree().get_nodes_in_group("TrackingAnchors"):
		if not anchor.refers_plane():
			continue
		if anchor.allegency_flags & hostility_flags == 0:
			continue
		res.append(anchor.ref)
	return res
	
func _is_target_valid() -> bool:
	return is_instance_valid(target) and _is_visible(target)

func _is_visible(tgt: TrackingAnchor) -> bool:
	if not behaviour.sees_all:
		var rel_pos = tgt.global_position - global_position
		if rel_pos.length_squared() > behaviour.view_cone_angle_rad:
			return false
		if velocity.angle_to(rel_pos) > behaviour.view_cone_radius_sqr:
			return false
	if not behaviour.sees_through_clouds and tgt.is_hidden():
		return false
	return true
	
# <<= ==================================== =>>
# 				ACTIONS / ANIMATIONS
# <<= ==================================== =>>
func __ACTIONS_ANIMATIONS__(): pass

func _search_new_target_async() -> void:
	while true:
		var possible_targets = _get_possible_targets()
		if possible_targets.size() > 0:
			target = possible_targets.pick_random()
			return
		else:
			target = null
		await get_tree().create_timer(behaviour.search_interval).timeout
		
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

# <<= ==================================== =>>
# 				COMMON FUNCTIONS
# <<= ==================================== =>>
func __COMMON_FUNCTIONS__(): pass

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
