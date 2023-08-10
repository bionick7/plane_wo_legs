extends Node3D

var tracking_anchor: TrackingAnchor

var is_targeted: bool
var player_can_see: bool

var healthbar_material

@onready var direct_tracker = $DirectTracker
@onready var distance_text = $DirectTracker/Distance
@onready var speed_text = $DirectTracker/Speed
@onready var aiming_point = $AimingPoint

func setup(anchor: TrackingAnchor) -> void:
	healthbar_material = $DirectTracker/Health.material_override
	assert(is_instance_valid(healthbar_material))
	tracking_anchor = anchor
	if tracking_anchor.has_health():
		tracking_anchor.hitbox.set_healthbar(healthbar_material)

func update_pos(view_pos: Vector3, view_vel: Vector3, up: Vector3) -> void:
	if not is_instance_valid(tracking_anchor):
		queue_free()
		return
	if tracking_anchor.is_hidden() or not player_can_see:
		hide()
		return
	show()
	var pointing_dir = (tracking_anchor.global_position - view_pos).normalized()
	direct_tracker.transform = Transform3D(
		NPCUtility.basis_align(pointing_dir, up, true),
		Vector3.ZERO)
	
	var rel_pos = tracking_anchor.global_position - view_pos
	var distance_km = rel_pos.length() / 1000.
	distance_text.text = "%6.2f km" % distance_km
	speed_text.text = "%6.0f kts" % (tracking_anchor.get_velocity().length() / 0.51444)

	$DirectTracker/Health.visible = is_targeted and tracking_anchor.has_health()
	aiming_point.visible = is_targeted and distance_km <= 1.0
	distance_text.visible = is_targeted
	speed_text.visible = is_targeted

	if is_targeted:
		var rel_vel = tracking_anchor.get_velocity() - view_vel
		var aim_t = NPCUtility.preaim_simple(rel_pos, rel_vel, 1000)
		var aim_dir = (rel_pos + aim_t * rel_vel).normalized()
		aiming_point.transform = Transform3D(NPCUtility.basis_align(aim_dir, up, true), Vector3.ZERO).orthonormalized()

