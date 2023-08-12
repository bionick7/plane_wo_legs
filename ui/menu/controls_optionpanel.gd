class_name ControlsOptionPanel
extends Control

const MAX_CONNECTED_DEVICES: int = 4

const FLIGHTSTICK_OPTION: int = 0
const GAMEPAD_OPTION: int = 1

var devices := PackedInt32Array()

var current_device_index: int = 0

@onready var config := InputManager.config
@onready var device_selector: OptionButton = %DeviceSelector

func _ready():
	config.changed.connect(_update_menu)
	_update_menu()

func _update_menu() -> void:
	# Needs to update on reconnect
	devices.clear()
	devices.append_array(config.flightstick_devices.keys())
	devices.append_array(config.gamepad_devices.keys())
	device_selector.clear()
	for device in devices:
		device_selector.add_item(Input.get_joy_name(device))
	
	_on_selected_device_changed(current_device_index)
	
func _on_changed() -> void:
	pass

func _on_device_switched(option: int, device: int) -> void:
	if devices[device] < 0:
		return
	config.device_info[Input.get_joy_guid(device)].is_flight_stick = option == FLIGHTSTICK_OPTION
	config._update_device_connections()

func _on_selected_device_changed(new_index: int) -> void:
	current_device_index = new_index
	var current_device := devices[current_device_index]
	(%DeviceOptionTabs as TabContainer).current_tab = (FLIGHTSTICK_OPTION
			if current_device in config.flightstick_devices else GAMEPAD_OPTION)
