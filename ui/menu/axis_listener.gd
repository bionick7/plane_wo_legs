class_name AxisListener
extends LineEdit

## Listnes for a joystick/gamepad axis when focused and signals inputted axis away

signal axis_mapping_changed(device: int, axis_id: String, new_axis: JoyAxis)

const AXIS_ARRAY: Array[String] = [
	"Left X",
	"Left Y",
	"Right X",
	"Right Y",
	"Trigger Left",
	"Trigger Right",
]

## Key as used in the input_config.json device mat
@export var axis_id: String

var current_axis := 0

var is_listening := false
var device_listening := 0

func _ready():
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _input(event: InputEvent):
	if not is_listening or event.device != device_listening:
		return
	if not event is InputEventJoypadMotion:
		return
	if abs(event.axis_value) < 0.5:
		return
	_set_axis_direct(event.axis)
	#release_focus()  # Is this preferable?
	axis_mapping_changed.emit(device_listening, axis_id, event.axis)

func set_device(device: int) -> void:
	device_listening = device
	var default_axis: JoyAxis = InputManager.get_axis_mapping(device, axis_id)
	_set_axis_direct(default_axis)

func _set_axis_direct(new_axis: JoyAxis) -> void:
	current_axis = new_axis
	text = _get_axis_name(new_axis)
	new_axis = current_axis

func _on_focus_entered() -> void:
	is_listening = true
	text = "Actuate axis to replace"

func _on_focus_exited() -> void:
	is_listening = false
	text = _get_axis_name(current_axis)

func _get_axis_name(axis: int) -> String:
	if axis < 0 or axis >= AXIS_ARRAY.size():
		return "Axis not set"
	return AXIS_ARRAY[axis]
