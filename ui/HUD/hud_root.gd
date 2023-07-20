extends CanvasLayer

const TRACKER_TEMPLATE: PackedScene = preload("res://ui/HUD/tracker.tscn")

@export var player: PlayerPlane
@export var main_camera_hinge: Node3D

var trackers = []

@onready var hud_camera: Camera3D = $VPContainer/VP/HudCam
@onready var main_camera: Camera3D = main_camera_hinge.get_node("Camera")

func _ready():
	hud_camera.fov = main_camera.fov

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_hud"):
		visible = not visible

func _process(dt: float):
	var base_rot: Basis = Basis.from_euler(Vector3.UP * PI)
	hud_camera.global_transform.basis = main_camera_hinge.global_transform.basis * base_rot
	
	var up = $VPContainer/VP/HUDControl.up
	var viewer_vel = $VPContainer/VP/HUDControl.V
	for tracker in trackers:
		tracker.update_pos(main_camera.global_position, viewer_vel, up)

func spawn_tracker(tracked: Node3D):
	var tracker = TRACKER_TEMPLATE.instantiate()
	tracker.setup(tracked)
	$VPContainer/VP/HUDControl.add_child(tracker)
	trackers.append(tracker)
	
func remove_tracker(tracked: Node3D):
	for tracker in trackers:
		if tracker.tracking_agent == tracked:
			trackers.erase(tracker)
