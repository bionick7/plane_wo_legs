class_name Missile
extends PlaneInterface

enum Stage { STOWED, CRUISE, FINAL, EXPENDED }
enum AimingMethod { POINT, PREAIM, EXACT }

class FlightState:
	var speed: float = 100
	var ideal_speed: float = 100
	var target_pos: Vector3 = Vector3.ZERO
	var target_vel: Vector3 = Vector3.ZERO
	var stage: Stage = Stage.STOWED
	var dist2tgt_sqr: float = 0
	var can_track: bool = true
	
	var transform: Transform3D = Transform3D.IDENTITY
	var velocity: Vector3 = Vector3.ZERO
	
	var dt: float
	
	var position: Vector3:
		get: return transform.origin
		set(x): transform.origin = x
	
	var basis: Basis:
		get: return transform.basis
		set(x): transform.basis = x
			
	func launch(p_self: Missile, p_target: TrackingAnchor, initial_velocity: Vector3) -> void:
		transform = p_self.global_transform
		target_pos = p_target.position
		target_vel = p_target.get_velocity()
		dist2tgt_sqr = p_self.global_position.distance_squared_to(p_target.global_position)
		velocity = initial_velocity
		speed = initial_velocity.length()
		stage = Stage.CRUISE

@export var behaviour: MissileGuidanceBehaviour
@export var dammage: int = 2

var measured_velocity := Vector3.ZERO
var target: TrackingAnchor
var flight_state: FlightState

@onready var _pos := global_position

func _ready():
	flight_state = FlightState.new()
	super._ready()
	if flight_state.stage == Stage.STOWED:
		remove_from_group("Planes")

func _physics_process(dt: float):
	measured_velocity = (global_position - _pos) / dt
	_pos = global_position
	if flight_state.stage == Stage.STOWED:
		return
	super._physics_process(dt)
	
	var ss := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + velocity * dt, collision_mask, [])
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var raycast_result = ss.intersect_ray(query)
	if raycast_result:
		var collider: CollisionObject3D = raycast_result.collider
		if collider is Hitbox:
			collider.on_missile_hit(dammage, raycast_result.position, velocity)
			queue_free()

func update_velocity_rotation(dt: float, manual: bool) -> void:
	super.update_velocity_rotation(dt, manual)
	if flight_state.stage == Stage.EXPENDED:
		return
	if not is_instance_valid(target):
		flight_state.stage = Stage.EXPENDED
		_on_expended()
		return
	flight_state.dt = dt
	flight_state.transform = global_transform
	flight_state.target_pos = target.global_position
	flight_state.target_vel = target.get_velocity()
	flight_state.can_track = not target.is_hidden()
	_stage_update(flight_state, behaviour)
	if flight_state.stage == Stage.EXPENDED:
		_on_expended()
		return
	velocity = flight_state.velocity
	global_transform.basis = flight_state.basis
	
func sim_path(initial_velocity: Vector3, target: TrackingAnchor, acc: float=50.0, dt: float=0.01, log_to_table=false) -> float:
	# Assumes the target turns as a NPC does with current velocity and given acceleration
	# Returns closest distance.
	var sim_pos_missile := global_position
	var sim_pos_tgt := target.global_position
	var sim_vel_tgt := target.get_velocity()
	var sim_speed_tgt := sim_vel_tgt.length()
	var sim_time := 0.0
	var expected_time := (sim_pos_tgt - sim_pos_missile).length() /  (sim_vel_tgt - initial_velocity).project(sim_pos_tgt - sim_pos_missile).length()
	
	var closes_dst_sqr: float = 1.0/0.0
	
	var sim_state := FlightState.new()
	sim_state.launch(self, target, initial_velocity)
	sim_state.dt = dt
	while true:
		if sim_state.stage == Stage.EXPENDED:
			break
		if CommonPhysics.distance_to_bounds(sim_pos_missile) <= 0:
			break
		if sim_time > expected_time*2:
			break
		sim_pos_missile += sim_state.velocity * dt
		sim_pos_tgt += sim_vel_tgt * dt
		
		sim_state.position = sim_pos_missile
		sim_state.target_pos = sim_pos_tgt
		sim_state.target_vel = sim_vel_tgt
		_stage_update_compact(sim_state, behaviour)
		
		sim_vel_tgt = NPCUtility.angular_move_toward(
			sim_vel_tgt / sim_speed_tgt, 
			(sim_pos_missile - sim_pos_tgt).normalized(), 
			acc * dt / sim_speed_tgt, up_direction
		) * sim_speed_tgt
		if sim_state.dist2tgt_sqr < closes_dst_sqr:
			closes_dst_sqr = sim_state.dist2tgt_sqr
		sim_time += dt
		if log_to_table:
			Logger.data_table_push_row("sim_state", [
				sim_pos_missile.x, sim_pos_missile.y, sim_pos_missile.z,
				sim_state.velocity.x, sim_state.velocity.y, sim_state.velocity.z,
				sim_pos_tgt.x, sim_pos_tgt.y, sim_pos_tgt.z,
				sim_vel_tgt.x, sim_vel_tgt.y, sim_vel_tgt.z
			])
		
	if log_to_table:
		Logger.store_data_table("sim_state")
		Logger.clear_data_table("sim_state")
	return sqrt(closes_dst_sqr)

var _do_log = true
func test_sim_path(initial_velocity: Vector3, target: TrackingAnchor) -> float:
	"""
	var sim_state := FlightState.new()
	sim_state.launch(self, target, initial_velocity)
	sim_state.dt = 0.01
	
	Logger.push_timer()
	for i in range(100):
		Missile._stage_update(sim_state, behaviour)
	var time_1 = Logger.pop_timer()
	
	Logger.push_timer()
	for i in range(100):
		Missile._stage_update_compact(sim_state, target.global_position, target.get_velocity(), behaviour)
	var time_2 = Logger.pop_timer()
	print("%d µs -> %d µs" % [time_1, time_2])
	
	return 0
	"""
	Logger.push_timer()
	var x1 = sim_path(initial_velocity, target, 50, 0.01, _do_log)
	if _do_log: _do_log = false
	var time_1 = Logger.pop_timer()
	return x1

func is_ready(at: TrackingAnchor) -> bool:
	if not is_instance_valid(at):
		return false
	return true

func recommend_launch(at: TrackingAnchor, certainty_radius: float) -> bool:
	return sim_path(measured_velocity, at) < certainty_radius

func launch(at: TrackingAnchor) -> void:
	if flight_state.stage != Stage.STOWED:
		return
	top_level = true
	$Trail.is_pushing = true
	$TrackingIndicator.tracking = at
	flight_state.launch(self, at, measured_velocity)
	target = at
	velocity = measured_velocity
	add_to_group("Planes")

func _on_expended() -> void:
	$TrackingIndicator.tracking = null

# <<= ==================================== =>>
# 				STAGE FUNCTIONS
# <<= ==================================== =>>
func __STAGE_FUNCTIONS__(): pass

static func _stage_update_compact(state: FlightState, behaviour: MissileGuidanceBehaviour) -> void:
	var rel_pos := state.target_pos - state.position
	var rel_vel := state.target_vel - state.velocity
	
	if state.stage in [Stage.STOWED, Stage.EXPENDED]:
		return

	state.dist2tgt_sqr = rel_pos.length_squared()
	
	if rel_pos.angle_to(state.velocity) > behaviour.view_cone:
		state.stage = Stage.EXPENDED
		return

	var t = max(NPCUtility.preaim_simple(rel_pos, rel_vel, state.speed), 0)
	var dir = (rel_pos + state.target_vel * t).normalized()
	#var ang_step = behaviour.angular_velocity * state.dt
	var ang_step = behaviour.angular_acceleration / state.speed * state.dt
	state.velocity = NPCUtility.angular_move_toward(state.velocity / state.speed, dir, ang_step) * state.speed
	
	state.ideal_speed = behaviour.cruise_speed
	state.speed = move_toward(state.speed, state.ideal_speed, behaviour.acceleration * state.dt)


static func _stage_update(state: FlightState, behaviour: MissileGuidanceBehaviour) -> void:
	if state.stage in [Stage.STOWED, Stage.EXPENDED]:
		return
	
	var new_dist2tgt_sqr = state.position.distance_squared_to(state.target_pos)
	state.dist2tgt_sqr = new_dist2tgt_sqr
	
	match state.stage:
		Stage.STOWED, Stage.EXPENDED:
			push_error("Should not reach")
		Stage.CRUISE:
			state.ideal_speed = behaviour.cruise_speed
			_aim(behaviour.cruise_aiming_method, behaviour, state)
			if state.dist2tgt_sqr <= behaviour.transition_distance*behaviour.transition_distance:
				state.stage = Stage.FINAL
		Stage.FINAL:
			state.ideal_speed = behaviour.final_speed
			_aim(behaviour.final_aiming_method, behaviour, state)
			
	#if new_dist2tgt_sqr > dist2tgt_sqr:
	#	stage = Stage.EXPENDED
		
	state.speed = move_toward(state.speed, state.ideal_speed, behaviour.acceleration * state.dt)


static func _aim(method: AimingMethod, behaviour: MissileGuidanceBehaviour, state: FlightState) -> void:
	if not state.can_track:
		return
	
	if (state.target_pos - state.position).angle_to(state.basis.z) > behaviour.view_cone:
		state.stage = Stage.EXPENDED
		#prints(name, "Missed its target")
		return
	
	match method:
		AimingMethod.POINT:
			_face_point(state.target_pos, state, behaviour)
		AimingMethod.PREAIM:
			_face_preaim(state, behaviour)
		AimingMethod.EXACT:
			_face_exact(state)

static func _face_point(tgt_pos: Vector3, state: FlightState, behaviour: MissileGuidanceBehaviour):
	var dir := (tgt_pos - state.position).normalized()
	state.basis = NPCUtility.basis_align(dir, Vector3.UP, true)
	#var ang_step = behaviour.angular_velocity * state.dt
	var ang_step = behaviour.angular_acceleration / state.speed * state.dt
	state.velocity = NPCUtility.angular_move_toward(state.velocity / state.speed, dir, ang_step) * state.speed
	
static func _face_preaim(state: FlightState, behaviour: MissileGuidanceBehaviour):
	var rel_pos := state.target_pos - state.position
	var rel_vel := state.target_vel - state.velocity
	var t: float = max(NPCUtility.preaim_simple(rel_pos, rel_vel, state.speed), 0.0)
	_face_point(state.target_pos + state.target_vel * t, state, behaviour)
	
static func _face_exact(state: FlightState):
	# TODO
	return
