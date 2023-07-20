extends Node3D

var tracking_agent: PlaneInterface
var tracking_reference: Node3D

func setup(agent: Node3D):
	tracking_agent = agent
	tracking_reference = agent.get_node("TrackingPoint")

func update_pos(view_pos: Vector3, view_vel: Vector3, up: Vector3):
	var pointing_dir = (tracking_reference.global_position - view_pos).normalized()
	var point_up = (up - pointing_dir.project(up)).normalized()
	$DirectTracker.transform = Transform3D(point_up.cross(pointing_dir), point_up, pointing_dir, Vector3.ZERO)

	var rel_pos = tracking_reference.global_position - view_pos
	var rel_vel = tracking_agent.velocity - view_vel
	
	var aim_t = NPCPlane.preaim_simple(rel_pos, rel_vel, 1000)
	
	var aim_dir = (rel_pos + aim_t * rel_vel).normalized()
	var aim_up = (up - aim_dir.project(up)).normalized()
	$AimingPoint.transform = Transform3D(aim_up.cross(aim_dir), aim_up, aim_dir, Vector3.ZERO)
