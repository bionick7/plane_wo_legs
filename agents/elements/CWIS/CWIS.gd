class_name CWIS
extends Element

@export_flags("Good Guys", "Bad Guys", "3rd Party") var hostility_flags
@export_placeholder("Only for reading") var _ai_text_summary: String = ""

@export_range(-90.0, 90.0, 0.1, "suffix:°") var min_elevation = 0.0
@export_range(-90.0, 90.0, 0.1, "suffix:°") var max_elevation = 90.0
@export_range(-360.0, 360.0, 0.1, "suffix:°") var min_transverse = -180.0
@export_range(-360.0, 360.0, 0.1, "suffix:°") var max_transverse = 180.0

@export var behaviour: ShooterBehavior
@export var turret: Node3D
@export var barrel_paths: Array[NodePath]
@export var gun: Gun
@export var aim_dynamics: ProcAnim2Order

@onready var debug_drawer = $DebugDrawer
@onready var barrels = barrel_paths.map(get_node)

var target: TrackingAnchor

var is_searching: bool = false

var velocity = Vector3.ZERO
var _pos = Vector3.ZERO

func _ready():
	#super._ready()
	assert(not barrels.is_empty(), "barrel array empty in %s" % get_path())
	#assert(barrels.all(func (x): is_instance_of(x, Node3D)), "barrels are not 3D nodes is %s" % get_path())
	aim_dynamics.initialize_to(_get_real_point_dir(), Vector3.ZERO)
	
	_pos = global_position
	
	if not _is_target_valid():
		_search_new_target_async()

func _physics_process(dt: float):
	velocity = (global_position - _pos) / dt
	_pos = global_position
	
	_ai_logic(dt)

func _get_possible_targets() -> Array[TrackingAnchor]:
	var res: Array[TrackingAnchor] = []
	for anchor in get_tree().get_nodes_in_group("TrackingAnchors"):
		if anchor.allegency_flags & hostility_flags == 0:
			continue
		res.append(anchor)
	return res

func _is_target_valid() -> bool:
	return is_instance_valid(target) and _is_visible(target)

func _is_visible(tgt: TrackingAnchor) -> bool:
	if not behaviour.sees_all:
		var rel_pos = tgt.global_position - global_position
	if not behaviour.sees_through_clouds and tgt.is_hidden():
		return false
	return true
	
func _search_new_target_async() -> void:
	is_searching = true
	while true:
		var possible_targets = _get_possible_targets()
		if possible_targets.size() > 0:
			target = possible_targets.pick_random()
			is_searching = false
			return
		else:
			target = null
		await get_tree().create_timer(behaviour.search_interval).timeout

func _ai_logic(dt: float) -> void:
	if not _is_target_valid() and not is_searching:
		_search_new_target_async()
	if _is_target_valid():
		var rel_pos = target.global_position - global_position
		var rel_vel = target.velocity - velocity
		var preaim_time = NPCPlane.preaim_simple(rel_pos, rel_vel, gun.muzzle_velocity)
		var ideal_aim = lerp(rel_pos, rel_pos + rel_vel * preaim_time, behaviour.gun_preaim_factor).normalized()
		var aim = aim_dynamics.update(ideal_aim, dt)
		var free_aim = _aim_turret(aim)
		var deviation = ideal_aim.angle_to(_get_real_point_dir()) * rel_pos.length()
		var on_target = free_aim and preaim_time > 0 and behaviour.use_gun and deviation < behaviour.gun_shoot_delta and rel_pos.length() < behaviour.gun_shoot_distance
		if on_target and not gun.emitting:
			gun.start_fire()
		if gun.emitting and not on_target:
			gun.cease_fire()
		_ai_text_summary = "Chase target \"%s\"" % target.ref.name
		debug_drawer.draw_line_global(global_position, global_position + ideal_aim * 50, Color.RED)
		debug_drawer.draw_line_global(global_position, global_position + aim * 50, Color.ORANGE)
		return

func _aim_turret(dir: Vector3, test: bool = false) -> bool:
	var r = _cartesian2spherical(dir)
	
	if r.x < deg_to_rad(min_elevation) || r.x > deg_to_rad(max_elevation):
		return false
	
	if not test:
		_set_elevation_transverse(r.x, r.y)
	return true

func _shperical2cartesian(transverse: float, elevation: float) -> Vector3:
	return Vector3(
		cos(transverse) * cos(elevation), 
		sin(elevation), 
		sin(transverse) * cos(elevation)
	)
	
func _cartesian2spherical(dir: Vector3) -> Vector2:
	dir = dir.normalized()
	var turret_up = _up()
	var turret_looking = (dir - dir.project(turret_up)).normalized()
	var turret_side = turret_up.cross(turret_looking)
	
	var barrel_side = turret_side
	var barrel_up = dir.cross(barrel_side).normalized()
	
	var elevation = dir.signed_angle_to(turret_looking, turret_side)
	var true_elevation = clamp(elevation, deg_to_rad(min_elevation), deg_to_rad(max_elevation))
	
	var transverse = _fore().signed_angle_to(turret_looking, turret_up)
	var true_transverse = transverse #  Change if needed
	
	return Vector2(elevation, transverse)
	
func _up() -> Vector3:
	return global_transform.basis.y
	
func _fore() -> Vector3:
	return global_transform.basis.z
	
func _get_real_point_dir() -> Vector3:
	if barrels.size() == 0 or not (barrels[0] is Node3D):
		return Vector3.UP
	return barrels[0].global_transform.basis.z
	
func _set_elevation_transverse(elevation: float, transverse: float) -> void:
	if not is_instance_valid(turret) or barrels.size() == 0:
		return
	var turretRot = Basis(Vector3.UP, transverse)
	var barrelRot = turretRot * Basis(Vector3.LEFT, elevation)
	
	turret.transform = Transform3D(turretRot, turret.position);
	for b in barrels:
		b.transform = Transform3D(barrelRot, b.position);

