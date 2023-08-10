extends MeshInstance3D

var tracking: TrackingAnchor
var draw_mesh: ImmediateMesh

func _ready():
	draw_mesh = ImmediateMesh.new()
	mesh = draw_mesh

func _process(dt: float):
	if not is_instance_valid(tracking):
		return
		
	var distance_sqr := global_position.distance_squared_to(tracking.global_position)
	var closeness: float = 1.0 - clamp(distance_sqr / 1000.0, 0.0, 1.0)
	var angle = global_transform.basis.z.angle_to(tracking.global_position - global_position)
	var tracking_strength: float = 1.0 - clamp(angle / deg_to_rad(30), 0.0, 1.0)
	draw_mesh.clear_surfaces()
	draw_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	draw_mesh.surface_set_color(Color.RED.lerp(Color.GREEN, tracking_strength))
	draw_mesh.surface_add_vertex(Vector3.ZERO)
	draw_mesh.surface_add_vertex(global_transform.inverse() * tracking.global_position)
	draw_mesh.surface_end()
