@tool
class_name CloudManagerClass
extends Node

@export var voronoi_generator: VoronoiGenerator
@export var cloud_parameters: CloudParameters

@export var test_performance: bool:
	set(x): 
		_load()
		_test()

var cloud_anim_time: float = 0
var image_cache: Array[Image]
var image_size = Vector3i(64, 64, 64)

func _ready():
	_load()
	
func _process(dt: float):
	cloud_anim_time += dt
	RenderingServer.global_shader_parameter_set("cloud_anim_time", cloud_anim_time)

func _test() -> void:
	var random_pts = PackedVector3Array()
	for i in range(1000):
		random_pts.append(Vector3(randf(), randf(), randf()) * 4000)
	var t0_µs: int = Time.get_ticks_usec()
	for i in range(1000):
		get_cloud_density(random_pts[i])
	var time_ms: float = (Time.get_ticks_usec() - t0_µs) / 1e3
	print("Cloud density lookup in %f µs" % time_ms)

func _load() -> void:
	voronoi_generator.load_images_at(voronoi_generator.save_path)
	image_cache = voronoi_generator.voronoi.get_data()
	image_size = Vector3i(64, 64, 64)

func is_in_cloud(pos: Vector3) -> bool:
	var pos_xy = pos - pos.z * Vector3.BACK
	var p: Vector3 = Vector3(
		CloudManagerClass.radial_coord(pos_xy.x, pos_xy.y),
		(cloud_parameters.layer_mid - pos_xy.length()) * 1e-3,
		pos.z * 3.33333e-4
	)
	
	var mask = clamp(1.0 - 4e6*p.y*p.y/(cloud_parameters.layer_thickness*cloud_parameters.layer_thickness), 0.0, 1.0)
	mask = mask*mask
	#if mask < cloud_parameters.threshhold:
	#	return false
	var cov = _get_coverage(Vector2(p.x, p.z))
	#if cov * mask < cloud_parameters.threshhold:
	#	return false
	p.y *= cloud_parameters.cloud_flatten
	p += Vector3(cloud_parameters.cloud_cover_speed, 0, 0) * cloud_anim_time
	var n = 0.0
	n += smoothstep(0.4, 1.2, 
		_evaluate_voronoi(p / TAU).dot(cloud_parameters.noise_weights)
		+ _evaluate_voronoi(p / TAU * 10.0).dot(cloud_parameters.noise_weights_detail)
	)
	return cov * mask * n >= cloud_parameters.threshhold

func get_cloud_density(pos: Vector3) -> float:
	#assert(is_instance_valid(voronoi_generator.voronoi), "Texture gone *shrugs*")
	#var texels = voronoi_generator.voronoi.get_depth() * voronoi_generator.voronoi.get_width() * voronoi_generator.voronoi.get_height()
	#assert(texels == 64*64*64, "Texture wrong size (%d x %d x %d)" % [
	#	voronoi_generator.voronoi.get_width(),
	#	voronoi_generator.voronoi.get_height(),
	#	voronoi_generator.voronoi.get_depth(),
	#])
	var pos_xy = pos - pos.z * Vector3.BACK
	var p: Vector3 = Vector3(
		CloudManagerClass.radial_coord(pos_xy.x, pos_xy.y),
		(cloud_parameters.layer_mid - pos_xy.length()) * 1e-3,
		pos.z * 3.33333e-4
	)
	
	var mask = clamp(1.0 - 4e6*p.y*p.y/(cloud_parameters.layer_thickness*cloud_parameters.layer_thickness), 0.0, 1.0)
	var cov = _get_coverage(Vector2(p.x, p.z))
	mask = mask*mask
	p.y *= cloud_parameters.cloud_flatten
	p += Vector3(cloud_parameters.cloud_cover_speed, 0, 0) * cloud_anim_time
	var n = 0.0
	n += smoothstep(0.4, 1.2, 
		_evaluate_voronoi(p / TAU).dot(cloud_parameters.noise_weights)
		+ _evaluate_voronoi(p / TAU * 10.0).dot(cloud_parameters.noise_weights_detail)
	)
	return cov * mask * n

static func radial_coord(x: float, y: float) -> float:
	var angle = atan(y / x) + PI/2.0
	if x < 0.0: angle += PI
	return angle;

func _get_coverage(uv: Vector2) -> float:
	uv /= TAU
	uv += Vector2(cloud_parameters.cloud_cover_speed, 0) * cloud_anim_time
	return smoothstep(0.4, 1.0, _evaluate_texture_2d(cloud_parameters.coverage_texture, uv))
	
func _evaluate_texture_2d(texture2d: Texture2D, uv: Vector2) -> float:
	uv.x = fposmod(uv.x, 1.0)
	uv.y = fposmod(uv.y, 1.0)
	var uv_index: Vector2i = Vector2i(uv * Vector2(texture2d.get_width(), texture2d.get_height())) 
	return texture2d.get_image().get_pixelv(uv_index).r
	
func _evaluate_voronoi(pos: Vector3) -> Vector4:
	pos.x = fposmod(pos.x, 1.0)
	pos.y = fposmod(pos.y, 1.0)
	pos.z = fposmod(pos.z, 1.0)
	var pos_index: Vector3i = Vector3i(pos * Vector3(image_size))
	var res_color: Color = image_cache[pos_index.z].get_pixel(pos_index.x, pos_index.y)
	return Vector4(res_color.r, res_color.g, res_color.b, res_color.a)
