extends CanvasLayer

var text = ""

var global_frozen = false

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
