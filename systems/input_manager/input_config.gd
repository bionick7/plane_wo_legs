class_name InputConfig
extends Resource

const FLAG_FLIGHTSTICK = 0x01
const FLAG_GAMEPAD = 0x02
const FLAG_ANY = FLAG_FLIGHTSTICK | FLAG_GAMEPAD

@export_file("*.json") var save_path: String = "res://data/saves/control_config.json"

var device_info := {}
var action_map := {}
var allow_mouse_aim := false

var flightstick_devices := {}
var gamepad_devices := {}

func init() -> void:
	if not FileAccess.file_exists(save_path):
		# create file
		set_and_store_config({})
	else:
		_read_config_file()
		
	_reset_to_default_inputmap()
	_store_config_file()
	
	Input.joy_connection_changed.connect(_update_device_connections.unbind(2))
	_update_device_connections()

func device_known(device: int) -> bool:
	return device in flightstick_devices or device in gamepad_devices
	
func set_and_store_config(config: Dictionary) -> void:
	device_info = config
	_update_device_connections()
	_store_config_file()

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

func _encode_event_from_inputmap(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var filter: int = [FLAG_ANY, FLAG_FLIGHTSTICK, FLAG_GAMEPAD, 0,0,0,0,0,0][event.device + 1]  # Sorry
		return {
			filter = filter,
			code = var_to_str(event)
		}
	return { code = var_to_str(event) }
	
func _decode_events(data: Dictionary) -> Array[InputEvent]:
	var ev: InputEvent = str_to_var(data.code)
	if not ev is InputEventJoypadButton and not ev is InputEventJoypadMotion:
		return [ev]
	var res: Array[InputEvent] = []
	var filter: int = data.get("filter", FLAG_ANY)
	if filter & FLAG_FLIGHTSTICK:
		for fs in flightstick_devices:
			var ev2 = ev.duplicate()
			ev2.device = fs
			res.append(ev2)
	if filter & FLAG_GAMEPAD:
		for gp in gamepad_devices:
			var ev2 = ev.duplicate()
			ev2.device = gp
			res.append(ev2)
	return res
	
func _set_inputmap_from_actionmap() -> void:
	# depends on connected devices
	for action in action_map:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for event_data in action_map[action]:
			for event in _decode_events(event_data):
				InputMap.action_add_event(action, event)
	
func _reset_to_default_inputmap() -> void:
	InputMap.load_from_project_settings()
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"):
			action_map[action] = InputMap.action_get_events(action).map(_encode_event_from_inputmap)
	emit_changed()
	_set_inputmap_from_actionmap()
		
func _read_config_file() -> void:
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
	
func _store_config_file() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	
	var content = {}
	content.device_info = device_info
	
	content.action_map = action_map
	content.allow_mouse_aim = allow_mouse_aim
	
	file.store_line(JSON.stringify(content, "  "))
	file.flush()
