extends Node

const CONFIG_SAVE_PATH: String = "res://data/saves/control_config.json"

const FLIGHTSTICK_DEFAULTS = {
	yaw = JOY_AXIS_RIGHT_X,
	pitch = JOY_AXIS_LEFT_Y,
	roll = JOY_AXIS_LEFT_X,
	throttle = JOY_AXIS_RIGHT_Y,
}

const GAMEPAD_DEFAULTS = {
	pitch = JOY_AXIS_RIGHT_Y,
	roll = JOY_AXIS_RIGHT_X,
	r_pedal = JOY_AXIS_TRIGGER_LEFT,
	l_pedal = JOY_AXIS_TRIGGER_RIGHT,
	throttle = -1,
}

@export var test_local_multiplayer: bool = true

var pitch_trim = 0

#var flightstick_devices: int = 0x01
#var active_id = 0
#var control = "GAMEPAD"

var flightstick_devices = PackedInt32Array()
var gamepad_devices = PackedInt32Array()

# TODO: load key binding on _ready() from file
# TODO: UI

var flightstick_throttle: float = 0.0
var gamepad_throttle: float = 0.0
var mouse_throttle: float = 0.0

var controls = {
	throttle = 0.0,
	airbrake = 0.0,
	ypr = Vector3.ZERO,
}

var device_info: Dictionary = {}
var control_multiplier = 1.0
var allow_mouse_aim := false

var mouse_drage_ref := Vector2.ZERO

func _ready():
	print(Input.get_joy_guid(0))
	
	if not FileAccess.file_exists(CONFIG_SAVE_PATH):
		# create file
		set_and_store_config({})
	else:
		_read_config_file()
		
	Input.joy_connection_changed.connect(func(_1,_2): _update_device_connections())
	_update_device_connections()
	
	return
	
	$AskInput.input_configured.connect(set_and_store_config)
	if device_info.is_empty():
		$AskInput.popup_centered()

func _process(dt: float):	
	_handle_throttle(dt)
	_handle_ypr(dt)
	
	var brake_gamepad = min(_accumulate_virtual_axis_gp("r_pedal"), _accumulate_virtual_axis_gp("r_pedal"))
	var brake_flightstick = _accumulate_virtual_axis_fs("airbreak")
	controls.airbrake = brake_gamepad + brake_flightstick + Input.get_action_strength("airbrake")
	
func _input(event: InputEvent):
	if event.is_action_pressed("toggle_control_help"):
		$ControlHelp/PanelContainer.visible = not $ControlHelp/PanelContainer.visible
		
	if event is InputEventJoypadMotion:
		var config: Dictionary = device_info[Input.get_joy_guid(event.device)]
		if event.axis == config.axis.get("throttle", FLIGHTSTICK_DEFAULTS.throttle):
			# Because of some input shenanigans, only update on active change
			flightstick_throttle = 0.5 - 0.5 * event.axis_value
			
	mouse_throttle
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			mouse_throttle += 0.1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mouse_throttle -= 0.1
		clamp(mouse_throttle, -flightstick_throttle-gamepad_throttle, 1-flightstick_throttle-gamepad_throttle)
			
	if Input.is_action_just_pressed("mouse_drag"):
		mouse_drage_ref = get_viewport().get_mouse_position()
		
	if event.device >= 0 and event.device not in flightstick_devices and event.device not in gamepad_devices:
		return
		

func _handle_throttle(dt: float) -> void:
	if Input.is_action_pressed("throttle_set"):
		gamepad_throttle = clamp(gamepad_throttle - _accumulate_virtual_axis_gp("throttle") * dt * 5, 0, 1)
	
	controls.throttle = clamp(lerp(controls.throttle, flightstick_throttle + gamepad_throttle + mouse_throttle, smoothstep(0., .5, control_multiplier)), 0.0, 1.0)

func _handle_ypr(dt: float) -> void:
	var flightstick_ypr := Vector3(
		_accumulate_virtual_axis_fs("yaw"),
		-_accumulate_virtual_axis_fs("pitch"),
		_accumulate_virtual_axis_fs("roll")
	)
	var gamepad_ypr := Vector3.ZERO if Input.is_action_pressed("camera_toggle") else Vector3(
		_accumulate_virtual_axis_gp("r_pedal") - _accumulate_virtual_axis_gp("r_pedal"),
		-_accumulate_virtual_axis_gp("pitch"),
		_accumulate_virtual_axis_gp("roll")
	)
	var mouse_ypr := Vector3.ZERO
	#if not Input.is_key_pressed(KEY_CTRL) and Input.is_action_pressed("mouse_drag"):
	if mouse_is_in_aimmode():
		var mouse_delta = get_viewport().get_mouse_position() - get_viewport().size * 0.5
		mouse_delta /= 200
		mouse_ypr = Vector3(
			0,
			clamp(-mouse_delta.y, -1, 1), 
			clamp( mouse_delta.x, -1, 1)
		)
	controls.ypr = (flightstick_ypr + gamepad_ypr + mouse_ypr) * control_multiplier
	
func mouse_is_in_aimmode() -> bool:
	return allow_mouse_aim and not Input.is_key_pressed(KEY_CTRL)
	
func restart() -> void:
	gamepad_throttle = 0
	flightstick_throttle = 0

func get_throttle() -> float:
	return _peer_acc("throttle")
	
func get_yaw_pitch_roll(trimmed: bool) -> Vector3:
	if trimmed:
		return _peer_acc("ypr") + Vector3.UP * pitch_trim
	return _peer_acc("ypr")
	
func get_airbrake() -> float:
	return _peer_acc("airbrake")

func _accumulate_virtual_axis_fs(v_axis_name: String, default: float=0) -> float:
	return _accumulate_virtual_axis(flightstick_devices, v_axis_name, FLIGHTSTICK_DEFAULTS, default)

func _accumulate_virtual_axis_gp(v_axis_name: String, default: float=0) -> float:
	return _accumulate_virtual_axis(gamepad_devices, v_axis_name, GAMEPAD_DEFAULTS, default)

func _accumulate_virtual_axis(devices: PackedInt32Array, v_axis_name: String, defaults: Dictionary, default: float = 0) -> float:
	var res: float = 0
	var devices_connected: int = 0
	for device in devices:
		if not device in Input.get_connected_joypads():
			continue
		var map: Dictionary = device_info.get(Input.get_joy_guid(device), {axis={}}).axis
		var axis: int = map.get(v_axis_name, -1)
		if axis < 0:
			axis = defaults.get(v_axis_name, -1)
		res += Input.get_joy_axis(device, axis)
		devices_connected += 1
	if devices_connected == 0:
		return default
	return clamp(res, -1, 1)
	
func _accumulate_axis(devices: PackedInt32Array, axis: int, default: float = 0) -> float:
	var res: float = 0
	var devices_connected: int = 0
	for device in devices:
		if device in Input.get_connected_joypads():
			res += Input.get_joy_axis(device, axis)
			devices_connected += 1
	if devices_connected == 0:
		return default
	return clamp(res, -1, 1)

func set_vibration(certainty: float) -> void:
	if certainty > 0.6:
		for gamepad in gamepad_devices:
			Input.start_joy_vibration(gamepad, 0, 0.5, 1)
	if certainty < 0.5:
		for gamepad in gamepad_devices:
			Input.stop_joy_vibration(gamepad)

func _peer_acc(key: String) -> Variant:
	return controls[key]

#func ask_input_config() -> Dictionary:
#	
#	var input_config

func _update_device_connections() -> void:
	flightstick_devices.clear()
	gamepad_devices.clear()
	for device in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(device)
		if guid in device_info:
			var config: Dictionary = device_info[guid]
			if config.is_flight_stick:
				flightstick_devices.append(device)
			else:
				gamepad_devices.append(device)
	
func set_and_store_config(config: Dictionary) -> void:
	device_info = config
	_update_device_connections()
	_store_config_file()
	
func _read_config_file() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_SAVE_PATH, FileAccess.READ)
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
	
	for action in content.action_map:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for event in content.action_map[action]:
			InputMap.action_add_event(action, str_to_var(event))
			
	allow_mouse_aim = content.allow_mouse_aim
	
func _store_config_file() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_SAVE_PATH, FileAccess.WRITE)
	
	var content = {}
	content.device_info = device_info
	
	var action_map = {}
	for action in InputMap.get_actions():
		if not action.begins_with("ui_"):
			action_map[action] = InputMap.action_get_events(action).map(func(x): return var_to_str(x))
	content.action_map = action_map
	content.allow_mouse_aim = allow_mouse_aim
	
	file.store_line(JSON.stringify(content, " "))
	file.flush()
	
