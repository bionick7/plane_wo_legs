class_name ControlsOptionPanel__
extends Control

const MAX_CONNECTED_DEVICES: int = 4
const FLIGHTSTICK_OPTION: int = 0
const GAMEPAD_OPTION: int = 1

var devices := PackedInt32Array()

@onready var config := InputManager.config
@onready var device_labels: Array = range(MAX_CONNECTED_DEVICES).map(
	func(x): return get_node("%%DeviceLabel%d" % x)
)

@onready var device_switches: Array = range(MAX_CONNECTED_DEVICES).map(
	func(x): return get_node("%%DeviceSwitch%d" % x)
)

func _ready():
	config.changed.connect(_update_menu)
	_update_menu()

func _update_menu() -> void:
	# Needs to update on reconnect
	devices.clear()
	devices.append_array(config.flightstick_devices.keys())
	devices.append_array(config.gamepad_devices.keys())
	for i in range(devices.size(), MAX_CONNECTED_DEVICES):
		devices.append(-1)
	devices.resize(MAX_CONNECTED_DEVICES)
	
	for i in range(MAX_CONNECTED_DEVICES):
		device_switches[i].disabled = devices[i] < 0
		if devices[i] < 0:
			device_labels[i].text = " --- "
			device_switches[i].selected = -1
			continue
		device_labels[i].text = Input.get_joy_name(devices[i])
		device_labels[i].tooltip_text = Input.get_joy_guid(devices[i])
		if devices[i] in config.flightstick_devices:
			device_switches[i].selected = FLIGHTSTICK_OPTION
		elif devices[i] in config.gamepad_devices:
			device_switches[i].selected = GAMEPAD_OPTION
	
func _on_changed() -> void:
	pass

func _on_device_switched(option: int, device: int) -> void:
	if devices[device] < 0:
		return
	config.device_info[Input.get_joy_guid(device)].is_flight_stick = option == FLIGHTSTICK_OPTION
	config._update_device_connections()
