class_name TrackingAnchor
extends Node3D

@export var show_on_hud = true
@export var show_on_rwr = true
@export var hitbox: Hitbox
@export_flags("Good Guys", "Bad Guys", "3rd Party") var allegency_flags: int

signal on_take_dammage(dmg: int)

var ref: Node3D
var _pos = Vector3.ZERO
var velocity = Vector3.ZERO

func _ready():
	_pos = global_position
	if not is_instance_valid(ref):
		_auto_setup()
		
func _physics_process(dt: float):
	velocity = (global_position - _pos) / dt
	_pos = global_position
		
func _auto_setup():
	var node = get_parent()
	while node != get_tree().root:
		if node is PlaneInterface:
			setup_from_plane(node)
			return
		elif node is Element:
			setup_from_element(node)
			return
		node = node.get_parent()
	push_error("Autosetup could not find valid node in hirarchy od tracking anchor at \"%s\". Deleting anchor" % get_path())
	queue_free()

func setup_from_plane(plane: PlaneInterface) -> void:
	ref = plane
	
func setup_from_element(element: Element) -> void:
	ref = element

func refers_plane() -> bool:
	return ref is PlaneInterface

func refers_element() -> bool:
	return ref is Element

func has_health() -> bool:
	if not is_instance_valid(hitbox):
		return false
	return hitbox.max_health > 1 and not hitbox.invulnerable

func get_health() -> int:
	if not is_instance_valid(hitbox):
		return 0
	return hitbox.health
	
func get_max_health() -> int:
	if not is_instance_valid(hitbox):
		return 0
	return hitbox.max_health
	
func get_velocity() -> Vector3:
	return velocity

func is_hidden() -> bool:
	if refers_plane():
		return ref.is_hidden()
	return false  # TODO
