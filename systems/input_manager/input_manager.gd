extends Node

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
	throttle = JOY_AXIS_LEFT_Y,
}

@export var config: InputConfig

var pitch_trim = 0

var flightstick_throttle: float = 0.0
var gamepad_throttle: float = 0.0
var mouse_throttle: float = 0.0

var controls = {
	throttle = 0.0,
	airbrake = 0.0,
	ypr = Vector3.ZERO,
}

var mouse_drage_ref := Vector2.ZERO

var control_multiplier = 1.0

func _ready():
	config.init()

func _process(dt: float):
	_handle_throttle(dt)
	_handle_ypr(dt)
	
	var brake_gamepad = min(accumulate_virtual_axis_gp("r_pedal"), accumulate_virtual_axis_gp("l_pedal"))
	var brake_flightstick = accumulate_virtual_axis_fs("airbreak")
	controls.airbrake = brake_gamepad + brake_flightstick + Input.get_action_strength("airbrake")
	
func _input(event: InputEvent):
	if event.is_action_pressed("toggle_control_help"):
		$ControlHelp/PanelContainer.visible = not $ControlHelp/PanelContainer.visible
		
	if event is InputEventJoypadMotion and event.device in config.flightstick_devices:
		var info: Dictionary = config.device_info[config.flightstick_devices[event.device]]
		if info.is_flight_stick and event.axis == info.overrides.get("throttle", FLIGHTSTICK_DEFAULTS.throttle):
			# Because of some input shenanigans, only update on active change
			flightstick_throttle = 0.5 - 0.5 * event.axis_value
			
	if event is InputEventMouseButton and fly_by_mouse():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			mouse_throttle += 0.1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			mouse_throttle -= 0.1
		mouse_throttle = clampf(mouse_throttle, -flightstick_throttle-gamepad_throttle, 1-flightstick_throttle-gamepad_throttle)
			
	if Input.is_action_just_pressed("mouse_drag") and fly_by_mouse():
		mouse_drage_ref = get_viewport().get_mouse_position()
		
	if event.device >= 0 and not config.device_known(event.device):
		return
		

func _handle_throttle(dt: float) -> void:
	if true: #Input.is_action_pressed("throttle_set"):
		var axis_read := accumulate_virtual_axis_gp("throttle")
		if abs(axis_read) < 0.1: axis_read = 0.0
		axis_read = signf(axis_read) * absf(axis_read) ** 3.0
		gamepad_throttle = gamepad_throttle - axis_read * dt * 5
		gamepad_throttle = clampf(gamepad_throttle, -flightstick_throttle-mouse_throttle, 1-flightstick_throttle-mouse_throttle)
	
	controls.throttle = clampf(lerp(controls.throttle, flightstick_throttle + gamepad_throttle + mouse_throttle, smoothstep(0., .5, control_multiplier)), 0.0, 1.0)

func _handle_ypr(dt: float) -> void:
	var flightstick_ypr := Vector3(
		accumulate_virtual_axis_fs("yaw"),
		-accumulate_virtual_axis_fs("pitch"),
		accumulate_virtual_axis_fs("roll")
	)
	var gamepad_ypr := Vector3.ZERO if Input.is_action_pressed("camera_toggle") else Vector3(
		accumulate_virtual_axis_gp("l_pedal") - accumulate_virtual_axis_gp("r_pedal"),
		-accumulate_virtual_axis_gp("pitch"),
		accumulate_virtual_axis_gp("roll")
	)
	gamepad_ypr.y = signf(gamepad_ypr.y) * absf(gamepad_ypr.y) ** 1.3
	gamepad_ypr.x = signf(gamepad_ypr.x) * absf(gamepad_ypr.x) ** 2.5
	var mouse_ypr := Vector3.ZERO
	#if not Input.is_key_pressed(KEY_CTRL) and Input.is_action_pressed("mouse_drag"):
	if fly_by_mouse():
		var mouse_delta = get_viewport().get_mouse_position() - get_viewport().size * 0.5
		mouse_delta /= 200
		mouse_ypr = Vector3(
			0,
			clamp(-mouse_delta.y, -1, 1), 
			clamp( mouse_delta.x, -1, 1)
		)
	controls.ypr = (flightstick_ypr + gamepad_ypr + mouse_ypr) * control_multiplier
	
	
func fly_by_mouse() -> bool:
	return config.allow_mouse_aim and not Input.is_key_pressed(KEY_CTRL)
	
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

func accumulate_virtual_axis_fs(v_axis_name: String, default: float=0) -> float:
	return accumulate_virtual_axis(config.flightstick_devices, v_axis_name, FLIGHTSTICK_DEFAULTS, default)

func accumulate_virtual_axis_gp(v_axis_name: String, default: float=0) -> float:
	return accumulate_virtual_axis(config.gamepad_devices, v_axis_name, GAMEPAD_DEFAULTS, default)

func accumulate_virtual_axis(devices: Dictionary, v_axis_name: String, defaults: Dictionary, default: float = 0) -> float:
	var res: float = 0
	var devices_connected: int = 0
	for device in devices:
		if not device in Input.get_connected_joypads():
			continue
		var map: Dictionary = config.device_info.get(devices[device], {overrides={}}).overrides
		var axis: int = map.get(v_axis_name, -1)
		if axis < 0:
			axis = defaults.get(v_axis_name, -1)
		res += Input.get_joy_axis(device, axis)
		devices_connected += 1
	if devices_connected == 0:
		return default
	return clamp(res, -1, 1)

func accumulate_axis_fs(axis: int, default: float=0) -> float:
	return accumulate_axis(config.flightstick_devices, axis, default)

func accumulate_axis_gp(axis: int, default: float=0) -> float:
	return accumulate_axis(config.gamepad_devices, axis, default)

func accumulate_axis(devices: Dictionary, axis: int, default: float = 0) -> float:
	var res: float = 0
	var devices_connected: int = 0
	for device in devices:
		if not device in Input.get_connected_joypads():
			continue
		res += Input.get_joy_axis(device, axis)
		devices_connected += 1
	if devices_connected == 0:
		return default
	return clamp(res, -1, 1)

func set_vibration(certainty: float) -> void:
	if certainty > 0.6:
		for gamepad in config.gamepad_devices:
			Input.start_joy_vibration(gamepad, 0, 0.5, 1)
	if certainty < 0.5:
		for gamepad in config.gamepad_devices:
			Input.stop_joy_vibration(gamepad)

func _peer_acc(key: String) -> Variant:
	return controls[key]
