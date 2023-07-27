extends Node3D

@export var camera_yaw_rate = 1
@export var camera_pitch_rate = 1
@export_range(0, 0.1) var zoom_factor = 0.03

var joypad_dragging = false
var mouse_dragging = false
var mouse_null_pos = Vector2.ZERO
var euler_null = Vector3.ZERO

@onready var camera = $Camera

func _process(dt):
	var rotation_delta = Vector2.ZERO
	if joypad_dragging:
		rotation_delta = Vector2(
			InputManager.accumulated_gamepad_axis(JOY_AXIS_RIGHT_X),
			InputManager.accumulated_gamepad_axis(JOY_AXIS_RIGHT_Y)
		)
		rotation += Vector3(
			rotation_delta.y * camera_pitch_rate,
			-rotation_delta.x * camera_yaw_rate,
			0
		) * dt
	if mouse_dragging:
		rotation_delta = (get_window().get_mouse_position() - mouse_null_pos) * 1e-3
		rotation = euler_null + Vector3(
			rotation_delta.y * camera_pitch_rate,
			-rotation_delta.x * camera_yaw_rate,
			0
		)

func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.is_pressed():
					mouse_dragging = true
					mouse_null_pos = get_window().get_mouse_position()
				else:
					mouse_dragging = false
					euler_null = rotation
			MOUSE_BUTTON_WHEEL_UP:
				camera.position /= (1 + zoom_factor)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.position *= (1 + zoom_factor)
	if event.is_action_pressed("camera_toggle"):
		joypad_dragging = true
	if event.is_action_released("camera_toggle"):
		joypad_dragging = false
		euler_null = rotation
	if event.is_action_pressed("camera_reset") and joypad_dragging:
		rotation = Vector3.ZERO
		euler_null = rotation
		joypad_dragging = false
