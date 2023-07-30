class_name Missile
extends PlaneInterface

enum Stage { STOWED, CRUISE, FINAL, EXPENDED }
enum AimingMethod { POINT, PREAIM, EXACT }

@export var cruise_aiming_method: AimingMethod
@export var final_aiming_method: AimingMethod
@export var dammage: int = 2
@export_range(0, 1000, 1, "or_greater", "hide_slider", "suffix:m") var transition_distance: float = 300
@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s²") var turn_acceleration: float = 80

@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s") var cruise_speed: float = 300
@export_range(0, 1000, 0.1, "or_greater", "hide_slider", "suffix:m/s") var final_speed: float = 250

var speed = 100
var tgt_speed = 100

var target: TrackingAnchor
var stage: Stage
var dist2tgt_sqr = 0

func _physics_process(dt: float):
	if stage == Stage.STOWED:
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
	if manual and stage in [Stage.STOWED, Stage.EXPENDED]:
		return
	if not is_instance_valid(target):
		stage = Stage.EXPENDED
		
	var new_dist2tgt_sqr = global_position.distance_squared_to(target.global_position)
	
	match stage:
		Stage.STOWED, Stage.EXPENDED:
			push_error("Should not reach")
		Stage.CRUISE:
			tgt_speed = cruise_speed
			_aim(cruise_aiming_method, dt)
			if dist2tgt_sqr <= transition_distance*transition_distance:
				stage = Stage.FINAL
		Stage.FINAL:
			tgt_speed = final_speed
			_aim(final_aiming_method, dt)
			
	#if new_dist2tgt_sqr > dist2tgt_sqr:
	#	stage = Stage.EXPENDED
		
	speed = move_toward(speed, tgt_speed, turn_acceleration * dt)
	

func is_ready(at: TrackingAnchor) -> bool:
	if not is_instance_valid(at):
		return false
	return true

func launch(at: TrackingAnchor, inherited_velocity: Vector3) -> void:
	target = at
	dist2tgt_sqr = global_position.distance_squared_to(target.global_position)
	top_level = true
	$Trail.is_pushing = true
	
	velocity = inherited_velocity
	speed = velocity.length()
	stage = Stage.CRUISE

func _aim(method: AimingMethod, dt: float) -> void:
	match method:
		AimingMethod.POINT:
			_face_point(target.global_position, dt)
		AimingMethod.PREAIM:
			_face_preaim(target.global_position, target.velocity, dt)
		AimingMethod.EXACT:
			_face_exact(dt)

func _face_point(tgt_pos: Vector3, dt: float):
	var dir = (tgt_pos - global_position).normalized()
	global_transform.basis = NPCUtility.basis_align(dir, Vector3.UP, true)
	#var acc = turn_acceleration
	#velocity = NPCUtility.angular_move_toward(velocity / speed, dir, acc * dt / speed) * speed
	velocity = dir * speed
	debug_drawer.draw_line_global(global_position, tgt_pos, Color.LIGHT_YELLOW)
	
func _face_preaim(tgt_pos: Vector3, tgt_vel: Vector3, dt: float):
	var rel_pos = tgt_pos - global_position
	var rel_vel = tgt_vel - velocity
	var t = max(NPCUtility.preaim_simple(rel_pos, rel_vel, speed), 0)
	_face_point(tgt_pos + tgt_vel * t, dt)
	
func _face_exact(dt: float):
	# TODO
	return
