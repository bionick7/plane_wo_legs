extends CanvasLayer

var text = ""

func _process(dt: float):
	$Label.text = text
	text = ""

func write_line(line: String) -> void:
	text += line + "\n"
