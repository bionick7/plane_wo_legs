class_name PlayerCamera
extends Node3D

@export var tracking_plane: PlaneInterface

@export var camera_yaw_rate: float = 1.0
@export var camera_pitch_rate: float = 1.0
@export_range(0, 0.1) var zoom_factor: float = 0.03

var joypad_dragging = false
var mouse_dragging = false
var mouse_null_pos = Vector2.ZERO
var euler_null = Vector3.ZERO

@onready var camera_hinge = $CameraHinge
@onready var camera = $CameraHinge/Camera

@onready var tracking_index = get_tree().get_nodes_in_group("Planes").find(tracking_plane)

func _process(dt):
	if not get_tree().has_group("Planes"):
		return
	if not is_instance_valid(tracking_plane):
		_cycle_to(0)
		
	global_transform = tracking_plane.global_transform
	if _handle_target_tracking():
		return
	_handle_dragging(dt)

func _input(event):
	if event is InputEventMouseButton:
		_handle_mousebutton(event)
	if event.is_action_pressed("camera_toggle"):
		joypad_dragging = true
	if event.is_action_released("camera_toggle"):
		joypad_dragging = false
		euler_null = camera_hinge.rotation
	if event.is_action_pressed("camera_reset") and joypad_dragging:
		camera_hinge.rotation = Vector3.ZERO
		euler_null = camera_hinge.rotation
		joypad_dragging = false
	if event.is_action_pressed("ui_left"):
		_cycle_to(1)
	if event.is_action_released("ui_right"):
		_cycle_to(-1)

func _get_target() -> TrackingAnchor:
	if tracking_plane is PlayerPlane:
		return tracking_plane.locked_target
	if tracking_plane is NPCPlane:
		return tracking_plane.target
	return null

func _cycle_to(offset: int) -> void:
	tracking_index = (tracking_index + offset) % get_tree().get_nodes_in_group("Planes").size()
	tracking_plane = get_tree().get_nodes_in_group("Planes")[tracking_index]
	

func _handle_target_tracking() -> bool:
	if not Input.is_action_pressed("camera_track_plane"):
		return false
	if not is_instance_valid(_get_target()):
		return false
	if _get_target().is_hidden() or tracking_plane.is_hidden():
		return false
	basis = NPCUtility.basis_align(
		(_get_target().global_position - global_position).normalized(), 
		basis.y, true)
	return true
	
func _handle_dragging(dt: float) -> void:
	var rotation_delta = Vector2.ZERO
	if joypad_dragging:
		rotation_delta = Vector2(
			InputManager.accumulated_gamepad_axis(JOY_AXIS_RIGHT_X),
			InputManager.accumulated_gamepad_axis(JOY_AXIS_RIGHT_Y)
		)
		camera_hinge.rotation += Vector3(
			rotation_delta.y * camera_pitch_rate,
			-rotation_delta.x * camera_yaw_rate,
			0
		) * dt
	if mouse_dragging:
		rotation_delta = (get_window().get_mouse_position() - mouse_null_pos) * 1e-3
		camera_hinge.rotation = euler_null + Vector3(
			rotation_delta.y * camera_pitch_rate,
			-rotation_delta.x * camera_yaw_rate,
			0
		)

func _handle_mousebutton(event: InputEventMouseButton) -> void:
	if InputManager.mouse_is_in_aimmode():
		return
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				mouse_dragging = true
				mouse_null_pos = get_window().get_mouse_position()
			else:
				mouse_dragging = false
				euler_null = camera_hinge.rotation
		MOUSE_BUTTON_WHEEL_UP:
			camera.position /= (1 + zoom_factor)
		MOUSE_BUTTON_WHEEL_DOWN:
			camera.position *= (1 + zoom_factor)
