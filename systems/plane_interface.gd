@icon("plane_interface_icon.svg")
class_name PlaneInterface
extends CharacterBody3D

@export_range(0, 100, 0.001, "or_greater", "hide_slider", "suffix:m/s") var crash_tolerance: float

@export_group("Initial")
@export var initial_velocity: Vector3
@export var invincible: bool
@export var max_health: int

@export_flags("Good Guys", "Bad Guys", "3rd Party") var allegency_flags: int

@export_group("Debug")
@export var frozen: bool
@export var manual_step: bool:
	get: return false
	set(x):
		if is_inside_tree():
			update_velocity_rotation(0.0167, true)

@export var draw_pathtrace: bool
@export var pathtrace_color: Color = Color.RED

@export_group("References")
@export var gun: GPUParticles3D

var trace_index = -1
var visual_ypr = Vector3.ZERO
var visual_throttle = 0

@onready var health = max_health
@onready var common_physics = $"/root/CommonPhysics"
@onready var debug_drawer = get_node_or_null("DebugDrawer")

signal on_death
signal update_ypr(ypr: Vector3, throttle: float)

func _ready():
	add_to_group("Planes")  # Set automatically for consistency
	velocity = initial_velocity

func _process(dt: float):
	emit_signal("update_ypr", visual_ypr, visual_throttle)

func _physics_process(dt: float):
	update_velocity_rotation(dt, false)
	
	var collision: KinematicCollision3D = move_and_collide(velocity * dt)
	if collision != null:
		var collision_velocity = (velocity - collision.get_collider_velocity()).dot(collision.get_normal())
		if collision_velocity > crash_tolerance:
			die()
		else: 
			velocity = collision.get_collider_velocity()
	_handle_pathtrace()

func update_velocity_rotation(dt: float, manual: bool) -> void:
	up_direction = common_physics.get_acc(global_position, velocity).normalized()
	# Override in children

func is_hidden() -> bool:
	return false

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

func die() -> void:
	if invincible:
		return
	emit_signal("on_death")
	queue_free()

func _on_bullet_hit(pos, vel):
	print("%s Hit" % name)
	health -= 1
	if health <= 0:
		die()
