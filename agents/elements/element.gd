class_name Element
extends Node3D

@export_group("References")
@export var hitbox: Hitbox

func _ready():
	hitbox.died.connect(die)

func die(cause: String) -> void:
	queue_free()
