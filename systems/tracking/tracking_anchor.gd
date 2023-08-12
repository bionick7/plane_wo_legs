class_name TrackingAnchor
extends Node3D

enum TGT_FLAGS {
	PLAYER_CAN_TARGET = 	0x01,
	NPC_CAN_TARGET = 		0x02,
	CWIS_CAN_TARGET = 		0x04
}

@export var show_on_hud = true
@export var show_on_rwr = true
## The TrackingAnchor can be tracked by the following agents
@export_flags("Player", "NPC Planes", "CWIS") var target_flags: int
## The hitbox associated with the same parent agent. null if not applicable
@export var hitbox: Hitbox
## Will get targeted by NPC if allegency_flags overlap with NPCs hostility flags
@export_flags("Good Guys", "Bad Guys", "3rd Party") var allegency_flags: int

## The object, the tracking anchor is attached to / refers to
var ref: Node3D
var _pos = Vector3.ZERO
var _calc_velocity = Vector3.ZERO

func _ready():
	_pos = global_position
	if not is_instance_valid(ref):
		_auto_setup()
		
func _physics_process(dt: float):
	_calc_velocity = (global_position - _pos) / dt
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
	if refers_plane():
		return ref.velocity
	return _calc_velocity

## Will return true if the object is within the cloud layer
## Only implemented for planes right now
func is_hidden() -> bool:
	if refers_plane():
		return ref.is_hidden()
	return false  # TODO
