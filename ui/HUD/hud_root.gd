extends CanvasLayer

const TRACKER_TEMPLATE: PackedScene = preload("res://ui/HUD/tracker.tscn")

@export var player: PlayerPlane
@export var main_camera_hinge: Node3D

var trackers = []

@onready var hud_camera: Camera3D = $VPContainer/VP/HudCam
@onready var main_camera: Camera3D = main_camera_hinge.get_node("Camera")

func _ready():
	hud_camera.fov = main_camera.fov
	if is_instance_valid(player):
		var flightmodel = player.flight_dynamics.fm
		if flightmodel.stall_enabled:
			_set_aoa_limit(flightmodel.stall_start)
		else:
			_set_aoa_limit(-1)

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_hud"):
		visible = not visible

func _process(dt: float):
	var base_rot: Basis = Basis.from_euler(Vector3.UP * PI)
	hud_camera.global_transform.basis = main_camera_hinge.global_transform.basis * base_rot
	
	var up = $VPContainer/VP/HUDControl.up
	var viewer_vel = $VPContainer/VP/HUDControl.V
	for tracker in trackers:
		tracker.draw_preaim = player.locked_target == tracker.tracking_agent
		tracker.update_pos(main_camera.global_position, viewer_vel, up)

func spawn_tracker(tracked: PlaneInterface):
	var tracker = TRACKER_TEMPLATE.instantiate()
	tracker.setup(tracked)
	$VPContainer/VP/HUDControl.add_child(tracker)
	trackers.append(tracker)
	
func remove_tracker(tracked: PlaneInterface):
	for tracker in trackers:
		if tracker.tracking_agent == tracked:
			tracker.queue_free()
			trackers.erase(tracker)

func _set_aoa_limit(aoa_degrees: float):
	if aoa_degrees > 0:
		$VPContainer/VP/HUDControl/Heading2/BodyCenteredSphere/AoALimitPivot.rotation_degrees = Vector3.RIGHT * aoa_degrees
		$VPContainer/VP/HUDControl/Heading2/BodyCenteredSphere/AoALimitPivot/AoALimit.text = "AoA limit: %3.1f" % aoa_degrees
	else:
		$VPContainer/VP/HUDControl/Heading2/BodyCenteredSphere/AoALimitPivot.hide()
	$VPContainer/VP/HUDControl/Heading2/BodyCenteredSphere.material.set_shader_parameter("max_aoa_pos", aoa_degrees)
