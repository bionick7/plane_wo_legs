class_name DebugDrawer
extends MeshInstance3D

enum { DEBUG, GAME }

const TRACE_FLAG_ACTIVE = 1
const TRACE_FLAG_GLOBAL = 2

@export var marker_size = 0.2

var _colors = PackedColorArray()
var _lines = PackedVector3Array()
var _vis_types = PackedByteArray()

var traces: Array[PackedVector3Array] = []
var trace_flags = PackedByteArray()
var trace_colors = PackedColorArray()

var current_vis_type = DEBUG

func _ready():
	assert(mesh is ImmediateMesh)

func _process(dt: float):
	mesh.clear_surfaces()
	assert(_colors.size() == _lines.size())
	if _lines.size() == 0:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(_colors.size()):
		mesh.surface_set_color(_colors[i])
		mesh.surface_add_vertex(_lines[i])
	mesh.surface_end()
	_lines.clear()
	_colors.clear()
	
	assert(traces.size() == trace_flags.size() and traces.size() == trace_colors.size())
	for i in range(traces.size()):
		if trace_flags[i] & TRACE_FLAG_ACTIVE != 0 and traces[i].size() > 0:
			mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			mesh.surface_set_color(trace_colors[i])
			for v in traces[i]:
				if trace_flags[i] & TRACE_FLAG_GLOBAL:
					mesh.surface_add_vertex(global_transform.inverse() * v)
				else:
					mesh.surface_add_vertex(v)
			mesh.surface_end()

func draw_line(from: Vector3, to: Vector3, color: Color) -> void:
	_lines.append(from)
	_lines.append(to)
	_colors.append_array([color, color])
	_vis_types.append_array([current_vis_type, current_vis_type])
	
func draw_point(point: Vector3, color: Color) -> void:
	draw_line(point + Vector3.FORWARD * marker_size, point + Vector3.BACK * marker_size, color)
	draw_line(point + Vector3.RIGHT * marker_size, point + Vector3.LEFT * marker_size, color)
	draw_line(point + Vector3.UP  * marker_size, point + Vector3.DOWN * marker_size, color)
	
func draw_path(pts: PackedVector3Array, color: Color) -> void:
	assert(pts.size() >= 2)
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i+1], color)
	
func draw_line_global(from: Vector3, to: Vector3, color: Color) -> void:
	var transf = global_transform.inverse()
	draw_line(transf * from, transf * to, color)

func draw_point_global(point: Vector3, color: Color) -> void:
	var transf = global_transform.inverse()
	draw_point(transf * point, color)
	
func draw_path_global(pts: PackedVector3Array, color: Color) -> void:
	var transf = global_transform.inverse()
	draw_path(transf * pts, color)

func draw_basis(mat: Basis, offset: Vector3, color: Color) -> void:
	# Always global orientation
	var transf = global_transform.basis.inverse()
	draw_line(offset, offset + transf * mat.x, color)
	draw_line(offset, offset + transf * mat.y, color)
	draw_line(offset, offset + transf * mat.z, color)
	
func start_trace(color: Color, flags: int = TRACE_FLAG_ACTIVE) -> int:
	for i in range(traces.size()):
		if trace_flags[i] == 0:
			traces[i] = PackedVector3Array()
			trace_colors[i] = color
			trace_flags[i] = flags
			return i
	var index = traces.size()
	traces.append(PackedVector3Array())
	trace_colors.append(color)
	trace_flags.append(flags)
	return index
	
func stop_trace(index: int) -> void:
	trace_flags[index] &= ~TRACE_FLAG_ACTIVE

func extend_trace(index: int, point: Vector3) -> void:
	traces[index].append(point)
	
