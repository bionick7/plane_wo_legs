extends Window

@onready var config := InputManager.config

func setup(device: int) -> void:
	position = (get_tree().root.size - size) / 2
	show()

func _on_close_requested():
	hide()
