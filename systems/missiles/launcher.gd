class_name MissileLauncher
extends Node3D

@export var missile_cooldown = 0
@export var wait_for_impact = true
@export var missile_certainty_radius := 10.0
@export var missile_paths: Array[NodePath]

var allow_missile = true

@onready var missile_stack = missile_paths.map(get_node)
var launched_missiles = []

var target: TrackingAnchor

func _process(dt: float):
	launched_missiles = launched_missiles.filter(func(x): return is_instance_valid(x))

func update(p_target: TrackingAnchor) -> void:
	target = p_target

func recommend_launch(missile: Missile) -> bool:
	if not allow_missile:
		return false
	if wait_for_impact and not launched_missiles.is_empty():
		return false
	return missile.recommend_launch(target, missile_certainty_radius)

func get_next_missile() -> Missile:
	for missile in missile_stack:
		if missile.is_ready(target):
			return missile
	return null

func launch(missile: Missile):
	if not is_instance_valid(missile):
		return null
	missile.launch(target)
	missile_stack.erase(missile)
	launched_missiles.append(missile)
	
	if missile_cooldown > 0:
		var tween: Tween = get_tree().create_tween().bind_node(self)
		tween.tween_interval(missile_cooldown)
		tween.tween_callback(func (): allow_missile = true)
	return missile

func launch_next_missile() -> Missile:
	var missile = get_next_missile()
	launch(missile)
	return missile
