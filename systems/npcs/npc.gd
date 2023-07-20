class_name NPCPlane
extends PlaneInterface

enum State {
	DOGFIGHT,
	AVOID_COLLISION,
}

@export var target: PlaneInterface
@export var behaviour: NPCBehaviour

@export var draw_avoidance: bool
@export var avoidance_color: Color = Color.YELLOW

var _next_velocity = Vector3.ZERO

var ai_state: State = State.DOGFIGHT

var speed = 200 # m/s
var tgt_speed = 200  # m/s
var avoidance_point = Vector3.ZERO

var plane_up = Vector3.UP

var allow_fire = true

signal spawn_tracker(this: Node3D)
signal kill_tracker(this: Node3D)

func _ready():
	velocity = basis.z * speed
	emit_signal("spawn_tracker", self)

func _exit_tree():
	emit_signal("kill_tracker", self)
	
func update_velocity_rotation(dt: float, manual: bool) -> void:
	super.update_velocity_rotation(dt, manual)
		
	# Collision avoidance
	if test_avoidance():
		var avoidance_direction = (avoidance_point - global_position).normalized()
		tgt_speed = behaviour.maneuver_speed
		_next_velocity = _step_face_direction(velocity / speed, avoidance_direction, speed, dt)
	else:
		# Accomplish objective
		var rel_pos = target.global_position - global_position
		var is_chased = velocity.angle_to(rel_pos) > PI/2
		if is_chased:
			# Chased
			var face_dir = rel_pos.normalized()
			tgt_speed = behaviour.maneuver_speed
			_next_velocity = _step_face_direction(velocity / speed, face_dir, speed, dt)
		else:
			# Chasing
			var rel_vel = target.velocity - velocity
			var preaim_time = preaim_simple(rel_pos, rel_vel, gun.muzzle_velocity)
			var face_dir = (rel_pos + rel_vel * preaim_time).normalized()
			if behaviour.use_gun and allow_fire and face_dir.angle_to(velocity) * rel_pos.length() < behaviour.gun_shoot_distance:
				_give_burst()
			tgt_speed = target.velocity.length() * behaviour.speed_overshoot
			_next_velocity = _step_face_direction(velocity / speed, face_dir, speed, dt)
		
	# Speed
	var lerp_weight = clamp((velocity / speed).dot(up_direction), 0, 1)
	var max_speed = lerp(behaviour.max_level_speed, behaviour.max_vertical_speed, lerp_weight)
	var steady_speed = clamp(tgt_speed, behaviour.stall_speed, max_speed)
	speed = clamp(speed, behaviour.stall_speed, max_speed)
	speed = move_toward(speed, steady_speed, behaviour.thrust_acceleration * dt)
		
	# Visuals
	if not frozen or manual:
		var tgt_acc = (_next_velocity - velocity) / dt
		var load_acc = tgt_acc - common_physics.get_acc(global_position, velocity)
		plane_up = angular_move_toward(plane_up, load_acc, dt * behaviour.max_roll_rate).normalized()
		
		var fore = velocity.normalized()
		plane_up = (plane_up - plane_up.project(fore))
		basis.x = plane_up.cross(fore)
		basis.y = plane_up
		basis.z = fore
		
		velocity = _next_velocity
	else:
		velocity = basis.z * speed
		
	debug_drawer.draw_line_global(global_position, global_position + _next_velocity, Color.LIGHT_SKY_BLUE)

func test_avoidance() -> bool:
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

func _step_face_direction(current_dir: Vector3, dir: Vector3, speed: float, dt: float) -> Vector3:
	var acc = clamp((speed*speed / (behaviour.stall_speed*behaviour.stall_speed) - 1.0) * 9.81, 1, behaviour.max_acceleration)
	return angular_move_toward(current_dir, dir, acc * dt / speed, up_direction) * speed

func _give_burst():
	allow_fire = false
	gun.start_fire()
	var tween: Tween = get_tree().create_tween()
	tween.tween_interval(randf_range(behaviour.gun_min_burst_length, behaviour.gun_max_burst_length))
	tween.tween_callback(gun.cease_fire)
	tween.tween_interval(behaviour.gun_cooldown)
	tween.tween_callback(func (): allow_fire = true)

static func angular_move_toward(from: Vector3, to: Vector3, delta_angle: float, fallback_axis=Vector3.UP) -> Vector3:
	var axis = from.cross(to).normalized()
	if not axis.is_normalized():
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
	if muzzle_vel == 0 :
		push_error("Muzzleveloxity cannot be 0")
		return -1
	# Quadratic equation: (v*v - w*w) t² + 2*v*x t + x*x = 0, w is muzzlevelocity
	var a = vel.dot(vel) - muzzle_vel*muzzle_vel;
	var b = 2 * pos.dot(vel);
	var c = pos.dot(pos);
	var discr = b*b - 4*a*c;
	if discr < 0:
		# Failure: no solutions
		return -1
	# Always fastest solution, since sqrt > 0 and a > 0
	var t = (-b - sqrt(discr)) / (2*a);
	if t < 0:  # Check slower solution
		# Always slower solution
		t = (-b + sqrt(discr)) / (2*a);
	return t
