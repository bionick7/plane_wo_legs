class_name  NPCUtility
extends Node

static func angular_move_toward(from: Vector3, to: Vector3, delta_angle: float, fallback_axis=Vector3.UP) -> Vector3:
	var axis = from.cross(to).normalized()
	if not axis.is_normalized():  # only when from and to are roughly aligned
		axis = fallback_axis
	var angle = from.signed_angle_to(to, axis)
	if angle < delta_angle:
		return to
	return from.rotated(axis, delta_angle)

static func basis_align(x: Vector3, up: Vector3, align_z: bool=false) -> Basis:
	assert(x.is_normalized())
	assert(up.is_normalized())
	if is_equal_approx(abs(x.dot(up)), 1.0):
		up = Vector3.UP if x.y < 0.5 else Vector3.RIGHT
	up = (up - up.dot(x) * x).normalized()
	if align_z:
		return Basis(up.cross(x), up, x)
	return Basis(x, up, x.cross(up))

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
	if is_zero_approx(a):
		# bx + c = 0 <=> x = -c / b
		return -c / b
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
	if vel.is_zero_approx():
		return 0  # covers for a = 0
	var a = vel.dot(vel)
	var b = 2 * pos.dot(vel)
	var c = pos.dot(pos)
	#2a t + b = 0
	return -b / (2*a)
