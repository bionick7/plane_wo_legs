@tool
class_name Trail
extends MeshInstance3D

const MAX_STREAMFRAMES = 2048
const FLOAT_SIZE = 4
const ARRAY_FORMAT = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

@export var gen_in_editor: bool = false
@export var emit_velocity: Vector3
@export var lifetime = 6
@export var width = 0.5
@export var is_pushing = false

var position_byte_window: PackedByteArray = PackedByteArray(range(FLOAT_SIZE *  3))
var velocity_time_byte_window: PackedByteArray = PackedByteArray(range(FLOAT_SIZE *  4))

var _surface_array_cache = null

var stream_frame_push_index = 0

var time = 0

func _ready():
	if _surface_array_cache == null:
		_generate_cache()

func _process(dt: float):
	time += dt
	if _surface_array_cache == null:
		_generate_cache()
	if not Engine.is_editor_hint() or gen_in_editor:
		step(emit_velocity, -global_transform.basis.x * width*.5, time, time + dt)
		step(emit_velocity, global_transform.basis.x * width*.5, time, time + dt)

func clear() -> void:
	for i in range(MAX_STREAMFRAMES):
		free_at(i)

func step(global_push_velocity: Vector3, offset: Vector3, time: float, time_next: float) -> void:
	material_override.set_shader_parameter("time", time)
	material_override.set_shader_parameter("max_index", stream_frame_push_index)
	set_attributes_at_index(
		stream_frame_push_index,
		global_position + offset - global_push_velocity * time_next,
		global_push_velocity, 
		time + lifetime if is_pushing else -1e6
	)
	stream_frame_push_index = (stream_frame_push_index + 1) % MAX_STREAMFRAMES
	
func free_at(index: int) -> void:
	set_attributes_at_index(index, Vector3.ZERO, Vector3.ZERO, -1e6)

func set_attributes_at_index(index: int, pos: Vector3, vel: Vector3, death_time: float) -> void:
	# Very low level ik, but it gets an impactful 20x performance improvement over the naive approach
	position_byte_window.encode_float(0, pos.x)
	position_byte_window.encode_float(FLOAT_SIZE, pos.y)
	position_byte_window.encode_float(FLOAT_SIZE*2, pos.z)
	#position_byte_window.encode_var(0, pos)
	velocity_time_byte_window.encode_float(0, vel.x)
	velocity_time_byte_window.encode_float(FLOAT_SIZE, vel.y)
	velocity_time_byte_window.encode_float(FLOAT_SIZE*2, vel.z)
	velocity_time_byte_window.encode_float(FLOAT_SIZE*3, death_time)
	
	mesh.surface_update_vertex_region(   0, FLOAT_SIZE * 3 * index, position_byte_window)
	mesh.surface_update_attribute_region(0, FLOAT_SIZE * 4 * index, velocity_time_byte_window)
	
	#printt(pos, vel, death_time)
	#print(">", mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][index-1])
	#print(">", mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][(index-1)*4])
	#print(">", mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][(index-1)*4+1])
	#print(">", mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][(index-1)*4+2])
	#print(">", mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0][(index-1)*4+3])

func _generate_cache():
	_surface_array_cache = []
	_surface_array_cache.resize(Mesh.ARRAY_MAX)
	var vertecies = PackedVector3Array()
	var custom = PackedFloat32Array()
	vertecies.resize(MAX_STREAMFRAMES)
	custom.resize(MAX_STREAMFRAMES*4)
	_surface_array_cache[Mesh.ARRAY_VERTEX] = vertecies
	_surface_array_cache[Mesh.ARRAY_CUSTOM0] = custom
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, _surface_array_cache, [], {}, ARRAY_FORMAT)
