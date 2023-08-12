class_name ControlsOptionPanel
extends Control

const MAX_CONNECTED_DEVICES: int = 4
const FLIGHTSTICK_OPTION: int = 0
const GAMEPAD_OPTION: int = 1

const INPUT_ACTION_UI_TEMPLATE: PackedScene = preload("res://ui/menu/input_action_ui.tscn")

var devices := PackedInt32Array()

var current_device_index: int = 0

@onready var config := InputManager.config
@onready var device_selector: OptionButton = %DeviceSelector

func _ready():
	config.changed.connect(_update_menu)
	_update_menu()
	for axis_listener in get_tree().get_nodes_in_group("AxisListener"):
		axis_listener.axis_mapping_changed.connect(_on_axis_mapping_changed)

func _update_menu() -> void:
	# Needs to update on reconnect
	devices.clear()
	devices.append_array(config.flightstick_devices.keys())
	devices.append_array(config.gamepad_devices.keys())
	device_selector.clear()
	for device in devices:
		device_selector.add_item(Input.get_joy_name(device))
	
	for action in config.action_map:
		var inp_action: InputActionUI = INPUT_ACTION_UI_TEMPLATE.instantiate()
		%InputActionUIParent.add_child(inp_action)
		inp_action.setup(action)
	
	_on_selected_device_changed(current_device_index)
	
func _on_changed() -> void:
	pass

func _on_selected_device_changed(new_index: int) -> void:
	current_device_index = new_index
	var current_device := devices[current_device_index]
	(%DeviceOptionTabs as TabContainer).current_tab = (FLIGHTSTICK_OPTION
			if current_device in config.flightstick_devices else GAMEPAD_OPTION)
	get_tree().call_group("AxisListener", "set_device", current_device)

func _on_save() -> void:
	config.store_config_file()

func _on_axis_mapping_changed(device: int, axis_id: String, new_axis: JoyAxis) -> void:
	if InputManager.get_default_axis_mapping(device, axis_id) != new_axis:
		config.device_info[Input.get_joy_guid(device)].overrides[axis_id] = new_axis

func _on_mouseaim_toggled(button_pressed: bool):
	config.allow_mouse_aim = button_pressed
