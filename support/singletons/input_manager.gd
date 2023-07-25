extends Node

const CONFIG_SAVE_PATH: String = "res://data/saves/control_config.json"

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
var broken: bool = false

var controls = {
	throttle = 0.0,
	airbrake = 0.0,
	ypr = Vector3.ZERO,
}

var peer_controls = {}
var local_input_config: Array[Dictionary] = []

var control_multiplier = 1.0

signal networked_input(origin: int, event_name: String, is_pressed: bool)

func _ready():
	if not FileAccess.file_exists(CONFIG_SAVE_PATH):
		# create file
		set_and_store_config([])
	else:
		var file: FileAccess = FileAccess.open(CONFIG_SAVE_PATH, FileAccess.READ)
		var content = JSON.parse_string(file.get_as_text())
		local_input_config.clear()
		if content != null:
			for i in range(content.size()):
				local_input_config.append(content[i])
		read_input_config()
	
	multiplayer.connected_to_server.connect(on_multiplayer_connect)
	$AskInput.input_configured.connect(set_and_store_config)
	if not test_local_multiplayer and local_input_config.is_empty():
		$AskInput.popup_centered()

func _process(dt: float):
	if broken:
		controls.throttle = 0
		#controls.ypr = Vector3.ZERO
		#controls.direction = Vector2.ZERO
		#controls.airbrake = 0
		return
		
	# ============== THROTTLE ============== 
	
	if Input.is_action_pressed("throttle_set"):
		gamepad_throttle = clamp(gamepad_throttle - accumulate_axis(gamepad_devices, JOY_AXIS_LEFT_Y) * dt * 5, 0, 1)
	
	controls.throttle = lerp(controls.throttle, flightstick_throttle + gamepad_throttle, smoothstep(0., .5, control_multiplier))
	
	# ============== YAW PITCH ROLL ============== 
	
	var flightstick_ypr = Vector3(
		accumulate_axis(flightstick_devices, JOY_AXIS_RIGHT_X),
		-accumulate_axis(flightstick_devices, JOY_AXIS_LEFT_Y),
		accumulate_axis(flightstick_devices, JOY_AXIS_LEFT_X)
	)
	var gamepad_ypr = Vector3.ZERO if Input.is_action_pressed("camera_toggle") else Vector3(
		accumulate_axis(gamepad_devices, JOY_AXIS_TRIGGER_RIGHT) - accumulate_axis(gamepad_devices, JOY_AXIS_TRIGGER_LEFT),
		-accumulate_axis(gamepad_devices, JOY_AXIS_RIGHT_Y),
		accumulate_axis(gamepad_devices, JOY_AXIS_RIGHT_X)
	)
	controls.ypr = (flightstick_ypr + gamepad_ypr) * control_multiplier
	
	# ============== OTHER ============== 
	var brake_gamepad = min(accumulate_axis(gamepad_devices, JOY_AXIS_TRIGGER_RIGHT), accumulate_axis(gamepad_devices, JOY_AXIS_TRIGGER_LEFT))
	controls.airbrake = brake_gamepad + Input.get_action_strength("airbrake")
	
	if multiplayer.has_multiplayer_peer():
		share_controls.rpc(multiplayer.get_unique_id(), controls)

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_control_help"):
		$ControlHelp/PanelContainer.visible = not $ControlHelp/PanelContainer.visible
		
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_Y and event.device in flightstick_devices:
			# Because of some input shenanigans, only update on active change
			flightstick_throttle = 0.5 - 0.5 * event.axis_value
		
	if event.device >= 0 and event.device not in flightstick_devices and event.device not in gamepad_devices:
		return
	if not multiplayer.has_multiplayer_peer():
		return

@rpc("unreliable", "any_peer")
func share_controls(origin: int, p_controls: Dictionary) -> void:
	peer_controls[origin] = p_controls

@rpc("reliable", "any_peer")
func share_input(origin: int, event_name: String, is_pressed: bool):
	#printt(multiplayer.get_unique_id(), event_name, is_pressed)
	emit_signal("networked_input", origin, event_name, is_pressed)

func restart() -> void:
	broken = false
	gamepad_throttle = 0
	flightstick_throttle = 0

func get_throttle() -> float:
	return peer_acc("throttle")
	
func get_yaw_pitch_roll(trimmed: bool) -> Vector3:
	if trimmed:
		return peer_acc("ypr") + Vector3.UP * pitch_trim
	return peer_acc("ypr")
	
func get_airbrake() -> float:
	return peer_acc("airbrake")

func accumulated_gamepad_axis(axis: int, default: float = 0) -> float:
	return accumulate_axis(gamepad_devices, axis, default)
	
func accumulated_flightstick_axis(axis: int, default: float = 0) -> float:
	return accumulate_axis(flightstick_devices, axis, default)
	
func accumulate_axis(devices: PackedInt32Array, axis: int, default: float = 0) -> float:
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

func peer_acc(key: String) -> Variant:
	var res: Variant = controls[key]
	for peer_id in multiplayer.get_peers():
		if peer_id in peer_controls and key in peer_controls[peer_id]:
			res += peer_controls[peer_id][key]
	return res

#func ask_input_config() -> Dictionary:
#	
#	var input_config

func read_input_config() -> void:
	flightstick_devices.clear()
	gamepad_devices.clear()
	for device in Input.get_connected_joypads():
		for config in local_input_config:
			if config.name == Input.get_joy_name(device):
				if config.is_flight_stick:
					flightstick_devices.append(device)
				else:
					gamepad_devices.append(device)
	
func set_and_store_config(config: Array[Dictionary]):
	var file: FileAccess = FileAccess.open(CONFIG_SAVE_PATH, FileAccess.WRITE)
	local_input_config = config
	read_input_config()
	file.store_line(JSON.stringify(local_input_config, " "))
	
func on_multiplayer_connect():
	if not test_local_multiplayer:
		return
	if multiplayer.is_server():
		local_input_config = [{
			name = "Thrustmaster T.Flight Stick X",
			is_flight_stick = false
		}]
	else:
		local_input_config = [{
			name = "PS4 Controller",
			is_flight_stick = true
		}]
	read_input_config()
