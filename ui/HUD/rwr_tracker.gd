extends Node2D

var tracking_agent: PlaneInterface
var tracking_reference: Node3D

var max_distance = 1000  # m
var rwr_radius = 128  # px

@onready var common_physics = $"/root/CommonPhysics"

func setup(agent: PlaneInterface) -> void:
	tracking_agent = agent
	tracking_reference = agent.get_node("TrackingPoint")

func update_pos(player: PlayerPlane) -> void:
	if not is_instance_valid(tracking_agent):
		queue_free()
		return
	var rel_pos = tracking_reference.global_position - player.global_position
	var distance = rel_pos.length()
	var up = common_physics.get_up(player.global_position)
	var m_y = (player.velocity - player.velocity.project(up)).normalized()
	var m_x = m_y.cross(up)
	var rel_pos_2d = Vector2(rel_pos.dot(m_x), rel_pos.dot(-m_y))
	var direction_2d = Vector2(tracking_agent.basis.x.dot(m_x), tracking_agent.basis.x.dot(-m_y))
	rel_pos_2d = rel_pos_2d.normalized() * clamp(distance / max_distance, 0, 1) * rwr_radius
	#rel_vel_2d = rel_vel_2d.normalized()
	position = Vector2.ONE * 128 + rel_pos_2d
	rotation = direction_2d.angle()
