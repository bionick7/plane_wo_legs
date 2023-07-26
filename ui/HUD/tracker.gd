extends Node3D

var tracking_anchor: TrackingAnchor

var draw_preaim: bool
var player_can_see: bool

var healthbar_material

@onready var direct_tracker = $DirectTracker
@onready var distance_text = $DirectTracker/Distance
@onready var aiming_point = $AimingPoint

func setup(anchor: TrackingAnchor) -> void:
	healthbar_material = $DirectTracker/Health.material_override
	assert(is_instance_valid(healthbar_material))
	tracking_anchor = anchor
	tracking_anchor.hitbox.on_take_dammage.connect(_on_take_dammage)
	healthbar_material.set_shader_parameter("total_hp", tracking_anchor.get_max_health())
	_update_hp()

func update_pos(view_pos: Vector3, view_vel: Vector3, up: Vector3) -> void:
	if not is_instance_valid(tracking_anchor):
		queue_free()
		return
	if tracking_anchor.is_hidden() or not player_can_see:
		hide()
		return
	show()
	var pointing_dir = (tracking_anchor.global_position - view_pos).normalized()
	if is_equal_approx(pointing_dir.dot(up), 1.):  # Avoid singularities where up and pointing_dir are linearly dependant
		up = Vector3.UP if abs(up.y) < 0.9 else Vector3.RIGHT
	var point_up = (up - up.project(pointing_dir)).normalized()
	direct_tracker.transform = Transform3D(point_up.cross(pointing_dir), point_up, pointing_dir, Vector3.ZERO)
	
	var rel_pos = tracking_anchor.global_position - view_pos
	var distance_km = rel_pos.length() / 1000.
	distance_text.text = "%6.2f km" % distance_km

	$DirectTracker/Health.visible = draw_preaim and tracking_anchor.has_health()
	aiming_point.visible = draw_preaim and distance_km <= 1.0

	if draw_preaim:
		var rel_vel = tracking_anchor.get_velocity() - view_vel
		
		var aim_t = NPCPlane.preaim_simple(rel_pos, rel_vel, 1000)
		
		var aim_dir = (rel_pos + aim_t * rel_vel).normalized()
		var aim_up = (up - up.project(aim_dir)).normalized()
		aiming_point.transform = Transform3D(aim_up.cross(aim_dir), aim_up, aim_dir, Vector3.ZERO).orthonormalized()

func _on_take_dammage(ammount: int) -> void:
	# TODO: animation
	_update_hp()

func _update_hp() -> void:
	healthbar_material.set_shader_parameter("current_hp", tracking_anchor.get_health())
