extends Node3D

var tracking_agent: PlaneInterface
var tracking_reference: Node3D

var draw_preaim: bool
var player_can_see: bool

func setup(agent: PlaneInterface) -> void:
	tracking_agent = agent
	tracking_reference = agent.get_node("TrackingPoint")
	tracking_agent.on_take_dammage.connect(_on_take_dammage)

func update_pos(view_pos: Vector3, view_vel: Vector3, up: Vector3) -> void:
	if not is_instance_valid(tracking_agent):
		queue_free()
		return
	if tracking_agent.is_hidden() or not player_can_see:
		$DirectTracker/Sprite3D.hide()
		$AimingPoint.hide()
		$DirectTracker/Distance.text = "???"
		return
	var pointing_dir = (tracking_reference.global_position - view_pos).normalized()
	if is_equal_approx(pointing_dir.dot(up), 1.):  # Avoid singularities where up and pointing_dir are linearly  dependant
		up = Vector3.UP if abs(up.y) < 0.9 else Vector3.RIGHT
	var point_up = (up - up.project(pointing_dir)).normalized()
	$DirectTracker.transform = Transform3D(point_up.cross(pointing_dir), point_up, pointing_dir, Vector3.ZERO)
	
	var rel_pos = tracking_reference.global_position - view_pos
	$DirectTracker/Distance.text = "%6.2f km" % (rel_pos.length() / 1000.)

	$AimingPoint.visible = draw_preaim

	if draw_preaim:
		var rel_vel = tracking_agent.velocity - view_vel
		
		var aim_t = NPCPlane.preaim_simple(rel_pos, rel_vel, 1000)
		
		var aim_dir = (rel_pos + aim_t * rel_vel).normalized()
		var aim_up = (up - up.project(aim_dir)).normalized()
		$AimingPoint.transform = Transform3D(aim_up.cross(aim_dir), aim_up, aim_dir, Vector3.ZERO).orthonormalized()

func _on_take_dammage(ammount: int) -> void:
	pass
	
