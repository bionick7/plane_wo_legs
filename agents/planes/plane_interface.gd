@icon("plane_interface_icon.svg")
class_name PlaneInterface
extends CharacterBody3D

signal update_ypr(ypr: Vector3, throttle: float)

@export_range(0, 100, 0.001, "or_greater", "hide_slider", "suffix:m/s") var crash_tolerance: float

@export_group("Initial")
@export var initial_velocity_local: Vector3

@export_group("Debug")
@export var frozen: bool
@export var manual_step: bool:
	get: return false
	set(x):
		if is_inside_tree():
			update_velocity_rotation(0.0167, true)
			move_and_collide(velocity * 0.0167)

@export var draw_pathtrace: bool
@export var pathtrace_color: Color = Color.RED

@export_group("References")
@export var gun: GPUParticles3D
@export var hitbox: Hitbox

var trace_index = -1
var visual_ypr = Vector3.ZERO
var visual_throttle = 0
var _is_hidden = false

@onready var debug_drawer = get_node_or_null("DebugDrawer")

func _ready():
	add_to_group("Planes")  # Set automatically for consistency
	velocity = basis * initial_velocity_local
	if is_instance_valid(hitbox):
		hitbox.died.connect(die)

func _process(dt: float):
	_is_hidden = CloudManager.is_in_cloud(global_position)
	emit_signal("update_ypr", visual_ypr, visual_throttle)

func _physics_process(dt: float):
	var collision: KinematicCollision3D = null
	if not frozen:
		collision = move_and_collide(velocity * dt)
		
	if collision != null:
		var collision_velocity := (velocity - collision.get_collider_velocity()).project(collision.get_normal())
		velocity -= collision_velocity
		if collision_velocity.length() > crash_tolerance:
			die("Collision with %s" % collision.get_collider().get_path())
			
	update_velocity_rotation(dt, false)
	
	assert(transform.is_finite())
	assert(velocity.is_finite())
	
	_handle_pathtrace()

func update_velocity_rotation(dt: float, manual: bool) -> void:
	up_direction = CommonPhysics.get_up(global_position)
	# Override in children

func is_hidden() -> bool:
	return _is_hidden

func die(cause: String) -> void:
	print("%s Has died because of %s" % [name, cause])
	queue_free()

func _handle_pathtrace():
	if debug_drawer == null:
		return
	if draw_pathtrace:
		if trace_index < 0:
			trace_index = debug_drawer.start_trace(pathtrace_color, 
				debug_drawer.TRACE_FLAG_ACTIVE | debug_drawer.TRACE_FLAG_GLOBAL)
		debug_drawer.extend_trace(trace_index, global_position)
	else:
		if trace_index >= 0:
			debug_drawer.stop_trace(trace_index)
			trace_index = -1
