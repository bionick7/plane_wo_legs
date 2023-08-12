class_name InputConfig
extends Resource

## Holds shared information about the input configutration
##
## Outside of runtime, input configuration is stored in a json file,
## which can be accessed by this class

const FLAG_FLIGHTSTICK = 0x01
const FLAG_GAMEPAD = 0x02
const FLAG_ANY = FLAG_FLIGHTSTICK | FLAG_GAMEPAD

@export_file("*.json") var save_path: String = "res://data/saves/control_config.json"
@export var reset_to_default_on_startup := false

var device_info := {}
var action_map := {}
var allow_mouse_aim := false

var flightstick_devices := {}
var gamepad_devices := {}

func init() -> void:
	if not FileAccess.file_exists(save_path):
		push_error("Input configuration not found at \"%s\"" % save_path)
		# create empty file
		store_config_file()
	else:
		read_config_file()
		
	if reset_to_default_on_startup:
		_reset_to_default_inputmap()
		store_config_file()
	
	Input.joy_connection_changed.connect(_update_device_connections.unbind(2))
	_update_device_connections()

func is_device_known(device: int) -> bool:
	return device in flightstick_devices or device in gamepad_devices
		
func read_config_file() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	var json := JSON.new()
	var txt := file.get_as_text()
	var error := json.parse(txt)
	if error != OK:
		push_error("JSON Parse Error: %s at line %d when trying to read control_config.json", [json.get_error_message(), json.get_error_line()])
		return
	var content: Dictionary = json.data
	match content:
		{"device_info": {..}, "action_map": {..}, "allow_mouse_aim"}: pass
		_: 
			push_error("Unexpected structure in control_config.json")
			return
	
	device_info = content.device_info
	action_map = content.action_map
	
	allow_mouse_aim = content.allow_mouse_aim
	emit_changed()
	
func store_config_file() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	
	var content = {}
	content.device_info = device_info
	
	content.action_map = action_map
	content.allow_mouse_aim = allow_mouse_aim
	
	file.store_line(JSON.stringify(content, "  "))
	file.flush()

func _update_device_connections() -> void:
	flightstick_devices.clear()
	gamepad_devices.clear()
	for device in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(device)
		if guid in device_info:
			var config: Dictionary = device_info[guid]
			if config.is_flight_stick:
				flightstick_devices[device] = guid
			else:
				gamepad_devices[device] = guid
	emit_changed()
	
func _set_inputmap_from_actionmap() -> void:
	# depends on connected devices
	for action in action_map:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		var event_data = action_map[action]
		for keyboard_code in event_data.get("keyboard", []):
			InputMap.action_add_event(action, str_to_var(keyboard_code))
		for flightstick_code in event_data.get("flightstick", []):
			_set_inputmap_action(flightstick_devices.keys(), action, flightstick_code)
		for gamepad_code in event_data.get("gamepad", []):
			_set_inputmap_action(gamepad_devices.keys(), action, gamepad_code)
	
func _set_inputmap_action(devices: Array, action: String, code: String) -> void:
	var ev = str_to_var(code)
	for gp in devices:
		var ev2 = ev.duplicate()
		ev2.device = gp
		InputMap.action_add_event(action, ev2)
	
func _reset_to_default_inputmap() -> void:
	InputMap.load_from_project_settings()
	for action in InputMap.get_actions():
		if not action.begins_with("ui_") and not action.begins_with("debug_"):
			var events := InputMap.action_get_events(action)
			action_map[action] = {keyboard=[], flightstick=[], gamepad=[]}
			for ev in events:
				if ev is InputEventJoypadButton:
					if ev.device in [0, -1]:
						action_map[action].flightstick.append(var_to_str(ev))
					if ev.device in [1, -1]:
						action_map[action].gamepad.append(var_to_str(ev))
				else:
					action_map[action].keyboard.append(var_to_str(ev))
	emit_changed()
	_set_inputmap_from_actionmap()
	
