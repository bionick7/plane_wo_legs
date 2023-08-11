extends CanvasLayer

const TRACKER_TEMPLATE: PackedScene = preload("res://ui/HUD/tracker.tscn")
const RWR_TRACKER_TEMPLATE: PackedScene = preload("res://ui/HUD/rwr_tracker.tscn")

@export var player: PlayerPlane
@export var main_camera_ref: Node3D

var usable = true

@onready var hud_camera: Camera3D = %HudCamera
@onready var hud_rear_camera: Camera3D = %RearCamera
@onready var main_camera_hinge: Node3D = main_camera_ref.get_node("CameraHinge")
@onready var main_camera: Camera3D = main_camera_ref.get_node("CameraHinge/Camera")
#@onready var rear_camera: Camera3D = main_camera_ref.get_node("%RearCamera")

func _ready():
	await get_tree().process_frame  # Wait for a frame for everything to be set up
	for anchor in get_tree().get_nodes_in_group("TrackingAnchors"):
		_spawn_tracker(anchor)
	
	#hud_rear_camera.fov = rear_camera.fov
	if is_instance_valid(player):
		var flightmodel = player.flight_dynamics.fm
		if flightmodel.stall_enabled:
			_set_aoa_limit(flightmodel.stall_start)
		else:
			_set_aoa_limit(-1)
			
	player.hitbox.set_healthbar($PlayerHP.material)

func _input(event: InputEvent):
	if event.is_action_pressed("toggle_hud"):
		visible = not visible

func _process(dt: float):
	if not is_instance_valid(player):
		hide()
		return
		
	hud_camera.fov = main_camera.fov
	
	var base_rot: Basis = Basis.from_euler(Vector3.UP * PI)
	hud_camera.global_transform.basis = main_camera_hinge.global_transform.basis * base_rot
	
	usable = CloudManager.get_cloud_density(player.global_position) < 0.1
	
	#var up = $VPContainer/VP/HUDControl.up
	var up = player.basis.y
	var viewer_vel = %HUDControl.V
	for tracker in get_tree().get_nodes_in_group("HUDTracker"):
		tracker.player_can_see = usable
		tracker.is_targeted = player.locked_target == tracker.tracking_anchor
		tracker.update_pos(main_camera.global_position, viewer_vel, up)
		
	for rwr_tracker in get_tree().get_nodes_in_group("RWRTracker"):
		rwr_tracker.visible = usable
		rwr_tracker.update_pos(player)

func _is_tracker_valid(tracker: Node) -> bool:
	if not is_instance_valid(tracker):
		return false
	if tracker.is_queued_for_deletion():
		return false
	return true

func _spawn_tracker(tracked: TrackingAnchor):
	if tracked.show_on_hud:
		var tracker = TRACKER_TEMPLATE.instantiate()
		%HUDControl.add_child(tracker)
		tracker.setup(tracked)
	if tracked.show_on_rwr:
		var rwr_tracker = RWR_TRACKER_TEMPLATE.instantiate()
		$RWR.add_child(rwr_tracker)
		rwr_tracker.setup(tracked)
	
func _set_aoa_limit(aoa_degrees: float):
	if aoa_degrees > 0:
		%AoALimitPivot.rotation_degrees = Vector3.RIGHT * aoa_degrees
		%AoALimitPivot/AoALimit.text = "AoA limit: %3.1f" % aoa_degrees
	else:
		%AoALimitPivot.hide()
	%HUDControl/Heading2/BodyCenteredSphere.material.set_shader_parameter("max_aoa_pos", aoa_degrees)

