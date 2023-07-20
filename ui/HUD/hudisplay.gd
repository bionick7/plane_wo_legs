extends Node3D

@export var pitch_yaw_roll_display_sensitivity: Vector3 = Vector3(20, 20, 2)
@export_enum("cylinder", "flat") var coordinates = 0
@export_enum("m/s", "kts") var speed_units = 0

@onready var player: PlayerPlane = get_node("../../..").player
@onready var input_manager = $"/root/InputManager"
@onready var throttle_slider = get_node("../../../UI/ThrottleSlider")

var V = Vector3.ZERO
var target_basis = Basis.IDENTITY
var up = Vector3.UP


func _get_signed_angle_on_plane(from: Vector3, to: Vector3, plane: Vector3) -> float:
	var from_projected = from - from.project(plane)
	var to_projected = to - to.project(plane)
	return from_projected.signed_angle_to(to_projected, plane)

func _get_basis_transform(from: Vector3, to: Vector3) -> Basis:
	return Basis(from.cross(to).normalized(), from.angle_to(to))

func _process(dt: float):
	if not is_instance_valid(player):
		hide()
		return
		
	V = player.velocity
		
	if coordinates == 0:
		up = -(player.global_position - Vector3.BACK * player.global_position.z).normalized()
	else:
		up = Vector3.DOWN
	target_basis = player.global_transform.basis
	var heading_horizontal = -_get_signed_angle_on_plane(
		target_basis * Vector3.FORWARD,
		Vector3.FORWARD,
		up
	)
	var heading_vertical = _get_signed_angle_on_plane(
		target_basis * Vector3.FORWARD,
		Vector3.FORWARD.rotated(up, heading_horizontal),
		Vector3.RIGHT.rotated(up, heading_horizontal)
	)
		
	var proj_forward = (target_basis.z - target_basis.z.project(up)).normalized()
	$HUDSphere.basis = Basis(up.cross(proj_forward), up, proj_forward)
	
	$Heading2.transform.basis = target_basis
	
	var null_rot = Vector3(0, -PI/2, 0)
	
	$Heading.transform.basis = target_basis
	var roll = _get_signed_angle_on_plane(target_basis.y, up, target_basis.z)
	$Heading.rotate_object_local(Vector3.FORWARD, -roll)
	
	if "velocity" in player and player.velocity != null and not \
		is_zero_approx(player.velocity.length_squared()):
		$Velocity.transform.basis = _get_basis_transform(Vector3.RIGHT, player.velocity)
		$Velocity.show()
	else:
		$Velocity.hide()
	
	if input_manager != null:
		var ypr = input_manager.get_yaw_pitch_roll(true)
		var trim = ypr - input_manager.get_yaw_pitch_roll(false)
		var throttle = input_manager.get_throttle()
		$Heading2/Yaw.rotation = null_rot + Vector3.DOWN * ypr.x * pitch_yaw_roll_display_sensitivity.y
		$Heading2/Pitch.rotation = null_rot + Vector3.FORWARD * ypr.y * pitch_yaw_roll_display_sensitivity.x
		$Heading2/Roll.rotation = null_rot + Vector3.LEFT * ypr.z * pitch_yaw_roll_display_sensitivity.z
		$Heading2/YawTrim.rotation = null_rot + Vector3.DOWN * trim.x * pitch_yaw_roll_display_sensitivity.y
		$Heading2/PitchTrim.rotation = null_rot + Vector3.FORWARD * trim.y * pitch_yaw_roll_display_sensitivity.x
		$Heading2/RollTrim.rotation = null_rot + Vector3.LEFT * trim.z * pitch_yaw_roll_display_sensitivity.z
		throttle_slider.value = throttle
	else:
		$Heading2/Pitch.hide()
		$Heading2/Yaw.hide()
		$Heading2/Roll.hide()
		$Heading2/PitchTrim.hide()
		$Heading2/YawTrim.hide()
		$Heading2/RollTrim.hide()
		throttle_slider.hide()
	
	_update_display()


func _update_display():
	if "get_air_velocity" in player:
		var tas = V.length()
		var ias = tas
		if speed_units == 0:
			$Heading2/IAS.text = "%5.1f m/s" % ias
		else:
			$Heading2/IAS.text = "%5.1f kts" % (ias / 0.514444)
		var temperature = 288.15
		$Heading2/Mach.text = "M = %5.3f" % (tas / sqrt(1.4 * 287 * temperature))
	else:
		$Heading2/IAS.hide()
		$Heading2/Mach.hide()
		
	var pos2d: Vector3 = player.global_position - player.global_position.project(Vector3.FORWARD)
	if coordinates == 0:
		$Heading2/Altitude.text = "%5.1f m" % (4000 - pos2d.length())
	else:
		$Heading2/Altitude.text = "%5.1f m" % player.global_position.y
	var acc_display = sign(player.fealt_acceleration.dot(target_basis.y)) * player.fealt_acceleration.length()
	$Heading2/Acceleration.text = "%5.1f G" % (acc_display / 9.81)
	
	var cam_bas = get_tree().root.get_camera_3d().get_parent().global_transform.basis
	
	var view_heading_horizontal = _get_signed_angle_on_plane(
		cam_bas * Vector3.RIGHT,
		Vector3.RIGHT,
		Vector3.UP
	)
