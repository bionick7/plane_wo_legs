extends CanvasLayer

var text := ""
var global_frozen := false

var timer_stack: Array[int] = []
var profiles := {}
var data_tables := {}

func _process(dt: float):
	$Label.text = text
	text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		global_frozen = not global_frozen
		get_tree().call_group("Planes", "set", "frozen", global_frozen)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		get_tree().call_group("Planes", "set", "manual_step", true)

func write_line(line: String) -> void:
	text += line + "\n"

# <<= ==================================== =>>
# 				PROFILER
# <<= ==================================== =>>
func __PROFILER__(): pass

func push_timer() -> void:
	timer_stack.append(Time.get_ticks_usec())
	
func pop_timer() -> int:
	# retruns elapsed time in µs
	var last = timer_stack.pop_back()
	return (Time.get_ticks_usec() - last)
	
func pop_read_timer(format: String = "t = %d µs") -> int:
	# retruns elapsed time in µs
	var t := pop_timer()
	print(format % t)
	return t
	
func pop_timer_to_profile(key: String) -> int:
	var t := pop_timer()
	if key in profiles:
		profiles[key] += t
	else:
		profiles[key] = t
	return t

func clear_profile(key: String) -> void:
	if key in profiles:
		profiles[key] = 0.0

# <<= ==================================== =>>
# 				DATA TABLES
# <<= ==================================== =>>
func __DATA_TABLES__(): pass

func clear_data_table(table_name: String) -> void:
	if table_name in data_tables:
		data_tables.clear()

func data_table_push_row(table_name: String, row: Array) -> void:
	# Trusting row.Length = columnSize
	if not table_name in data_tables:
		var item: Array[PackedStringArray] = []
		data_tables[table_name] = item
	data_tables[table_name].append(PackedStringArray(row.map(func(x): return str(x))))

func store_data_table(table_name: String) -> void:
	var path := "res://meta/tables/%s.csv" % table_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("While trying to write to \"%s\": \"\"" % [path, error_string(FileAccess.get_open_error())])
		return
	for row in data_tables[table_name]:
		f.store_csv_line(row)
	f.flush()

func plot_data_table(table_name: String) -> void:
	store_data_table(table_name)
	var path := ProjectSettings.globalize_path("res://meta/tables/%s.csv" % table_name)
	var pyPath := ProjectSettings.globalize_path("res://meta/tables/plotter.py")
	var output := []
	OS.execute("python3", PackedStringArray([pyPath, path]), output, true, true)

func plot_function(f: Callable, x_start: float, x_end: float, steps: int) -> void:
	clear_data_table("__TMP")
	for i in range(steps):
		var x := x_start + (x_end - x_start) / (steps - 1) * i
		data_table_push_row("__TMP", [x, f.call(x)])
	store_data_table("__TMP")
	plot_data_table("__TMP")
