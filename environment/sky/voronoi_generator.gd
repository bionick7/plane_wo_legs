@tool
extends Resource
class_name VoronoiGenerator

const RESOLUTION: int = 64
const CELLS: int = 8
const CELL_SIZE: int = 8
const FORMAT: Image.Format = Image.FORMAT_RGBAH

@export_group("Texture generation")
@export var lacunarity: float
@export_enum("Distance", "Cell position", "Cell index") var output_type: String
@export_dir var save_path : String
@export var voronoi: Texture3D

@export_group("Operations")
@export var generate: bool:
	set(x):
		var active_thread = Thread.new()
		active_thread.start(update_img)

@export var load: bool:
	set(x):
		load_images_at(save_path)

var points: PackedVector3Array  # Relative position of points within cell : N = CELLS³ ; [0, 1 / CELLS[
var cell_neighbours: PackedInt32Array  # Flattened lookup for the neighbours of each cell N = 27*CELLS³ ; NN n [0, CELLS³[
var offsets: PackedVector3Array  # Offsets of each neighbour

func update_img() -> void:
	var time_start: int = Time.get_ticks_usec()
	
	var img_arr: Array[Image] = []
	for i in range(RESOLUTION):
		img_arr.append(Image.create(RESOLUTION, RESOLUTION, false, FORMAT))
	points = PackedVector3Array()
	points.resize(CELLS*CELLS*CELLS)
	
	var cell_index: int = 0
	for z_cell in range(CELLS):
		for y_cell in range(CELLS):
			for x_cell in range(CELLS):
				points[cell_index] = Vector3(randf(), randf(), randf()) / CELLS
				cell_index += 1
		
	cell_neighbours = PackedInt32Array()
	cell_neighbours.resize(27 * CELLS*CELLS*CELLS)
	for z_cell in range(CELLS):
		for y_cell in range(CELLS):
			for x_cell in range(CELLS):
				var i: int = 0
				for z_n in [-1, 0, 1]:
					for y_n in [-1, 0, 1]:
						for x_n in [-1, 0, 1]:
							var neighbours_index = (((z_cell * CELLS + y_cell) * CELLS + x_cell) * 27) + i
							cell_neighbours[neighbours_index] = \
								posmod(x_cell + x_n, CELLS) + \
								posmod(y_cell + y_n, CELLS) * CELLS + \
								posmod(z_cell + z_n, CELLS) * CELLS*CELLS
							i += 1
	
	offsets = PackedVector3Array()
	for z_n in [-1, 0, 1]:
		for y_n in [-1, 0, 1]:
			for x_n in [-1, 0, 1]:
				offsets.append(Vector3(x_n, y_n, z_n) / float(CELLS))
	
	var time_end: int = Time.get_ticks_usec()
	print("Cell neighbours done: %f ms" % ((time_end - time_start) / 1000))
	time_start = time_end
	
	#print(cell_neighbours)
	assert(cell_neighbours[(((1 * CELLS + 0) * CELLS + 7) * 27) + 5] == 0)
	
	for z in range(RESOLUTION):
		for y in range(RESOLUTION):
			for x in range(RESOLUTION):
				var pos = Vector3(x, y, z)
				match output_type:
					"Distance":
						var value0: float = get_distance_at(pos)
						var value1: float = get_distance_at((pos * lacunarity).posmod(RESOLUTION))
						var value2: float = get_distance_at((pos * lacunarity * lacunarity).posmod(RESOLUTION))
						#var value3: float = get_value_at(pos * lacunarity * lacunarity * lacunarity)
						
						img_arr[z].set_pixel(x, y, Color(value0, value1, value2, 1.0))
					"Cell position":
						var cell_pos: Vector3i = (pos  / CELL_SIZE).floor()
						var next_index: int = get_index_at(pos).x
						#var next_pos: Vector3 = points[next_index] + offsets[i] + cell_pos / float(CELLS)
						
						#img_arr[z].set_pixel(x, y, Color(next_pos.x, next_pos.y, next_pos.z))
					"Cell index":
						var next_index: Vector4i = get_index_at(pos)
						
						img_arr[z].set_pixel(x, y, Color.hex64(
							next_index.x << (48 + 7)
							| next_index.y << (32 + 7)
							| next_index.z << (16 + 7)
							| next_index.w << 7
						))
						
				
	voronoi = ImageTexture3D.new()
	voronoi.create(FORMAT, RESOLUTION, RESOLUTION, RESOLUTION, false, img_arr)
	
	time_end = Time.get_ticks_usec()
	print("Texture updated: %d ms" % ((time_end - time_start) / 1000))
	save_images_at(save_path, img_arr)

func get_distance_at(pos: Vector3) -> float:
	var cell_pos: Vector3i = (pos  / CELL_SIZE).floor()
	var sub_pos: Vector3 = pos / float(RESOLUTION) - cell_pos / float(CELLS)
	var next_dist_sqr: float = 1e3
	var neighbours_index = ((cell_pos.z * CELLS + cell_pos.y) * CELLS + cell_pos.x) * 27
	for i in range(27):
		var p: Vector3 = points[cell_neighbours[neighbours_index + i]] + offsets[i]
		var d_sqr: float = (p - sub_pos).length_squared()
		if d_sqr < next_dist_sqr:
			next_dist_sqr = d_sqr
	
	return 1 - clamp(sqrt(next_dist_sqr) * 5.0, 0, 1)
	
func get_index_at(pos: Vector3) -> Vector4i:
	var cell_pos: Vector3i = (pos  / CELL_SIZE).floor()
	var sub_pos: Vector3 = pos / float(RESOLUTION) - cell_pos / float(CELLS)
	var next_dist_sqr: Vector4 = Vector4.ONE * 1e3
	var next_dist_index: Vector4i = -Vector4i.ONE
	var neighbours_index = ((cell_pos.z * CELLS + cell_pos.y) * CELLS + cell_pos.x) * 27
	for i in range(27):
		var index: int = cell_neighbours[neighbours_index + i]
		var p: Vector3 = points[index] + offsets[i]
		var d_sqr: float = (p - sub_pos).length_squared()
		if d_sqr < next_dist_sqr.x:
			next_dist_sqr.w = next_dist_sqr.z
			next_dist_sqr.z = next_dist_sqr.y
			next_dist_sqr.y = next_dist_sqr.x
			next_dist_sqr.x = d_sqr
			next_dist_index.w = next_dist_index.z
			next_dist_index.z = next_dist_index.y
			next_dist_index.y = next_dist_index.x
			next_dist_index.x = index
		elif d_sqr < next_dist_sqr.y:
			next_dist_sqr.w = next_dist_sqr.z
			next_dist_sqr.z = next_dist_sqr.y
			next_dist_sqr.y = d_sqr
			next_dist_index.w = next_dist_index.z
			next_dist_index.z = next_dist_index.y
			next_dist_index.y = index
		elif d_sqr < next_dist_sqr.z:
			next_dist_sqr.w = next_dist_sqr.z
			next_dist_sqr.z = d_sqr
			next_dist_index.w = next_dist_index.z
			next_dist_index.z = index
		elif d_sqr < next_dist_sqr.w:
			next_dist_sqr.w = d_sqr
			next_dist_index.w = index	
	return next_dist_index

func save_images_at(dir_path: String, img_arr: Array[Image]) -> void:
	var i: int = 0
	var img_offsets = PackedInt32Array()
	img_offsets.resize(RESOLUTION)
	var file: FileAccess = FileAccess.open(dir_path.path_join("main.clouds"), FileAccess.WRITE)
	file.seek(4 * RESOLUTION + 4)
	for img in img_arr:
		#var path: String = dir_path.path_join("img%d.exr" % i)
		#img.save_exr(path)
		img_offsets[i] = file.get_position()
		file.store_buffer(img.save_png_to_buffer())
		i += 1
	file.seek(0)
	file.store_32(RESOLUTION)
	for o in img_offsets:
		file.store_32(o)
	file.flush()

func load_images_at(dir_path: String) -> void:
	var time_start = Time.get_ticks_usec()
	var img_arr: Array[Image] = []
	
	var file: FileAccess = FileAccess.open(dir_path.path_join("main.clouds"), FileAccess.READ)
	
	var resolution: int = file.get_32()
	var img_offsets = PackedInt32Array()
	for i in range(resolution):
		img_offsets.append(file.get_32())
		
	#print(resolution, offsets)
	
	for i in range(resolution):
		var from: int = img_offsets[i]
		var to: int = img_offsets[i+1] if i < resolution - 1 else file.get_length() + 1
		file.seek(from)
		var buffer: PackedByteArray = file.get_buffer(to - from)
		var img: Image = Image.create(resolution, resolution, false, FORMAT)
		img.load_png_from_buffer(buffer)
		img.convert(FORMAT)
		img_arr.append(img)
	
	#print(img_arr[0].data)
	#debug_show = ImageTexture.new()
	#debug_show.create_from_image(img_arr[0])
	voronoi = ImageTexture3D.new()
	voronoi.create(FORMAT, resolution, resolution, resolution, false, img_arr)
	
	print("Cloud noise loaded in %d ms (from manager)" % ((Time.get_ticks_usec() - time_start) / 1000))
