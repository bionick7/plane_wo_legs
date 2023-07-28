extends MeshInstance3D

@export var debug_region: AABB
@export var point_spacing: float

func _ready():
	await get_tree().process_frame
	var start = global_transform * debug_region.position
	var end = global_transform * debug_region.end
	var steps: Vector3i = (end - start) / point_spacing
	var N = steps.x*steps.y*steps.z
	var expected_time = 4.5e-6 * N
	print("%d x %d x %d = %d" % [steps.x, steps.y, steps.z, N])
	print("Expected time: %f s" % expected_time)
	assert(expected_time < 10)
	
	var t0 = Time.get_ticks_usec()
	var xx = range(steps.x).map(func(x): return start.x + x * (end.x - start.x) / steps.x)
	var yy = range(steps.y).map(func(y): return start.y + y * (end.y - start.y) / steps.y)
	var zz = range(steps.z).map(func(z): return start.z + z * (end.z - start.z) / steps.z)
	
	var points = PackedVector3Array()
	var v: Vector3
	
	for x in xx:
		for y in yy:
			for z in zz:
				v = Vector3(x, y, z)
				if CloudManager.is_in_cloud(v):
					points.append(v)
	
	var actual_time = (Time.get_ticks_usec() - t0) / 1e6
	var mesh_data = []
	mesh_data.resize(Mesh.ARRAY_MAX)
	mesh_data[Mesh.ARRAY_VERTEX] = points
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, mesh_data)
	print("Actual time: %f s" % actual_time)
