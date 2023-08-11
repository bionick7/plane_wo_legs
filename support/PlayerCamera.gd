class_name PlayerCamera
extends Node3D

enum View { BACK, FRONT, TOP, BOTTOM, LEFT, RIGHT }

@export var tracking_plane: PlaneInterface

@export var camera_yaw_rate: float = 1.0
@export var camera_pitch_rate: float = 1.0
@export_range(0, 720, 1, "suffix:°/s", "radians") var sideview_rotational_rate: float = 8.0
@export_range(0, 720, 1, "suffix:s") var fov_transition_time: float = 2.0
@export_range(0, 180, 1, "degrees") var max_fov: float = 45.0
@export_range(0, 180, 1, "degrees") var min_fov: float = 75.0
@export_range(0, 0.1) var zoom_factor: float = 0.03

var joypad_dragging := false
var mouse_dragging := false
var track_plane := false
var mouse_null_pos := Vector2.ZERO
var euler_null := Vector3.ZERO

var tgt_view := View.FRONT
var is_view_transitioning := false 
var current_view := View.FRONT

var sideview_basis := Basis.IDENTITY
var sideview_basis_array: Array[Basis] = [
	Basis.looking_at(Vector3.BACK,		Vector3.UP),
	Basis.IDENTITY,
	Basis.looking_at(Vector3.UP,		Vector3.BACK),
	Basis.looking_at(Vector3.DOWN,		Vector3.FORWARD),
	Basis.looking_at(Vector3.RIGHT,		Vector3.UP),
	Basis.looking_at(Vector3.LEFT,		Vector3.UP),
]

@onready var camera_hinge: Node3D = $CameraHinge
@onready var camera: Camera3D = $CameraHinge/Camera
@onready var tracking_index := get_tree().get_nodes_in_group("Planes").find(tracking_plane)
@onready var tgt_fov := camera.fov

func  _ready():
	var tgt_fov := min_fov if is_instance_valid(_get_target()) else max_fov
	camera.fov = tgt_fov

func _process(dt):
	if not get_tree().has_group("Planes"):
		return
	if not is_instance_valid(tracking_plane):
		_cycle_to(0)
		
	global_transform = tracking_plane.global_transform * Transform3D(sideview_basis, Vector3.ZERO)
	
	var tgt_fov := min_fov if is_instance_valid(_get_target()) else max_fov
	var fov_transition_rate := absf(max_fov - min_fov) / fov_transition_time
	camera.fov = move_toward(camera.fov, tgt_fov, fov_transition_rate * dt)
	
	if _handle_target_tracking():
		return
	_handle_sideviews(dt)
	_handle_dragging(dt)

func _input(event):
	if event is InputEventMouseButton:
		_handle_mousebutton(event)
	elif event.is_action_pressed("camera_toggle"):
		joypad_dragging = true
	elif event.is_action_released("camera_toggle"):
		joypad_dragging = false
		euler_null = camera_hinge.rotation
	elif event.is_action_pressed("camera_reset") and joypad_dragging:
		camera_hinge.rotation = Vector3.ZERO
		euler_null = camera_hinge.rotation
		joypad_dragging = false
	elif event.is_action_pressed("ui_left"):
		_cycle_to(1)
	elif event.is_action_released("ui_right"):
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
	#if not Input.is_action_pressed("camera_track_plane"):
	if not Input.is_action_pressed("camera_top") or not Input.is_action_pressed("camera_right"):
		return false
	if not is_instance_valid(_get_target()):
		return false
	if _get_target().is_hidden() or tracking_plane.is_hidden():
		return false
	basis = NPCUtility.basis_align(
		(_get_target().global_position - global_position).normalized(), 
		basis.y, true)
	return true

func _handle_sideviews(dt: float) -> void:
	if Input.is_action_pressed("camera_left") and Input.is_action_pressed("camera_bottom"):
		tgt_view = View.BACK
	elif Input.is_action_pressed("camera_top"):
		tgt_view = View.TOP
	elif Input.is_action_pressed("camera_bottom"):
		tgt_view = View.BOTTOM
	elif Input.is_action_pressed("camera_left"):
		tgt_view = View.LEFT
	elif Input.is_action_pressed("camera_right"):
		tgt_view = View.RIGHT
	else:
		tgt_view = View.FRONT
	
	if tgt_view == current_view and not is_view_transitioning:
		return
	
	var tgt_sideview_basis = sideview_basis_array[tgt_view]
	var d_rot := (tgt_sideview_basis * sideview_basis.inverse()).get_rotation_quaternion()
	var d_rot_angle := d_rot.get_angle()
	var d_rot_axis := d_rot.get_axis()
	
	var delta_angle := sideview_rotational_rate * dt  # 5 rad/s
	
	is_view_transitioning = d_rot_angle > delta_angle
	if is_view_transitioning:
		sideview_basis = sideview_basis.rotated(d_rot_axis, delta_angle)
	else:
		sideview_basis = tgt_sideview_basis
		current_view = tgt_view
	
func _handle_dragging(dt: float) -> void:
	var rotation_delta = Vector2.ZERO
	if joypad_dragging:
		rotation_delta = Vector2(
			InputManager.accumulate_axis_gp(JOY_AXIS_RIGHT_X),
			InputManager.accumulate_axis_gp(JOY_AXIS_RIGHT_Y)
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
	if InputManager.fly_by_mouse():
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
