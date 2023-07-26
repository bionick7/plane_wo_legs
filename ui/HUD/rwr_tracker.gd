extends Node2D

var tracking_anchor: TrackingAnchor

var max_distance = 1000  # m
var rwr_radius = 128  # px

@onready var common_physics = $"/root/CommonPhysics"

func setup(anchor: TrackingAnchor) -> void:
	tracking_anchor = anchor

func update_pos(player: PlayerPlane) -> void:
	if not is_instance_valid(tracking_anchor):
		queue_free()
		return
	var rel_pos = tracking_anchor.global_position - player.global_position
	var distance = rel_pos.length()
	var up = common_physics.get_up(player.global_position)
	var m_y = (player.velocity - player.velocity.project(up)).normalized()
	var m_x = m_y.cross(up)
	var rel_pos_2d = Vector2(rel_pos.dot(m_x), rel_pos.dot(-m_y))
	var direction_2d = Vector2(tracking_anchor.basis.x.dot(m_x), tracking_anchor.basis.x.dot(-m_y))
	rel_pos_2d = rel_pos_2d.normalized() * clamp(distance / max_distance, 0, 1) * rwr_radius
	#rel_vel_2d = rel_vel_2d.normalized()
	position = Vector2.ONE * 128 + rel_pos_2d
	rotation = direction_2d.angle()
