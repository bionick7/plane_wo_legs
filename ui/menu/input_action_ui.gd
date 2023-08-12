class_name InputActionUI
extends PanelContainer

## UI to handle an individual input action
## 
## Gets set up with the action name and keeps its independant 
## reference to InputManager.config

@export var input_atlas: InputAtlas

var action_name := ""
var action_data := {}
var is_listening := false

@onready var config := InputManager.config

func _ready():
	%InputListen.focus_entered.connect(_on_focus_entered)
	%InputListen.focus_exited.connect(_on_focus_exited)

func _input(event: InputEvent):
	if not is_listening:
		return
	if not (
			event is InputEventMouseButton or event is InputEventKey or 
			event is InputEventJoypadButton or event is InputEventMIDI
	):
		return
	if not event.is_pressed():
		return
	_add_event_to_map(event)
	%InputListen.release_focus()

func setup(p_action_name: String) -> void:
	action_name = p_action_name
	action_data = config.action_map[action_name]
	%ActionName.text = action_name.capitalize()
	_update_icons()

func _add_event_to_map(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.device in config.flightstick_devices:
			action_data.flightstick = [var_to_str(event)]
		elif event.device in config.gamepad_devices:
			action_data.gamepad = [var_to_str(event)]
	else:
		action_data.keyboard = [var_to_str(event)]
	config.action_map[action_name] = action_data
	_update_icons()

func _update_icons() -> void:
	var keyboard_action: InputEvent = _decode_first_event_from_array(action_data.keyboard)
	var flightstick_action: InputEvent = _decode_first_event_from_array(action_data.flightstick)
	var gamepad_action: InputEvent = _decode_first_event_from_array(action_data.gamepad)
	
	if config.flightstick_devices.size() > 0 and flightstick_action != null:
		flightstick_action.device = config.flightstick_devices.keys()[0]
	if config.gamepad_devices.size() > 0 and gamepad_action != null:
		gamepad_action.device = config.gamepad_devices.keys()[0]
	
	%KeyboardIcon.texture = input_atlas.get_icon(keyboard_action)
	%FlightStickIcon.texture = input_atlas.get_icon(flightstick_action)
	%GamepadIcon.texture = input_atlas.get_icon(gamepad_action)

func _decode_first_event_from_array(array: Array) -> InputEvent:
	if array.size() == 0:
		return null
	return str_to_var(array[0])

func _on_focus_entered() -> void:
	is_listening = true
	%InputListen.text = "Actuate axis to replace"

func _on_focus_exited() -> void:
	is_listening = false
	%InputListen.text = ""
