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
@export var avoidance_color := Color.YELLOW
@export_placeholder("Only for reading") var _ai_text_summary := ""

@export_group("References")
@export var missile_launcher: MissileLauncher

var _next_velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO

var speed := 200.0  # m/s
var tgt_speed := 200.0  # m/s
var avoidance_point := Vector3.ZERO
var roll_speed := 0.0
var roll_acceleration := 0.0

var plane_up := Vector3.UP

var allow_fire := true
var allow_missile := true

func _ready():
	super._ready()
	velocity = basis.z * speed
	#missile_launcher.missile_cooldown = behaviour.missile_cooldown
		
	if not _is_target_valid():
		_search_new_target_async()
		
	aim_dynamics.initialize_to(basis.z, Vector3.ZERO)
	
func update_velocity_rotation(dt: float, manual: bool) -> void:
	super.update_velocity_rotation(dt, manual)
		
	_ai_logic(dt)
	missile_launcher.update(target)
	
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
	var next_up = NPCUtility.angular_move_toward(plane_up, load_acc, dt * behaviour.max_roll_rate).normalized()
	roll_speed = next_up.signed_angle_to(plane_up, fore) / dt
	roll_acceleration = 0  # ??? how to smooth out 
	plane_up = next_up
	
	plane_up = (plane_up - plane_up.project(fore))
	var new_basis = Basis(
		plane_up.cross(fore),
		plane_up,
		fore
	)
	assert(new_basis.is_finite())
	
	visual_ypr = Vector3(0., load_acc.dot(plane_up) * -2e-2, roll_acceleration * 2)
	visual_throttle = speed / max_speed
	basis = new_basis
	
	velocity = _next_velocity

# <<= ==================================== =>>
# 				DECISION TREE
# <<= ==================================== =>>
func __DECISION_TREE__(): pass

func _ai_logic(dt: float) -> void:
	_ai_text_summary = "UNSET"
	if not _is_target_valid():
		_search_new_target_async()
	if _test_terrain_collision():
		tgt_speed = behaviour.maneuver_speed
		_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.force_update((avoidance_point - global_position).normalized(), dt), speed, dt)
		_ai_text_summary = "Avoid terrain"
		return
		
	var max_collision_relevance := 0.0
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
		
	var max_chase_relevance := 0.0
	var max_chase_relevance_plane = null
	for plane in get_tree().get_nodes_in_group("Planes"):
		var chase_relevance = _get_chasing_relevance(plane)
		if chase_relevance > max_chase_relevance:
			max_chase_relevance = chase_relevance
			max_chase_relevance_plane = plane
	# Evade, if any is found
	if max_chase_relevance_plane != null:
		_evade_from(max_chase_relevance_plane, dt)
		_ai_text_summary = "Evade plane \"%s\"" % max_chase_relevance_plane.name
		return

	if _is_target_valid():
		_chase_target(dt)
		_ai_text_summary = "Chase target \"%s\"" % target.ref.name
		return
	_ai_text_summary = "idle"
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
	if test == self:
		return -1e6
	# Negative means not worth evading
	# 1 is exact collision
	var rel_pos = test.global_position - global_position
	var rel_vel = test.velocity - velocity
	var min_delta = rel_pos + rel_vel * max(NPCUtility.get_closest_approach(rel_pos, rel_vel), 0)
	#printt(test, rel_pos, rel_vel, NPCUtility.get_closest_approach(rel_pos, rel_vel))
	
	return 1 - min_delta.length() / behaviour.plane_safe_radius
	
func _get_chasing_relevance(test: PlaneInterface) -> float:
	if test == self:
		return -1e6
	var rel_pos = test.global_position - global_position
	var angle_based = 1 - velocity.angle_to(-rel_pos) / behaviour.chase_cone_angle
	var pos_based = 1 - rel_pos.length_squared() / behaviour.chase_cone_radius_sqr
	var res = angle_based * pos_based
	if test is Missile:
		res *= 2
	return res

func _idle() -> void:
	_next_velocity = velocity

func _evade_from(chaser: PlaneInterface, dt: float) -> void:
	var rel_pos = chaser.global_position - global_position
	tgt_speed = behaviour.max_level_speed
	_next_velocity = _step_face_direction(velocity / speed, aim_dynamics.force_update(rel_pos.normalized(), dt), speed, dt)

func _avoid_plane_collision(plane: PlaneInterface, dt: float) -> void:
	var rel_pos = plane.global_position - global_position
	var rel_vel = plane.velocity - velocity
	var time_at_closest_approach = max(NPCUtility.get_closest_approach(rel_pos, rel_vel), 0)
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
	var preaim_time = NPCUtility.preaim_simple(rel_pos, rel_vel, gun.muzzle_velocity)
	var ideal_face_dir: Vector3
	if preaim_time >= 0:
		ideal_face_dir = lerp(rel_pos, rel_pos + rel_vel * preaim_time, behaviour.gun_preaim_factor).normalized()
	else:
		# No possibility to hit target (e.g. target will outrun bullets)
		ideal_face_dir = rel_pos.normalized()  # Just chase directly
	
	var deviation = ideal_face_dir.angle_to(velocity) * rel_pos.length()
	if preaim_time >= 0 and behaviour.use_gun and allow_fire and deviation < behaviour.gun_shoot_delta and rel_pos.length() < behaviour.gun_shoot_distance:
		_give_burst()
		
	var missile = missile_launcher.get_next_missile()
	if is_instance_valid(missile) and not frozen:
		if preaim_time >= 0 and missile_launcher.recommend_launch(missile):
			missile_launcher.launch(missile)
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
	var res = NPCUtility.angular_move_toward(current_dir, dir, acc * dt / turn_speed, up_direction) * turn_speed
	assert(not res.is_zero_approx() and res.is_finite())
	return res

func _get_possible_targets() -> Array[TrackingAnchor]:
	var res: Array[TrackingAnchor] = []
	for anchor in get_tree().get_nodes_in_group("TrackingAnchors"):
		if anchor.allegency_flags & hostility_flags == 0:
			continue
		if (anchor.target_flags & TrackingAnchor.TGT_FLAGS.NPC_CAN_TARGET) == 0:
			continue
		res.append(anchor)
	return res

func _get_hostile_planes() -> Array[PlaneInterface]:
	return _get_possible_targets().filter(
		func(x): return x.refers_plane()
	).map(
		func(x): return x.ref
	)
	
func _is_target_valid() -> bool:
	return is_instance_valid(target) and _is_visible(target)

func _is_visible(tgt: TrackingAnchor) -> bool:
	if not behaviour.sees_all:
		var rel_pos = tgt.global_position - global_position
		if rel_pos.length_squared() > behaviour.view_cone_angle:
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
