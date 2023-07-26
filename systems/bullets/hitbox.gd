class_name Hitbox
extends Area3D

@export_range(0, 10, 0.01, "suffix:s") var vulnerability_cooldown = 0.5
@export var max_health: int
@export var invulnerable: bool

@onready var hit_explosion = $HitExplosion
@onready var health = max_health

var accept_hits = true

signal bullet_hit(pos: Vector3, vel: Vector3)
signal on_take_dammage(dmg: int)
signal die()

func on_bullet_hit(pos: Vector3, vel: Vector3) -> void:
	if not accept_hits:
		return
	hit_explosion.global_position = pos
	hit_explosion.emitting = true
	emit_signal("bullet_hit", pos, vel)
	
	var dmg: int = 1
	health -= dmg
	emit_signal("on_take_dammage", dmg)
	if health <= 0 and not invulnerable:
		emit_signal("die")
		
	accept_hits = false
	get_tree().create_timer(vulnerability_cooldown).timeout.connect(func(): accept_hits = true)
